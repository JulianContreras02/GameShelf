package com.gameshelf.data.psn

import com.gameshelf.data.net.GameShelfJson
import com.gameshelf.data.net.NetworkError
import com.gameshelf.data.net.OkHttpFormTransport
import com.gameshelf.data.net.PSNAuthTransporting
import com.gameshelf.data.net.RedirectMissingException
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.time.Instant

/**
 * Inicia y mantiene la sesion con PlayStation Network.
 *
 * **Es una API no oficial.** Sony no la documenta ni promete que siga
 * existiendo. Todo lo que sabe de su forma vive detras de esta interfaz, para
 * que el dia que cambie el dano quede en un solo archivo.
 */
interface PSNAuthenticating {
  /**
   * Canjea el codigo que el usuario copio del navegador por credenciales.
   *
   * @throws PSNAuthError.NpssoInvalido si el codigo no sirve o caduco.
   */
  suspend fun signIn(npsso: String): PSNCredentials

  /**
   * Pide un token de acceso nuevo con el de refresco.
   *
   * @throws PSNAuthError.SesionExpirada si el refresco tampoco sirve ya.
   */
  suspend fun refresh(refreshToken: String): PSNCredentials
}

/** Implementacion real contra los endpoints de Sony. */
class PSNAuthService(
  private val transport: PSNAuthTransporting = OkHttpFormTransport(),
  private val ahora: () -> Instant = Instant::now,
) : PSNAuthenticating {

  override suspend fun signIn(npsso: String): PSNCredentials {
    val limpio = npsso.trim()
    if (limpio.isEmpty()) throw PSNAuthError.NpssoInvalido

    val codigo = authorizationCode(limpio)
    return tokens(
      campos = mapOf(
        "code" to codigo,
        "redirect_uri" to REDIRECT_URI,
        "grant_type" to "authorization_code",
        "token_format" to "jwt",
      ),
      errorSiFalla = PSNAuthError.NpssoInvalido,
    )
  }

  override suspend fun refresh(refreshToken: String): PSNCredentials = tokens(
    campos = mapOf(
      "refresh_token" to refreshToken,
      "grant_type" to "refresh_token",
      "token_format" to "jwt",
      "scope" to SCOPE,
    ),
    errorSiFalla = PSNAuthError.SesionExpirada,
  )

  /**
   * Primer paso: cambiar el NPSSO por un codigo de autorizacion.
   *
   * El codigo no viene en el cuerpo sino en la **redireccion**: Sony responde
   * 302 hacia `com.scee.psxandroid.scecompcall://redirect?code=v3.xxx`. Si el
   * NPSSO no sirve, redirige a la pantalla de login con
   * `error=login_required`.
   */
  suspend fun authorizationCode(npsso: String): String {
    val url = (AUTHORIZE_URL.toHttpUrlOrNull() ?: throw NetworkError.InvalidURL(AUTHORIZE_URL))
      .newBuilder()
      .addQueryParameter("access_type", "offline")
      .addQueryParameter("client_id", CLIENT_ID)
      .addQueryParameter("redirect_uri", REDIRECT_URI)
      .addQueryParameter("response_type", "code")
      .addQueryParameter("scope", SCOPE)
      .build()
      .toString()

    val destino = try {
      transport.redirectLocation(url, npsso)
    } catch (e: RedirectMissingException) {
      throw PSNAuthError.RespuestaInesperada(e.detalle)
    }

    return extraerCodigo(destino)
  }

  /** Segundo paso: cambiar el codigo (o el refresco) por tokens. */
  private suspend fun tokens(
    campos: Map<String, String>,
    errorSiFalla: PSNAuthError,
  ): PSNCredentials {
    val cuerpo = transport.postForm(campos, TOKEN_URL, basicAuthorization())

    runCatching { GameShelfJson.decodeFromString(PSNTokenResponse.serializer(), cuerpo) }
      .getOrNull()
      ?.credentials(ahora())
      ?.let { return it }

    // Sony devuelve el motivo en el cuerpo, con 400. Se traduce a algo que el
    // usuario pueda accionar.
    runCatching { GameShelfJson.decodeFromString(PSNErrorResponse.serializer(), cuerpo) }
      .getOrNull()
      ?.let { error ->
        throw if (error.esDeCredencialesInvalidas) {
          errorSiFalla
        } else {
          PSNAuthError.RespuestaInesperada(error.descripcion)
        }
      }

    throw PSNAuthError.RespuestaInesperada("No se entendio la respuesta")
  }

  companion object {
    /**
     * Credenciales de la app movil de PlayStation.
     *
     * No son secretas ni son del usuario: van dentro de la app de Sony, se
     * pueden sacar de ella y las usan todas las librerias abiertas de PSN. Van
     * aca y no en el archivo de secretos justamente por eso: no hay nada que
     * proteger, y ponerlas en la configuracion sugeriria que cada quien tiene
     * las suyas.
     */
    const val CLIENT_ID = "09515159-7237-4370-9b40-3806e67c0891"
    const val CLIENT_SECRET = "ucPjka5tntB2KqsP"
    const val REDIRECT_URI = "com.scee.psxandroid.scecompcall://redirect"
    const val SCOPE = "psn:mobile.v2.core psn:clientapp"

    const val AUTHORIZE_URL = "https://ca.account.sony.com/api/authz/v3/oauth/authorize"
    const val TOKEN_URL = "https://ca.account.sony.com/api/authz/v3/oauth/token"

    /**
     * Donde el usuario ve su NPSSO.
     *
     * **Solo responde con el codigo si ya hay sesion iniciada en ese
     * navegador.** Sin sesion devuelve `{"error":"invalid_grant",
     * "error_description":"Invalid login","error_code":20}`, que despista
     * bastante: parece que la direccion esta mal cuando lo que falta es
     * iniciar sesion. Por eso la pantalla ofrece los dos enlaces en orden.
     */
    const val NPSSO_URL = "https://ca.account.sony.com/api/v1/ssocookie"

    /**
     * Donde iniciar sesion, que es el paso previo.
     *
     * Es la pagina normal de PlayStation, con su boton de "Iniciar sesion". No
     * se usa la pantalla de login suelta porque sin los parametros de OAuth
     * que Sony le pasa por dentro se queda en "Algo salio mal".
     *
     * Los dos pasos tienen que hacerse en el **mismo navegador**: lo que
     * comparten es la sesion.
     */
    const val SIGN_IN_URL = "https://www.playstation.com/"

    /**
     * Saca el `code` de la URL de redireccion.
     *
     * Se expone para poder probarlo sin red: es donde se decide si el token
     * del usuario sirve o hay que pedirle uno nuevo.
     */
    fun extraerCodigo(destino: String): String {
      // El destino usa un esquema propio de otra app, que OkHttp no sabe
      // parsear. Se lee la query a mano.
      val query = destino.substringAfter('?', "")
      val parametros = query.split('&')
        .mapNotNull { par ->
          val clave = par.substringBefore('=')
          val valor = par.substringAfter('=', "")
          if (clave.isEmpty()) null else clave to valor
        }
        .toMap()

      parametros["code"]?.takeIf { it.isNotEmpty() }?.let { return it }

      // Sony manda a la pantalla de login con error=login_required (codigo
      // 4165) cuando el NPSSO caduco. Es el caso mas comun con diferencia.
      parametros["error"]?.let { error ->
        throw if (error == "login_required") {
          PSNAuthError.NpssoInvalido
        } else {
          PSNAuthError.RespuestaInesperada(error)
        }
      }

      throw PSNAuthError.RespuestaInesperada("Redireccion sin codigo ni error")
    }

    /** La cabecera `Authorization: Basic` con las credenciales de la app movil. */
    fun basicAuthorization(): String {
      val par = "$CLIENT_ID:$CLIENT_SECRET"
      // Se usa el Base64 de la JVM y no el de android.util: asi la funcion
      // se puede probar sin levantar Android, que es justo lo que hace la
      // prueba equivalente de iOS.
      val codificado = java.util.Base64.getEncoder().encodeToString(par.toByteArray(Charsets.UTF_8))
      return "Basic $codificado"
    }
  }
}
