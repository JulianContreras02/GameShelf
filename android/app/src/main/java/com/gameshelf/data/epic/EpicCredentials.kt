package com.gameshelf.data.epic

import android.content.Context
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError
import java.time.Duration
import java.time.Instant

/** Lo que hace falta para hablar con Epic en nombre del usuario. */
data class EpicCredentials(
  val accessToken: String,
  val refreshToken: String,

  /** Cuando deja de servir el token de acceso. Epic da unas ocho horas. */
  val expiresAt: Instant,

  /** Cuando deja de servir el de refresco. Epic si manda este dato. */
  val refreshExpiresAt: Instant? = null,

  /** Identificador de la cuenta, que hace falta para pedir la biblioteca. */
  val accountID: String? = null,

  /** Nombre visible de la cuenta. Solo para mostrarlo. */
  val displayName: String? = null,
) {
  /**
   * Si el token de acceso ya no sirve, o le queda muy poco.
   *
   * Se adelanta un minuto, igual que en PSN: pedir con un token que expira
   * mientras la peticion va en camino da un 401 evitable.
   */
  fun isExpired(at: Instant = Instant.now(), margen: Duration = Duration.ofSeconds(60)): Boolean =
    !at.plus(margen).isBefore(expiresAt)
}

/**
 * Por que fallo la autenticacion con Epic.
 *
 * Los codigos vienen de la respuesta real y se comprobaron contra la API.
 */
sealed class EpicAuthError : Exception(), UserFacingError {

  /** El codigo no existe o ya se uso. Duran muy poco. */
  data object CodigoInvalido : EpicAuthError()

  /** El refresh token ya no sirve: toca copiar un codigo nuevo. */
  data object SesionExpirada : EpicAuthError()

  /** Epic respondio algo que no se esperaba. */
  data class RespuestaInesperada(val detalle: String) : EpicAuthError()

  /** No hay credenciales guardadas todavia. */
  data object SinCredenciales : EpicAuthError()

  override fun message(context: Context): String = when (this) {
    CodigoInvalido -> context.getString(R.string.epic_error_code_invalid)
    SesionExpirada -> context.getString(R.string.epic_error_session_expired)
    is RespuestaInesperada -> context.getString(R.string.epic_error_unexpected, detalle)
    SinCredenciales -> context.getString(R.string.epic_error_not_connected)
  }

  override fun recovery(context: Context): String? = when (this) {
    // Los codigos de Epic caducan en segundos: lo mas comun es tardar entre
    // copiarlo y pegarlo, no que este mal escrito.
    CodigoInvalido -> context.getString(R.string.epic_recovery_code_expires_fast)
    SesionExpirada -> context.getString(R.string.epic_recovery_generate_again)
    SinCredenciales -> context.getString(R.string.recovery_connect_from_settings)
    is RespuestaInesperada -> null
  }

  /** Si la unica salida es que el usuario genere un codigo nuevo. */
  val necesitaCodigoNuevo: Boolean
    get() = this is CodigoInvalido || this is SesionExpirada || this is SinCredenciales

  override val message: String
    get() = when (this) {
      CodigoInvalido -> "Codigo de Epic invalido"
      SesionExpirada -> "Sesion de Epic expirada"
      is RespuestaInesperada -> "Respuesta inesperada de Epic: $detalle"
      SinCredenciales -> "Sin credenciales de Epic"
    }
}
