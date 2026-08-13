package com.gameshelf.data.steam

import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.NetworkError
import com.gameshelf.data.net.OkHttpNetworkClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Conectar la cuenta de Steam.
 *
 * Es una interfaz para poder inyectar un doble en las pruebas, igual que el
 * resto de los servicios.
 */
interface SteamAuthenticating {

  /**
   * Comprueba la clave y el perfil, y devuelve las credenciales ya listas.
   *
   * @param perfil La URL del perfil o el SteamID64. Ver [SteamProfileRef].
   * @throws SteamAuthError si la clave o el perfil no sirven.
   * @throws NetworkError si la peticion falla.
   */
  suspend fun signIn(apiKey: String, perfil: String): SteamCredentials
}

/**
 * Implementacion real contra la Steam Web API.
 *
 * ## Por que hay que pegar la API key a mano
 *
 * Steam **no tiene OAuth para su Web API**. La clave se genera en
 * `steamcommunity.com/dev/apikey` y solo se puede copiar de ahi: no existe
 * ningun flujo por el que una app de terceros la obtenga sola. Es la misma
 * situacion que el NPSSO de PSN y que el codigo de Epic, y por eso la pantalla
 * de conexion tiene la misma forma que las otras dos.
 *
 * Lo que si se resuelve solo es el SteamID: el usuario pega la URL de su
 * perfil, que es lo que tiene a mano, y este servicio la traduce al numero de
 * 17 digitos que la API necesita.
 */
class SteamAuthService(
  private val client: HttpClient = OkHttpNetworkClient(),
) : SteamAuthenticating {

  override suspend fun signIn(apiKey: String, perfil: String): SteamCredentials {
    val clave = apiKey.trim()
    if (clave.isEmpty()) throw SteamAuthError.ClaveInvalida

    val referencia = SteamProfileRef.parse(perfil) ?: throw SteamAuthError.PerfilIlegible

    val steamID = when (referencia) {
      is SteamProfileRef.Id -> referencia.steamID64
      is SteamProfileRef.Vanity -> resolverNombre(clave, referencia.nombre)
    }

    // Se pide el resumen aunque ya se tenga el id: es lo que confirma que la
    // clave sirve de verdad y que el perfil existe, antes de guardar nada. Sin
    // esta llamada, una clave mal copiada se descubriria mucho despues, al
    // sincronizar, y con un error que no apunta a la causa.
    val jugador = resumen(clave, steamID) ?: throw SteamAuthError.PerfilNoEncontrado

    return SteamCredentials(
      apiKey = clave,
      steamID = steamID,
      personaName = jugador.personaName,
    )
  }

  /** Traduce un nombre personalizado al SteamID64. */
  private suspend fun resolverNombre(apiKey: String, nombre: String): String {
    val respuesta = pedir(
      resolveVanityURL(apiKey, nombre),
      SteamResolveVanityResponse.serializer(),
    ).response

    // Steam contesta 200 con `success: 42` cuando el nombre no existe. Tratarlo
    // como error de red seria enganoso: la peticion salio bien, el nombre no.
    if (respuesta.success != EXITO || respuesta.steamID.isNullOrBlank()) {
      throw SteamAuthError.PerfilNoEncontrado
    }

    return respuesta.steamID
  }

  /** Trae el resumen publico del perfil. `null` si el id no existe. */
  private suspend fun resumen(apiKey: String, steamID: String): SteamPlayerSummaryDTO? =
    pedir(
      playerSummariesURL(apiKey, steamID),
      SteamPlayerSummariesResponse.serializer(),
    ).response.players.firstOrNull()

  /**
   * Hace la peticion traduciendo los codigos que significan "clave mala".
   *
   * Steam responde 403 con una clave invalida y 401 con una revocada. Los dos
   * llegarian como un `HttpError` generico que la pantalla mostraria como un
   * problema de red, cuando el arreglo es volver a copiar la clave.
   */
  private suspend fun <T> pedir(
    url: String,
    serializer: kotlinx.serialization.DeserializationStrategy<T>,
  ): T = try {
    client.get(url, serializer)
  } catch (e: NetworkError.HttpError) {
    if (e.statusCode == 401 || e.statusCode == 403) throw SteamAuthError.ClaveInvalida else throw e
  }

  // --- URLs ----------------------------------------------------------------
  //
  // Se exponen para poder verificar como se arman sin hacer la peticion, igual
  // que en el resto de los servicios de Steam.

  /** Arma la URL de `ResolveVanityURL`. */
  fun resolveVanityURL(apiKey: String, nombre: String): String =
    SteamService.buildURL("/ISteamUser/ResolveVanityURL/v1/") {
      addQueryParameter("key", apiKey)
      addQueryParameter("vanityurl", nombre)
    }

  /** Arma la URL de `GetPlayerSummaries`. */
  fun playerSummariesURL(apiKey: String, steamID: String): String =
    SteamService.buildURL("/ISteamUser/GetPlayerSummaries/v2/") {
      addQueryParameter("key", apiKey)
      addQueryParameter("steamids", steamID)
    }

  companion object {
    /** El unico valor de `success` que significa que el nombre se resolvio. */
    const val EXITO = 1

    /** Donde se genera la API key. Pide iniciar sesion en Steam. */
    const val API_KEY_URL = "https://steamcommunity.com/dev/apikey"

    /**
     * Atajo al perfil propio.
     *
     * `/my/profile` redirige al perfil de quien tenga la sesion abierta, asi
     * que la barra de direcciones acaba mostrando la URL que hay que copiar sin
     * tener que buscarla.
     */
    const val PROFILE_URL = "https://steamcommunity.com/my/profile"
  }
}

// --- DTOs -----------------------------------------------------------------

@Serializable
internal data class SteamResolveVanityResponse(val response: Payload) {

  @Serializable
  internal data class Payload(
    @SerialName("steamid") val steamID: String? = null,
    /** `1` si lo encontro, `42` si no. Steam no usa otros valores. */
    val success: Int = 0,
  )
}

@Serializable
internal data class SteamPlayerSummariesResponse(val response: Payload) {

  @Serializable
  internal data class Payload(
    @SerialName("players") private val rawPlayers: List<SteamPlayerSummaryDTO>? = null,
  ) {
    /**
     * Steam omite `players` cuando no hay ninguno, en vez de mandar una lista
     * vacia. Se normaliza aca para que quien lo lea no repita el `?: emptyList()`.
     */
    val players: List<SteamPlayerSummaryDTO> get() = rawPlayers.orEmpty()
  }
}

@Serializable
internal data class SteamPlayerSummaryDTO(
  @SerialName("steamid") val steamID: String,
  @SerialName("personaname") val personaName: String? = null,
)
