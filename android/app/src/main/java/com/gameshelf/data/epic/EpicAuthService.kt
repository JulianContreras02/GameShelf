package com.gameshelf.data.epic

import com.gameshelf.data.net.FormPostTransporting
import com.gameshelf.data.net.GameShelfJson
import com.gameshelf.data.net.OkHttpFormTransport
import java.net.URLEncoder
import java.time.Instant

/**
 * Inicia y mantiene la sesion con Epic Games.
 *
 * **API no oficial**, y la mas fragil de las tres: Epic no publica un flujo
 * para apps de terceros. Todo lo que sabe de su forma vive detras de esta
 * interfaz.
 */
interface EpicAuthenticating {
  /** Canjea el codigo que el usuario copio del navegador. */
  suspend fun signIn(authorizationCode: String): EpicCredentials

  /** Pide credenciales nuevas con el token de refresco. */
  suspend fun refresh(refreshToken: String): EpicCredentials
}

/** Implementacion real contra los endpoints de Epic. */
class EpicAuthService(
  private val transport: FormPostTransporting = OkHttpFormTransport(),
  private val ahora: () -> Instant = Instant::now,
) : EpicAuthenticating {

  override suspend fun signIn(authorizationCode: String): EpicCredentials {
    val limpio = authorizationCode.trim()
    if (limpio.isEmpty()) throw EpicAuthError.CodigoInvalido

    return tokens(
      campos = mapOf(
        "grant_type" to "authorization_code",
        "code" to limpio,
        "token_type" to "eg1",
      ),
      errorSiFalla = EpicAuthError.CodigoInvalido,
    )
  }

  override suspend fun refresh(refreshToken: String): EpicCredentials = tokens(
    campos = mapOf(
      "grant_type" to "refresh_token",
      "refresh_token" to refreshToken,
      "token_type" to "eg1",
    ),
    errorSiFalla = EpicAuthError.SesionExpirada,
  )

  private suspend fun tokens(
    campos: Map<String, String>,
    errorSiFalla: EpicAuthError,
  ): EpicCredentials {
    val cuerpo = transport.postForm(campos, TOKEN_URL, basicAuthorization())

    runCatching { GameShelfJson.decodeFromString(EpicTokenResponse.serializer(), cuerpo) }
      .getOrNull()
      ?.credentials(ahora())
      ?.let { return it }

    runCatching { GameShelfJson.decodeFromString(EpicErrorResponse.serializer(), cuerpo) }
      .getOrNull()
      ?.let { error ->
        throw if (error.esDeCredencialesInvalidas) {
          errorSiFalla
        } else {
          EpicAuthError.RespuestaInesperada(error.descripcion)
        }
      }

    throw EpicAuthError.RespuestaInesperada("No se entendio la respuesta")
  }

  companion object {
    /**
     * Credenciales del launcher de Epic.
     *
     * No son secretas ni del usuario: van dentro del launcher, se pueden sacar
     * de el y las usan todas las herramientas abiertas del ecosistema. Van aca
     * por lo mismo que las de PSN: no hay nada que proteger.
     */
    const val CLIENT_ID = "34a02cf8f4414e29b15921876da36f9a"
    const val CLIENT_SECRET = "daafbccc737745039dffe53d94fc76cf"

    const val TOKEN_URL =
      "https://account-public-service-prod.ol.epicgames.com/account/api/oauth/token"

    /**
     * Donde el usuario ve su codigo, si ya inicio sesion.
     *
     * Sin sesion responde con `authorizationCode: null`, no con un error.
     */
    val CODE_URL: String
      get() = "https://www.epicgames.com/id/api/redirect?clientId=$CLIENT_ID&responseType=code"

    /**
     * La pagina de login, que despues lleva al codigo.
     *
     * El destino va codificado: sin escaparlo, Epic corta la direccion en el
     * primer "&" y el login no sabe a donde volver.
     */
    val LOGIN_URL: String
      get() {
        val destino = URLEncoder.encode(CODE_URL, "UTF-8")
        return "https://www.epicgames.com/id/login?redirectUrl=$destino"
      }

    /**
     * La cabecera `Authorization: basic` con las credenciales del launcher.
     *
     * Epic la espera en minuscula. Con "Basic" tambien responde, pero se manda
     * tal como lo hace su launcher para no depender de esa tolerancia.
     */
    fun basicAuthorization(): String {
      val par = "$CLIENT_ID:$CLIENT_SECRET"
      val codificado = java.util.Base64.getEncoder().encodeToString(par.toByteArray(Charsets.UTF_8))
      return "basic $codificado"
    }
  }
}
