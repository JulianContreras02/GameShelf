package com.gameshelf

import com.gameshelf.data.itad.ITADService
import com.gameshelf.data.net.GameShelfJson
import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.NetworkError
import com.gameshelf.data.secrets.AppSecrets
import com.gameshelf.data.secrets.ITADKeyStore
import com.gameshelf.data.secrets.InMemorySecureStore
import com.gameshelf.data.secrets.SteamCredentialsStore
import com.gameshelf.data.steam.SteamAuthError
import com.gameshelf.data.steam.SteamAuthService
import com.gameshelf.data.steam.SteamCredentials
import com.gameshelf.data.steam.SteamProfileRef
import com.gameshelf.data.steam.SteamService
import com.gameshelf.data.steam.SteamWishlistService
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.DeserializationStrategy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Un cliente HTTP que devuelve respuestas fijas segun lo que diga la URL.
 *
 * Se empareja por trozo de URL y no por igualdad porque las URLs llevan la
 * clave y el id dentro: escribirlas enteras haria que cualquier cambio en como
 * se arman rompiera pruebas que no van de eso.
 */
private class FakeHttpClient(
  private val respuestas: List<Pair<String, String>> = emptyList(),
  private val fallos: List<Pair<String, Throwable>> = emptyList(),
) : HttpClient {

  /** Las URLs que se pidieron, en orden. Sirve para comprobar lo que NO se pide. */
  val urls = mutableListOf<String>()

  override suspend fun <T> get(
    url: String,
    serializer: DeserializationStrategy<T>,
    headers: Map<String, String>,
  ): T {
    urls += url

    fallos.firstOrNull { url.contains(it.first) }?.let { throw it.second }

    val cuerpo = respuestas.firstOrNull { url.contains(it.first) }?.second
      ?: throw AssertionError("La prueba no preparo respuesta para $url")

    return GameShelfJson.decodeFromString(serializer, cuerpo)
  }

  override suspend fun <T> post(
    url: String,
    jsonBody: String,
    serializer: DeserializationStrategy<T>,
    headers: Map<String, String>,
  ): T = throw AssertionError("No se esperaba un POST a $url")
}

/**
 * Comprueba que [bloque] lanza [T].
 *
 * Existe en vez de `assertThrows` porque los bloques de aqui llaman a funciones
 * `suspend`, y el lambda de `assertThrows` no lo es. Al ser `inline`, el cuerpo
 * se pega en el sitio donde se llama y hereda su contexto de corrutina.
 */
private inline fun <reified T : Throwable> assertLanza(bloque: () -> Unit) {
  val error = runCatching(bloque).exceptionOrNull()
  assertTrue(
    "Se esperaba ${T::class.simpleName} y llego ${error?.javaClass?.simpleName ?: "nada"}",
    error is T,
  )
}

private const val ID = "76561198000000000"

private fun resumenDe(nombre: String) =
  """{"response":{"players":[{"steamid":"$ID","personaname":"$nombre"}]}}"""

class SteamProfileRefTest {

  @Test
  fun `acepta el SteamID64 pelado`() {
    assertEquals(SteamProfileRef.Id(ID), SteamProfileRef.parse(ID))
    assertEquals(SteamProfileRef.Id(ID), SteamProfileRef.parse("  $ID  "))
  }

  @Test
  fun `acepta la URL del perfil numerico`() {
    assertEquals(
      SteamProfileRef.Id(ID),
      SteamProfileRef.parse("https://steamcommunity.com/profiles/$ID"),
    )
    // Con barra final, que es como la deja el navegador al copiarla.
    assertEquals(
      SteamProfileRef.Id(ID),
      SteamProfileRef.parse("https://steamcommunity.com/profiles/$ID/"),
    )
    // Sin esquema, que es como queda al copiarla de la barra de algunos navegadores.
    assertEquals(
      SteamProfileRef.Id(ID),
      SteamProfileRef.parse("steamcommunity.com/profiles/$ID"),
    )
  }

  @Test
  fun `acepta la URL del nombre personalizado`() {
    assertEquals(
      SteamProfileRef.Vanity("walter"),
      SteamProfileRef.parse("https://steamcommunity.com/id/walter/"),
    )
    assertEquals(SteamProfileRef.Vanity("walter"), SteamProfileRef.parse("walter"))
  }

  @Test
  fun `el segmento anterior decide, no la forma del ultimo`() {
    // Un nombre personalizado puede ser 17 digitos y parecerse a un id. Lo que
    // lo distingue es venir tras "/id/", no como se ve.
    assertEquals(
      SteamProfileRef.Vanity(ID),
      SteamProfileRef.parse("https://steamcommunity.com/id/$ID"),
    )
  }

  @Test
  fun `rechaza lo que no es un perfil`() {
    assertNull(SteamProfileRef.parse(""))
    assertNull(SteamProfileRef.parse("   "))
    // Un id de menos digitos tras /profiles/ no es un id, y tampoco un nombre.
    assertNull(SteamProfileRef.parse("https://steamcommunity.com/profiles/123"))
    // Una URL de Steam que no es un perfil.
    assertNull(SteamProfileRef.parse("https://steamcommunity.com/app/440"))
  }
}

class SteamAuthServiceTest {

  @Test
  fun `con un id directo no se resuelve ningun nombre`() = runTest {
    val client = FakeHttpClient(
      respuestas = listOf("GetPlayerSummaries" to resumenDe("Walter")),
    )

    val credenciales = SteamAuthService(client).signIn("clave", ID)

    assertEquals(SteamCredentials("clave", ID, "Walter"), credenciales)
    assertTrue(client.urls.none { it.contains("ResolveVanityURL") })
  }

  @Test
  fun `un nombre personalizado se traduce a id`() = runTest {
    val client = FakeHttpClient(
      respuestas = listOf(
        "ResolveVanityURL" to """{"response":{"steamid":"$ID","success":1}}""",
        "GetPlayerSummaries" to resumenDe("Walter"),
      ),
    )

    val credenciales = SteamAuthService(client).signIn("clave", "walter")

    assertEquals(ID, credenciales.steamID)
    // El resumen se pide con el id ya resuelto, no con el nombre.
    assertTrue(client.urls.last().contains(ID))
  }

  @Test
  fun `un nombre que no existe no es un fallo de red`() = runTest {
    // Steam contesta 200 con success 42. Tratarlo como error de red mandaria al
    // usuario a revisar su conexion cuando lo que pasa es que se equivoco.
    val client = FakeHttpClient(
      respuestas = listOf("ResolveVanityURL" to """{"response":{"success":42}}"""),
    )

    assertLanza<SteamAuthError.PerfilNoEncontrado> {
      SteamAuthService(client).signIn("clave", "nadie")
    }
  }

  @Test
  fun `un id que no existe da perfil no encontrado`() = runTest {
    // Steam omite "players" en vez de mandar una lista vacia.
    val client = FakeHttpClient(
      respuestas = listOf("GetPlayerSummaries" to """{"response":{}}"""),
    )

    assertLanza<SteamAuthError.PerfilNoEncontrado> {
      SteamAuthService(client).signIn("clave", ID)
    }
  }

  @Test
  fun `un 403 se traduce a clave invalida`() = runTest {
    // Sin traducir llegaria como HttpError y la pantalla hablaria de red,
    // cuando el arreglo es volver a copiar la clave.
    val client = FakeHttpClient(
      fallos = listOf("GetPlayerSummaries" to NetworkError.HttpError(403)),
    )

    assertLanza<SteamAuthError.ClaveInvalida> { SteamAuthService(client).signIn("mala", ID) }
  }

  @Test
  fun `otros errores de red se dejan pasar`() = runTest {
    val client = FakeHttpClient(
      fallos = listOf("GetPlayerSummaries" to NetworkError.HttpError(500)),
    )

    assertLanza<NetworkError.HttpError> { SteamAuthService(client).signIn("clave", ID) }
  }

  @Test
  fun `no se toca la red si falta la clave o el perfil no se entiende`() = runTest {
    val client = FakeHttpClient()

    assertLanza<SteamAuthError.ClaveInvalida> { SteamAuthService(client).signIn("   ", ID) }
    assertLanza<SteamAuthError.PerfilIlegible> {
      SteamAuthService(client).signIn("clave", "no es un perfil")
    }

    assertTrue(client.urls.isEmpty())
  }

  @Test
  fun `un perfil sin nombre visible sigue siendo valido`() = runTest {
    // El nombre solo sirve para mostrarlo: su ausencia no invalida la conexion.
    val client = FakeHttpClient(
      respuestas = listOf(
        "GetPlayerSummaries" to """{"response":{"players":[{"steamid":"$ID"}]}}""",
      ),
    )

    assertNull(SteamAuthService(client).signIn("clave", ID).personaName)
  }
}

class SteamCredentialsStoreTest {

  /** Una fuente de configuracion como la que arma Gradle desde el xcconfig. */
  private fun config(vararg pares: Pair<AppSecrets.Key, String>) =
    AppSecrets.Source { clave -> pares.toMap()[clave] }

  @Test
  fun `lo conectado en la app gana sobre el archivo de configuracion`() {
    // Si no, conectar una cuenta nueva quedaria pisado por un xcconfig viejo y
    // el usuario no tendria forma de darse cuenta.
    val secure = InMemorySecureStore()
    val store = SteamCredentialsStore(
      secure,
      config(AppSecrets.Key.STEAM_API_KEY to "vieja", AppSecrets.Key.STEAM_ID to "111"),
    )

    store.save(SteamCredentials("nueva", ID, "Walter"))

    assertEquals(SteamCredentials("nueva", ID, "Walter"), store.credentials())
  }

  @Test
  fun `sin nada guardado se cae al archivo de configuracion`() {
    val store = SteamCredentialsStore(
      InMemorySecureStore(),
      config(AppSecrets.Key.STEAM_API_KEY to "clave", AppSecrets.Key.STEAM_ID to ID),
    )

    assertEquals(SteamCredentials("clave", ID, null), store.credentials())
  }

  @Test
  fun `media credencial no sirve`() {
    // Las dos hacen falta para llamar a la API de la biblioteca.
    val store = SteamCredentialsStore(
      InMemorySecureStore(),
      config(AppSecrets.Key.STEAM_ID to ID),
    )

    assertNull(store.credentials())
    // Pero el id solo si sirve: la wishlist no pide clave.
    assertEquals(ID, store.steamID())
  }

  @Test
  fun `desconectar deja de devolver lo guardado`() {
    val store = SteamCredentialsStore(InMemorySecureStore(), config())
    store.save(SteamCredentials("clave", ID, "Walter"))

    store.clear()

    assertNull(store.credentials())
    assertNull(store.steamID())
  }

  @Test
  fun `sin cuenta conectada el servicio falla al usarse, no al crearse`() = runTest {
    // Es lo que permite que la app arranque sin ninguna cuenta puesta.
    val store = SteamCredentialsStore(InMemorySecureStore(), config())
    val steam = SteamService.live(FakeHttpClient(), store)
    val deseos = SteamWishlistService.live(FakeHttpClient(), store)

    assertThrows(SteamAuthError.SinCredenciales::class.java) { steam.ownedGamesURL() }
    assertThrows(SteamAuthError.SinCredenciales::class.java) { deseos.wishlistURL() }
  }

  @Test
  fun `conectar surte efecto sin reconstruir el servicio`() {
    // El servicio se crea una vez al arrancar la app pero la cuenta se conecta
    // despues: si guardara las credenciales, haria falta reiniciar.
    val store = SteamCredentialsStore(InMemorySecureStore(), config())
    val steam = SteamService.live(FakeHttpClient(), store)

    store.save(SteamCredentials("clave", ID, null))

    assertTrue(steam.ownedGamesURL().contains(ID))
  }
}

class ITADKeyStoreTest {

  @Test
  fun `sin clave no se consulta nada y no es un error`() = runTest {
    // Los precios son opcionales: la lista de deseos se muestra igual sin ellos.
    val store = ITADKeyStore(InMemorySecureStore(), AppSecrets.Source { null })
    val servicio = ITADService(FakeHttpClient(), { store.key() })

    assertEquals(emptyMap<Int, Any>(), servicio.prices(listOf(440, 570)))
  }

  @Test
  fun `la clave guardada entra en las URLs`() {
    val store = ITADKeyStore(InMemorySecureStore(), AppSecrets.Source { null })
    val servicio = ITADService(FakeHttpClient(), { store.key() })

    store.save("  mi-clave  ")

    assertEquals("mi-clave", store.key())
    assertTrue(servicio.pricesURL().contains("mi-clave"))
  }
}
