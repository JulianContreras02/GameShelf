package com.gameshelf.data.steam

import com.gameshelf.data.net.GameShelfJson
import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.NetworkError
import com.gameshelf.data.net.OkHttpNetworkClient
import com.gameshelf.data.secrets.SteamCredentialsStore
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/**
 * Acceso a los datos de Steam del usuario.
 *
 * Es una interfaz para que los ViewModels dependan de esta forma y no de la
 * implementacion concreta, y se pueda inyectar un doble en las pruebas.
 */
interface SteamServicing {
  /**
   * Trae los juegos que el usuario posee en Steam.
   *
   * @return Lista vacia si la biblioteca esta vacia **o** si el perfil es
   *   privado: la API responde igual en los dos casos y no hay forma de
   *   distinguirlos.
   * @throws NetworkError si la peticion falla.
   */
  suspend fun fetchOwnedGames(): List<SteamGameDTO>
}

/**
 * Implementacion real contra la Steam Web API.
 *
 * Las credenciales llegan como una funcion y no como un valor a proposito. El
 * servicio se construye una vez al arrancar la app, pero la cuenta se conecta
 * y se desconecta mientras la app corre: si se guardara el valor, seguiria
 * usando el de cuando se creo y habria que reconstruir medio grafo de
 * dependencias en cada cambio.
 *
 * La funcion **lanza** [SteamAuthError.SinCredenciales] cuando no hay cuenta
 * conectada, en vez de devolver `null`. Asi el error llega a la pantalla por el
 * mismo camino que cualquier otro fallo de sincronizacion y se muestra con su
 * texto, sin un caso especial en cada ViewModel.
 */
class SteamService(
  private val client: HttpClient,
  private val credentials: () -> SteamCredentials,
) : SteamServicing {

  override suspend fun fetchOwnedGames(): List<SteamGameDTO> =
    client.get(ownedGamesURL(), SteamOwnedGamesResponse.serializer()).response.games

  /**
   * Arma la URL de `GetOwnedGames`.
   *
   * Se expone aparte para poder verificar la construccion sin hacer la
   * peticion.
   *
   * Los dos parametros de contenido importan y no son opcionales en la
   * practica:
   * - `include_appinfo=1` trae el nombre y el icono. Sin el, los juegos llegan
   *   como puros numeros.
   * - `include_played_free_games=1` incluye los free-to-play jugados. Sin el,
   *   Steam los omite: en una biblioteca real la diferencia fue de 88 a 118
   *   juegos y de 1220 a 2735 horas, porque el juego mas jugado era F2P.
   */
  fun ownedGamesURL(): String {
    val credenciales = credentials()
    return buildURL("/IPlayerService/GetOwnedGames/v1/") {
      addQueryParameter("key", credenciales.apiKey)
      addQueryParameter("steamid", credenciales.steamID)
      addQueryParameter("include_appinfo", "1")
      addQueryParameter("include_played_free_games", "1")
      addQueryParameter("format", "json")
    }
  }

  companion object {
    const val BASE_URL = "https://api.steampowered.com"

    /** Crea el servicio con las credenciales de la cuenta conectada. */
    fun live(
      client: HttpClient = OkHttpNetworkClient(),
      store: SteamCredentialsStore,
    ): SteamService = SteamService(client) {
      store.credentials() ?: throw SteamAuthError.SinCredenciales
    }

    /**
     * Arma una URL sobre la base de Steam.
     *
     * Va aca y no repetido en cada servicio: los dos de Steam lo necesitan.
     */
    internal fun buildURL(ruta: String, bloque: HttpUrl.Builder.() -> Unit): String {
      val base = (BASE_URL + ruta).toHttpUrlOrNull()
        ?: throw NetworkError.InvalidURL(BASE_URL + ruta)
      return base.newBuilder().apply(bloque).build().toString()
    }
  }
}

/**
 * Un juego de la lista de deseos, ya con todo lo que hace falta para mostrarlo.
 *
 * Junta las dos llamadas que hay que hacer: la wishlist da los appids y la
 * tienda da los nombres.
 */
data class SteamWishlistGame(
  val appID: Int,
  val name: String,
  val coverURL: String?,
  val storeURL: String?,
  /** Cuando se agrego a la lista en Steam. */
  val addedAt: java.time.Instant?,
  /** Orden que le puso el usuario en Steam. `0` es sin prioridad. */
  val priority: Int,
  val releaseDate: java.time.Instant?,
  val isComingSoon: Boolean,
)

/**
 * Acceso a la lista de deseos de Steam.
 *
 * Va en su propia interfaz, aparte de [SteamServicing], a proposito. El
 * endpoint de wishlist es **semi-oficial**: no esta documentado, no promete
 * estabilidad y ya cambio una vez (el antiguo de la tienda dejo de responder).
 * Manteniendolo separado, si se rompe se cae la wishlist y no la biblioteca.
 */
interface SteamWishlistServicing {
  /**
   * Trae la lista de deseos con nombres y caratulas.
   *
   * @return Lista vacia si la wishlist esta vacia **o** si es privada: Steam
   *   responde igual en los dos casos.
   */
  suspend fun fetchWishlist(): List<SteamWishlistGame>
}

/** Implementacion real contra la API de Steam. */
class SteamWishlistService(
  private val client: HttpClient,
  private val steamID: () -> String,
) : SteamWishlistServicing {

  override suspend fun fetchWishlist(): List<SteamWishlistGame> {
    val entradas = client.get(wishlistURL(), SteamWishlistResponse.serializer()).items
    if (entradas.isEmpty()) return emptyList()

    val fichas = fetchStoreItems(entradas.map { it.appID })
    return combinar(entradas, fichas)
  }

  /** Pide a la tienda los datos de una lista de appids, en tandas. */
  suspend fun fetchStoreItems(appIDs: List<Int>): Map<Int, SteamStoreItemDTO> {
    val porAppID = mutableMapOf<Int, SteamStoreItemDTO>()

    appIDs.chunked(TAMANO_DE_TANDA).forEach { tanda ->
      val respuesta = client.get(storeItemsURL(tanda), SteamStoreItemsResponse.serializer())
      respuesta.items.filter { it.isUsable }.forEach { porAppID[it.appID] = it }
    }

    return porAppID
  }

  /**
   * Une lo que dice la wishlist con lo que dice la tienda.
   *
   * Si la tienda no supo resolver un appid, el juego **igual se conserva** con
   * un nombre de respaldo: perder una entrada de la lista de deseos porque su
   * ficha fallo seria peor que mostrarla incompleta.
   */
  private fun combinar(
    entradas: List<SteamWishlistItemDTO>,
    fichas: Map<Int, SteamStoreItemDTO>,
  ): List<SteamWishlistGame> = entradas.map { entrada ->
    val ficha = fichas[entrada.appID]
    SteamWishlistGame(
      appID = entrada.appID,
      name = ficha?.name ?: SteamGameMapper.fallbackName(entrada.appID),
      coverURL = ficha?.coverURL,
      storeURL = ficha?.storeURL ?: "https://store.steampowered.com/app/${entrada.appID}",
      addedAt = entrada.addedAt,
      priority = entrada.priority ?: 0,
      releaseDate = ficha?.releaseDate,
      isComingSoon = ficha?.isComingSoon ?: false,
    )
  }

  // --- URLs --------------------------------------------------------------

  /** Arma la URL de `GetWishlist`. */
  fun wishlistURL(): String =
    SteamService.buildURL("/IWishlistService/GetWishlist/v1/") {
      addQueryParameter("steamid", steamID())
    }

  /**
   * Arma la URL de `GetItems` para una tanda de appids.
   *
   * El endpoint recibe un JSON dentro del parametro `input_json`, no
   * parametros sueltos.
   */
  fun storeItemsURL(appIDs: List<Int>): String {
    val peticion = StoreItemsRequest(
      ids = appIDs.map { StoreItemID(it) },
      context = StoreItemsContext(language = "spanish", countryCode = "CO"),
      dataRequest = StoreItemsDataRequest(includeAssets = true, includeRelease = true),
    )
    val json = GameShelfJson.encodeToString(StoreItemsRequest.serializer(), peticion)

    return SteamService.buildURL("/IStoreBrowseService/GetItems/v1/") {
      addQueryParameter("input_json", json)
    }
  }

  companion object {
    /**
     * Cuantos appids se piden por llamada a la tienda.
     *
     * Steam no documenta un limite. Se parte en tandas para no armar una URL
     * enorme con una wishlist grande, que es justo donde reventaria.
     */
    const val TAMANO_DE_TANDA = 50

    /**
     * Crea el servicio con el SteamID de la cuenta conectada.
     *
     * A diferencia del resto de la API, estos dos endpoints **no piden API
     * key**: se comprobo contra la cuenta real que responden igual con y sin
     * ella. Se pide solo el SteamID para no exponer la clave sin necesidad.
     */
    fun live(
      client: HttpClient = OkHttpNetworkClient(),
      store: SteamCredentialsStore,
    ): SteamWishlistService = SteamWishlistService(client) {
      store.steamID() ?: throw SteamAuthError.SinCredenciales
    }
  }
}

// --- Cuerpo de la peticion a GetItems ------------------------------------
//
// Van fuera del servicio para que sus nombres serializados queden a la vista.

@Serializable
internal data class StoreItemsRequest(
  val ids: List<StoreItemID>,
  val context: StoreItemsContext,
  @SerialName("data_request") val dataRequest: StoreItemsDataRequest,
)

@Serializable
internal data class StoreItemID(val appid: Int)

/** Idioma y pais con los que responde la tienda. */
@Serializable
internal data class StoreItemsContext(
  val language: String,
  @SerialName("country_code") val countryCode: String,
)

/** Que partes de la ficha se quieren. */
@Serializable
internal data class StoreItemsDataRequest(
  @SerialName("include_assets") val includeAssets: Boolean,
  @SerialName("include_release") val includeRelease: Boolean,
)
