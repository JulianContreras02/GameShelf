package com.gameshelf.data.steam

import android.content.Context
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError

/**
 * Lo que hace falta para hablar con Steam en nombre del usuario.
 *
 * A diferencia de PSN y de Epic, aca **no hay tokens que caduquen**: la API key
 * de Steam no vence sola y el SteamID no cambia nunca. Por eso no hay refresco
 * ni fecha de reconexion; una vez conectada, la cuenta sigue conectada hasta
 * que el usuario revoque la clave en la web de Steam.
 *
 * @param personaName El nombre visible de la cuenta. Solo sirve para mostrarlo
 *   en Ajustes y confirmar que se conecto la cuenta correcta, asi que es
 *   opcional: si Steam no lo devolvio, la conexion es valida igual.
 */
data class SteamCredentials(
  val apiKey: String,
  val steamID: String,
  val personaName: String? = null,
)

/**
 * Como el usuario dice cual es su cuenta.
 *
 * Steam identifica un perfil de dos maneras y el usuario no tiene por que
 * saber cual tiene: la URL de su perfil es `/profiles/<numero>` si nunca
 * eligio un nombre personalizado, y `/id/<nombre>` si lo hizo. Se aceptan las
 * dos, y tambien el numero pelado por si lo trae a mano.
 */
sealed interface SteamProfileRef {

  /** El SteamID64, que es lo que la API pide de verdad. */
  data class Id(val steamID64: String) : SteamProfileRef

  /** El nombre personalizado. Hay que resolverlo contra la API para tener el id. */
  data class Vanity(val nombre: String) : SteamProfileRef

  companion object {

    /**
     * Interpreta lo que el usuario pego.
     *
     * Acepta el SteamID64 suelto, la URL del perfil en cualquiera de sus dos
     * formas, con o sin `https://`, con o sin barra final.
     *
     * @return `null` si no se parece a ninguna de las dos cosas.
     */
    fun parse(entrada: String): SteamProfileRef? {
      val limpia = entrada.trim().trimEnd('/')
      if (limpia.isEmpty()) return null

      // El numero pelado. Es el caso mas directo y no necesita mirar la URL.
      if (limpia.esSteamID64()) return Id(limpia)

      // Dentro de una URL, lo que decide es el segmento anterior al ultimo: es
      // lo unico que distingue un id de un nombre personalizado, porque un
      // nombre puede ser todo numeros y parecerse a un id.
      val segmentos = limpia.substringBefore('?').split('/').filter { it.isNotEmpty() }
      val ultimo = segmentos.lastOrNull() ?: return null
      val anterior = segmentos.getOrNull(segmentos.size - 2)?.lowercase()

      return when (anterior) {
        "profiles" -> if (ultimo.esSteamID64()) Id(ultimo) else null
        "id" -> if (ultimo.esNombreValido()) Vanity(ultimo) else null

        // Sin URL de por medio, lo que quede es un nombre personalizado suelto.
        null -> if (ultimo.esNombreValido()) Vanity(ultimo) else null

        else -> null
      }
    }

    /**
     * Un SteamID64 son 17 digitos.
     *
     * No se comprueba el prefijo `7656119` a proposito: es cierto para las
     * cuentas de persona de hoy, pero es una convencion del formato y no una
     * regla de la API. Rechazar un id valido por eso seria peor que dejar que
     * Steam responda "no existe".
     */
    private fun String.esSteamID64() = length == 17 && all { it.isDigit() }

    /** Los nombres personalizados de Steam son letras, numeros, guion y guion bajo. */
    private fun String.esNombreValido() =
      isNotEmpty() && all { it.isLetterOrDigit() || it == '-' || it == '_' }
  }
}

/**
 * Por que fallo la conexion con Steam.
 *
 * Se separan los dos datos que el usuario escribe, porque el arreglo es
 * distinto en cada caso: una clave mala se corrige volviendo a la pagina de la
 * API key, y un perfil que no existe se corrige mirando la URL del perfil.
 */
sealed class SteamAuthError : Exception(), UserFacingError {

  /** No hay cuenta conectada todavia. */
  data object SinCredenciales : SteamAuthError()

  /** Lo que se pego en el campo del perfil no se parece a un perfil. */
  data object PerfilIlegible : SteamAuthError()

  /** El perfil no existe, o el nombre personalizado ya no apunta a nadie. */
  data object PerfilNoEncontrado : SteamAuthError()

  /** Steam rechazo la API key. */
  data object ClaveInvalida : SteamAuthError()

  /** Steam respondio algo que no se esperaba. */
  data class RespuestaInesperada(val detalle: String) : SteamAuthError()

  override fun message(context: Context): String = when (this) {
    SinCredenciales -> context.getString(R.string.steam_error_not_connected)
    PerfilIlegible -> context.getString(R.string.steam_error_profile_unreadable)
    PerfilNoEncontrado -> context.getString(R.string.steam_error_profile_not_found)
    ClaveInvalida -> context.getString(R.string.steam_error_invalid_key)
    is RespuestaInesperada -> context.getString(R.string.steam_error_unexpected, detalle)
  }

  override fun recovery(context: Context): String? = when (this) {
    SinCredenciales -> context.getString(R.string.recovery_connect_from_settings)
    PerfilIlegible, PerfilNoEncontrado ->
      context.getString(R.string.steam_recovery_check_profile)
    ClaveInvalida -> context.getString(R.string.steam_recovery_check_key)
    is RespuestaInesperada -> null
  }

  /**
   * Si la unica salida es que el usuario vuelva a conectar la cuenta.
   *
   * Sirve para que la interfaz decida entre reintentar sola o pedir ayuda,
   * igual que en PSN y en Epic.
   */
  val necesitaReconectar: Boolean
    get() = this is SinCredenciales || this is ClaveInvalida

  override val message: String
    get() = when (this) {
      SinCredenciales -> "Sin credenciales de Steam"
      PerfilIlegible -> "Perfil de Steam ilegible"
      PerfilNoEncontrado -> "Perfil de Steam no encontrado"
      ClaveInvalida -> "API key de Steam invalida"
      is RespuestaInesperada -> "Respuesta inesperada de Steam: $detalle"
    }
}
