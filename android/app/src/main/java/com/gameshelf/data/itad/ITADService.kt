package com.gameshelf.data.itad

import com.gameshelf.data.net.GameShelfJson
import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.NetworkError
import com.gameshelf.data.net.OkHttpNetworkClient
import com.gameshelf.data.secrets.AppSecrets
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.nullable
import kotlinx.serialization.builtins.serializer
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.math.BigDecimal

// --- DTOs -----------------------------------------------------------------

/**
 * Un juego en la respuesta de `POST /games/prices/v3`.
 *
 * Ojo con dos cosas de esta respuesta:
 *
 * 1. Es un arreglo, pero **puede traer menos juegos de los que se pidieron**.
 *    Los que la API no conoce, o que no se venden en ningun lado (un juego que
 *    todavia no ha salido, por ejemplo), simplemente no aparecen. Por eso
 *    quien la consuma tiene que indexar por `id` y nunca emparejar por
 *    posicion.
 * 2. `deals` trae **todas** las tiendas, no solo las que tienen descuento, y
 *    no vienen ordenadas por precio.
 */
@Serializable
data class ITADGamePricesDTO(
  val id: String,
  val historyLow: ITADHistoryLowDTO? = null,
  val deals: List<ITADDealDTO>? = null,
)

/** Minimos historicos en distintas ventanas de tiempo. */
@Serializable
data class ITADHistoryLowDTO(
  /** El minimo de siempre. Es el que interesa. */
  val all: ITADPriceDTO? = null,

  // La API los llama "y1" y "m3"; se renombran porque nombres de dos letras no
  // dicen nada en el sitio donde se leen.
  @SerialName("y1") val ultimoAno: ITADPriceDTO? = null,
  @SerialName("m3") val ultimosTresMeses: ITADPriceDTO? = null,
)

/** Una oferta concreta en una tienda. */
@Serializable
data class ITADDealDTO(
  val shop: ITADShopDTO,
  val price: ITADPriceDTO,
  val regular: ITADPriceDTO,
  /** Porcentaje de descuento que reporta la tienda. `0` si esta a precio lleno. */
  val cut: Int? = null,
  /** Enlace de afiliado de ITAD que redirige a la tienda. */
  val url: String? = null,
)

@Serializable
data class ITADShopDTO(val id: Int, val name: String)

/** Un importe tal como lo manda la API. */
@Serializable
data class ITADPriceDTO(
  /**
   * El valor con decimales. **No usar para calcular**: llega como numero de
   * coma flotante y pierde precision al convertirlo.
   */
  val amount: Double? = null,

  /** El mismo valor en centavos, exacto. Es el que se usa. */
  val amountInt: Int? = null,

  /** Codigo ISO 4217. */
  val currency: String? = null,
) {
  /** El importe ya como valor de dominio, o `null` si la respuesta venia incompleta. */
  val money: Money?
    get() {
      val moneda = currency?.takeIf { it.isNotEmpty() } ?: return null
      amountInt?.let { return Money.fromMinorUnits(it, moneda) }
      val valor = amount ?: return null
      return Money(BigDecimal.valueOf(valor), moneda)
    }
}

// --- Servicio -------------------------------------------------------------

/**
 * Consulta precios en IsThereAnyDeal.
 *
 * Va en su propia interfaz, como el de Steam, para que los ViewModels dependan
 * de esta forma y no de la implementacion, y se pueda inyectar un doble en las
 * pruebas.
 */
interface ITADServicing {
  /**
   * Trae precios y minimos historicos de una lista de juegos de Steam.
   *
   * Son **dos peticiones en lote**, no una por juego: primero se traducen los
   * appids a ids de ITAD y despues se piden todos los precios de una vez.
   *
   * @return Los precios indexados por appid de Steam. Los juegos que ITAD no
   *   conoce, o que no se venden en ninguna tienda, **no aparecen**.
   * @throws NetworkError si alguna peticion falla.
   */
  suspend fun prices(forSteamAppIDs: List<Int>): Map<Int, GamePrices>
}

/** Implementacion real contra la API v2 de IsThereAnyDeal. */
class ITADService(
  private val client: HttpClient,
  private val apiKey: String,
  /**
   * Pais con el que se piden los precios, en ISO 3166-1 alpha-2.
   *
   * Determina en que moneda responde la API. **Para Colombia responde en
   * dolares**, y no es un error del parametro: se comprobo que con `DE`
   * devuelve euros y con `AR` pesos argentinos, asi que el parametro funciona.
   * Lo que pasa es que Steam y las demas tiendas facturan Colombia en USD, y
   * eso es lo que de verdad se paga. La conversion a pesos que muestra la web
   * de ITAD es un calculo suyo con una tasa de cambio, no el precio cobrado.
   */
  val country: String = "CO",
) : ITADServicing {

  override suspend fun prices(forSteamAppIDs: List<Int>): Map<Int, GamePrices> {
    if (forSteamAppIDs.isEmpty()) return emptyMap()

    val idsDeITAD = lookupITADIDs(forSteamAppIDs)
    if (idsDeITAD.isEmpty()) return emptyMap()

    val precios = pricesForITADIDs(idsDeITAD.values.toList())

    // Se vuelve a indexar por appid, que es como los conoce el resto de la app.
    return buildMap {
      idsDeITAD.forEach { (appID, itadID) -> precios[itadID]?.let { put(appID, it) } }
    }
  }

  /**
   * Traduce appids de Steam a ids de ITAD, en tandas.
   *
   * Los que ITAD no conoce se quedan fuera del resultado.
   */
  suspend fun lookupITADIDs(appIDs: List<Int>): Map<Int, String> {
    val resultado = mutableMapOf<Int, String>()

    appIDs.chunked(TAMANO_DE_TANDA).forEach { tanda ->
      val claves = tanda.map { steamKey(it) }
      val cuerpo = GameShelfJson.encodeToString(ListSerializer(String.serializer()), claves)

      val respuesta = client.post(
        lookupURL(),
        cuerpo,
        MapSerializer(String.serializer(), String.serializer().nullable),
      )

      porSteamAppID(respuesta).forEach { (appID, itadID) -> resultado.putIfAbsent(appID, itadID) }
    }

    return resultado
  }

  /**
   * Pide los precios de una lista de ids de ITAD, en tandas.
   *
   * Se llama distinto que el metodo de la interfaz porque en la JVM los dos
   * borran su generico y quedarian con la misma firma.
   */
  suspend fun pricesForITADIDs(ids: List<String>): Map<String, GamePrices> {
    val resultado = mutableMapOf<String, GamePrices>()

    ids.chunked(TAMANO_DE_TANDA).forEach { tanda ->
      val cuerpo = GameShelfJson.encodeToString(ListSerializer(String.serializer()), tanda)
      val respuesta = client.post(
        pricesURL(),
        cuerpo,
        ListSerializer(ITADGamePricesDTO.serializer()),
      )

      // Se indexa por id y no por posicion: la respuesta puede traer menos
      // juegos de los que se pidieron.
      respuesta.forEach { dto -> resultado[dto.id] = mapear(dto) }
    }

    return resultado
  }

  // --- URLs ----------------------------------------------------------------

  /**
   * Arma la URL de la busqueda por id de tienda.
   *
   * Se expone aparte para poder verificar la construccion sin hacer la
   * peticion, igual que en los servicios de Steam.
   */
  fun lookupURL(): String = buildURL("/lookup/id/shop/$STEAM_SHOP_ID/v1") {
    addQueryParameter("key", apiKey)
  }

  /** Arma la URL de la consulta de precios. */
  fun pricesURL(): String = buildURL("/games/prices/v3") {
    addQueryParameter("key", apiKey)
    addQueryParameter("country", country)
  }

  private fun buildURL(ruta: String, bloque: okhttp3.HttpUrl.Builder.() -> Unit): String {
    val base = (BASE_URL + ruta).toHttpUrlOrNull() ?: throw NetworkError.InvalidURL(ruta)
    return base.newBuilder().apply(bloque).build().toString()
  }

  companion object {
    /**
     * Cuantos juegos se piden por peticion.
     *
     * La API acepta hasta 200 por llamada. Con una biblioteca de 118 juegos
     * cabe todo en una, pero se parte igual para no romperse cuando crezca.
     */
    const val TAMANO_DE_TANDA = 200

    /** Identificador de la tienda Steam dentro de ITAD. */
    const val STEAM_SHOP_ID = 61

    const val BASE_URL = "https://api.isthereanydeal.com"

    /** Crea el servicio con la clave del archivo de configuracion. */
    fun live(
      client: HttpClient = OkHttpNetworkClient(),
      source: AppSecrets.Source = AppSecrets.buildConfigSource,
      country: String = "CO",
    ): ITADService =
      ITADService(client, AppSecrets.value(AppSecrets.Key.ITAD_API_KEY, source), country)

    /**
     * Prefijo que usa Steam para sus ids dentro de ITAD.
     *
     * Para Steam la clave no es el appid pelado sino `app/<appid>`. Mandar solo
     * el numero devuelve `null` para todo, sin error: un fallo silencioso facil
     * de no notar.
     */
    fun steamKey(appID: Int): String = "app/$appID"

    /**
     * Traduce el diccionario crudo (`{"app/268910": "uuid", "app/999": null}`)
     * a `appid -> id de ITAD`, dejando fuera los que no se encontraron.
     */
    fun porSteamAppID(crudo: Map<String, String?>): Map<Int, String> = buildMap {
      crudo.forEach { (clave, valor) ->
        if (valor == null || !clave.startsWith("app/")) return@forEach
        clave.removePrefix("app/").toIntOrNull()?.let { put(it, valor) }
      }
    }

    /**
     * Convierte la respuesta de la API al tipo de dominio.
     *
     * De todas las tiendas se queda con la mas barata. La API las manda sin
     * ordenar, asi que hay que buscarla; y se comparan solo las que estan en la
     * misma moneda, porque mezclar monedas daria un "mas barato" falso.
     */
    fun mapear(dto: ITADGamePricesDTO): GamePrices {
      val ofertas = (dto.deals ?: emptyList()).mapNotNull { oferta ->
        val precio = oferta.price.money ?: return@mapNotNull null
        val regular = oferta.regular.money ?: return@mapNotNull null
        GameDeal(
          shopName = oferta.shop.name,
          price = precio,
          regular = regular,
          url = oferta.url,
        )
      }

      val historico = dto.historyLow?.all?.money

      val masBarata = ofertas
        .filter { historico == null || it.price.currency == historico.currency }
        .minByOrNull { it.price.amount }
        ?: ofertas.minByOrNull { it.price.amount }

      return GamePrices(itadID = dto.id, best = masBarata, historicalLow = historico)
    }
  }
}
