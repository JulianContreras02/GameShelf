package com.gameshelf.data.psn

import android.content.Context
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError
import java.time.Duration
import java.time.Instant

/**
 * Lo que hace falta para hablar con PSN en nombre del usuario.
 *
 * Son tres cosas con vidas muy distintas:
 *
 * - El **NPSSO** lo copia el usuario del navegador y dura unos dos meses. Es
 *   la unica pieza que no se puede renovar sola: cuando caduca hay que pedirle
 *   que lo vuelva a copiar.
 * - El **access token** dura una hora y se usa en cada peticion.
 * - El **refresh token** dura unas semanas y sirve para pedir uno de acceso
 *   nuevo sin molestar al usuario.
 */
data class PSNCredentials(
  val accessToken: String,
  val refreshToken: String,

  /** Cuando deja de servir el token de acceso. */
  val expiresAt: Instant,

  /**
   * Cuando deja de servir el token de refresco, si Sony lo dijo.
   *
   * Es la fecha que le importa al usuario: hasta entonces la app se renueva
   * sola. `null` si la respuesta no lo traia, y en ese caso no se muestra
   * ninguna fecha en vez de estimar una.
   */
  val refreshExpiresAt: Instant? = null,
) {
  /**
   * Si el token de acceso ya no sirve, o le queda muy poco.
   *
   * Se adelanta un minuto al vencimiento real: pedir con un token que expira
   * mientras la peticion va en camino da un 401 que se puede evitar.
   */
  fun isExpired(at: Instant = Instant.now(), margen: Duration = Duration.ofSeconds(60)): Boolean =
    !at.plus(margen).isBefore(expiresAt)
}

/**
 * Por que fallo la autenticacion con PSN.
 *
 * Los codigos vienen de la respuesta de Sony y se comprobaron contra la API
 * real. Se traducen a mensajes que digan que hacer, porque "error 4165" no le
 * sirve a nadie.
 */
sealed class PSNAuthError : Exception(), UserFacingError {

  /** El NPSSO caduco o esta mal copiado. Es el caso mas comun. */
  data object NpssoInvalido : PSNAuthError()

  /** El refresh token ya no sirve: toca volver a copiar el NPSSO. */
  data object SesionExpirada : PSNAuthError()

  /** Sony respondio algo que no se esperaba. */
  data class RespuestaInesperada(val detalle: String) : PSNAuthError()

  /** No hay credenciales guardadas todavia. */
  data object SinCredenciales : PSNAuthError()

  override fun message(context: Context): String = when (this) {
    NpssoInvalido -> context.getString(R.string.psn_error_npsso_invalid)
    SesionExpirada -> context.getString(R.string.psn_error_session_expired)
    is RespuestaInesperada -> context.getString(R.string.psn_error_unexpected, detalle)
    SinCredenciales -> context.getString(R.string.psn_error_not_connected)
  }

  override fun recovery(context: Context): String? = when (this) {
    NpssoInvalido, SesionExpirada -> context.getString(R.string.psn_recovery_copy_again)
    SinCredenciales -> context.getString(R.string.recovery_connect_from_settings)
    is RespuestaInesperada -> null
  }

  /**
   * Si la unica salida es que el usuario copie un NPSSO nuevo.
   *
   * Sirve para que la interfaz decida entre reintentar sola o pedir ayuda.
   */
  val necesitaTokenNuevo: Boolean
    get() = this is NpssoInvalido || this is SesionExpirada || this is SinCredenciales

  override val message: String
    get() = when (this) {
      NpssoInvalido -> "NPSSO invalido"
      SesionExpirada -> "Sesion de PSN expirada"
      is RespuestaInesperada -> "Respuesta inesperada de PSN: $detalle"
      SinCredenciales -> "Sin credenciales de PSN"
    }
}
