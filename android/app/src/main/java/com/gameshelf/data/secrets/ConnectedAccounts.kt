package com.gameshelf.data.secrets

import com.gameshelf.data.steam.SteamCredentials

/**
 * Donde viven las claves ahora que se piden al conectar cada cuenta.
 *
 * ## El cambio respecto al arranque del puerto
 *
 * Antes las tres claves (`STEAM_API_KEY`, `STEAM_ID`, `ITAD_API_KEY`) salian
 * de `Config/Secrets.xcconfig`, o sea de un archivo que hay que editar **antes
 * de compilar**. Eso obligaba a que la app avisara en Ajustes de que faltaba
 * configuracion, que es una tarea de desarrollo colandose en la interfaz de
 * quien solo quiere usarla.
 *
 * Ahora cada cuenta pide lo suyo cuando se conecta y se guarda cifrado, igual
 * que PSN y Epic desde el principio. Una app recien instalada ya no tiene nada
 * "faltante": tiene cuentas sin conectar, que es un estado normal.
 *
 * ## Por que el archivo sigue sirviendo de respaldo
 *
 * Quien ya tuviera `Secrets.xcconfig` (o quien comparta el repo con la version
 * de iOS) sigue funcionando sin tocar nada: si no hay nada guardado, se leen
 * de `BuildConfig` como antes. Lo guardado siempre gana, para que conectar la
 * cuenta desde la app no quede pisado por un archivo viejo.
 */
class SteamCredentialsStore(
  private val secure: SecureStoring,
  private val fallback: AppSecrets.Source = AppSecrets.buildConfigSource,
) {

  /**
   * Las credenciales completas, si las hay.
   *
   * @return `null` si falta la clave o el id. Las dos hacen falta para llamar
   *   a la API de la biblioteca, asi que media credencial no sirve de nada.
   */
  fun credentials(): SteamCredentials? {
    val clave = secure.string(API_KEY)?.ifBlank { null }
      ?: valorDeConfig(AppSecrets.Key.STEAM_API_KEY)
      ?: return null

    val id = steamID() ?: return null

    return SteamCredentials(
      apiKey = clave,
      steamID = id,
      personaName = secure.string(PERSONA_NAME),
    )
  }

  /**
   * Solo el SteamID.
   *
   * Va aparte porque los endpoints de la lista de deseos **no piden API key**:
   * pedirla ahi dejaria la wishlist inservible sin necesidad.
   */
  fun steamID(): String? =
    secure.string(STEAM_ID)?.ifBlank { null } ?: valorDeConfig(AppSecrets.Key.STEAM_ID)

  fun save(credenciales: SteamCredentials) {
    secure.set(credenciales.apiKey, API_KEY)
    secure.set(credenciales.steamID, STEAM_ID)
    credenciales.personaName?.let { secure.set(it, PERSONA_NAME) }
  }

  fun clear() {
    listOf(API_KEY, STEAM_ID, PERSONA_NAME).forEach(secure::remove)
  }

  private fun valorDeConfig(clave: AppSecrets.Key): String? =
    runCatching { AppSecrets.value(clave, fallback) }.getOrNull()

  private companion object {
    const val API_KEY = "steam.apiKey"
    const val STEAM_ID = "steam.steamID"
    const val PERSONA_NAME = "steam.personaName"
  }
}

/**
 * La clave de IsThereAnyDeal, que solo sirve para los precios.
 *
 * Es la mas opcional de todas: sin ella la lista de deseos funciona igual, solo
 * que sin precios ni minimos historicos. Por eso no es una "cuenta conectada"
 * con su pantalla propia sino una clave suelta que se pega en Ajustes.
 */
class ITADKeyStore(
  private val secure: SecureStoring,
  private val fallback: AppSecrets.Source = AppSecrets.buildConfigSource,
) {

  fun key(): String? =
    secure.string(API_KEY)?.ifBlank { null }
      ?: runCatching { AppSecrets.value(AppSecrets.Key.ITAD_API_KEY, fallback) }.getOrNull()

  fun save(clave: String) {
    secure.set(clave.trim(), API_KEY)
  }

  fun clear() {
    secure.remove(API_KEY)
  }

  private companion object {
    const val API_KEY = "itad.apiKey"
  }
}
