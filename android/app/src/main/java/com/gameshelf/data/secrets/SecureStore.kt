package com.gameshelf.data.secrets

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Guarda secretos pequenos, cifrados por el sistema.
 *
 * Es la contraparte del Keychain de iOS. En Android el equivalente es
 * `EncryptedSharedPreferences` con una clave maestra guardada en el Keystore
 * del dispositivo, respaldado por hardware cuando lo hay.
 *
 * Es una interfaz para poder inyectar un doble en las pruebas: el almacen de
 * verdad depende del Keystore, y una prueba que lo escriba puede dejar basura
 * o chocar con otra.
 */
interface SecureStoring {
  /** Lee un valor. `null` si no esta guardado. */
  fun string(key: String): String?

  /** Guarda un valor, reemplazando el anterior si lo hubiera. */
  fun set(value: String, key: String)

  /** Borra un valor. No falla si no existia. */
  fun remove(key: String)
}

/**
 * Implementacion real sobre `EncryptedSharedPreferences`.
 *
 * El fichero es propio de la app y no se comparte con nadie, que es el papel
 * que hacia `kSecAttrService` en el Keychain.
 */
class SecureStore(context: Context, fileName: String = DEFAULT_FILE) : SecureStoring {

  private val prefs: SharedPreferences by lazy {
    val master = MasterKey.Builder(context.applicationContext)
      .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
      .build()

    EncryptedSharedPreferences.create(
      context.applicationContext,
      fileName,
      master,
      EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
      EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )
  }

  override fun string(key: String): String? = prefs.getString(key, null)

  override fun set(value: String, key: String) {
    prefs.edit().putString(key, value).apply()
  }

  override fun remove(key: String) {
    prefs.edit().remove(key).apply()
  }

  companion object {
    const val DEFAULT_FILE = "gameshelf_secrets"
  }
}

/**
 * Guarda los secretos en memoria. **Solo para pruebas y vistas previas.**
 *
 * Vive junto a la implementacion real, y no en la carpeta de pruebas, para que
 * las vistas previas de Compose puedan usarla sin tocar el Keystore.
 */
class InMemorySecureStore(valoresIniciales: Map<String, String> = emptyMap()) : SecureStoring {
  private val valores = HashMap(valoresIniciales)

  @Synchronized
  override fun string(key: String): String? = valores[key]

  @Synchronized
  override fun set(value: String, key: String) {
    valores[key] = value
  }

  @Synchronized
  override fun remove(key: String) {
    valores.remove(key)
  }
}
