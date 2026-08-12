package com.gameshelf.data.secrets

import android.content.Context
import com.gameshelf.BuildConfig
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError

/**
 * Acceso a las claves de API que la app necesita.
 *
 * Los valores no viven en el codigo: entran por `Config/Secrets.xcconfig` (el
 * mismo archivo que usa la version de iOS, ignorado por git), el script de
 * Gradle los mete en `BuildConfig` y se leen aca en tiempo de ejecucion.
 *
 * Es el equivalente exacto del rodeo de iOS (xcconfig -> Info.plist -> Bundle),
 * y mantiene su propiedad importante: **si falta una clave el proyecto compila
 * igual** y la app avisa cual falta, en vez de caerse.
 *
 * Ver `docs/decisiones/002-gestion-de-secretos.md`.
 */
object AppSecrets {

  /**
   * Claves disponibles, con el nombre exacto que tienen en el archivo de
   * configuracion.
   */
  enum class Key(val configName: String) {
    STEAM_API_KEY("STEAM_API_KEY"),
    STEAM_ID("STEAM_ID"),
    ITAD_API_KEY("ITAD_API_KEY"),
  }

  /**
   * Error con un mensaje accionable, para mostrarlo en pantalla en vez de
   * dejar que la app se caiga.
   */
  data class MissingSecretError(val key: Key) : Exception(), UserFacingError {
    override fun message(context: Context): String =
      context.getString(R.string.secret_missing, key.configName)

    override fun recovery(context: Context): String =
      context.getString(R.string.secret_missing_recovery, key.configName)

    override val message: String get() = "Falta la clave ${key.configName}"
  }

  /**
   * De donde salen los valores.
   *
   * Se deja inyectar para las pruebas: en produccion es `BuildConfig`, pero un
   * test no puede recompilar el proyecto para cambiarlo.
   */
  fun interface Source {
    fun value(key: Key): String?
  }

  /** La fuente real: lo que Gradle escribio en `BuildConfig`. */
  val buildConfigSource = Source { key ->
    when (key) {
      Key.STEAM_API_KEY -> BuildConfig.STEAM_API_KEY
      Key.STEAM_ID -> BuildConfig.STEAM_ID
      Key.ITAD_API_KEY -> BuildConfig.ITAD_API_KEY
    }
  }

  /**
   * Devuelve el valor de una clave.
   *
   * @throws MissingSecretError si no esta o esta vacia.
   */
  fun value(key: Key, source: Source = buildConfigSource): String {
    val bruto = source.value(key)?.trim()
    if (bruto.isNullOrEmpty()) throw MissingSecretError(key)
    return bruto
  }

  /**
   * Claves que faltan o estan vacias.
   *
   * Sirve para avisar al arrancar, antes de que el usuario se tope con un
   * error a mitad de una pantalla.
   */
  fun missingKeys(source: Source = buildConfigSource): List<Key> =
    Key.entries.filter { key -> runCatching { value(key, source) }.isFailure }
}
