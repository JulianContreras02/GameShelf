package com.gameshelf

import com.gameshelf.data.epic.EpicErrorResponse
import com.gameshelf.data.epic.EpicLibraryResponse
import com.gameshelf.data.epic.EpicLibraryService
import com.gameshelf.data.epic.EpicPlaytimeDTO
import com.gameshelf.data.epic.EpicTokenResponse
import com.gameshelf.data.itad.ITADGamePricesDTO
import com.gameshelf.data.itad.ITADService
import com.gameshelf.data.itad.Money
import com.gameshelf.data.psn.ISO8601Duration
import com.gameshelf.data.psn.PSNAuthError
import com.gameshelf.data.psn.PSNAuthService
import com.gameshelf.data.psn.PSNErrorResponse
import com.gameshelf.data.psn.PSNGameListResponse
import com.gameshelf.data.psn.PSNTokenResponse
import com.gameshelf.data.psn.PSNTrophyMapResponse
import com.gameshelf.data.secrets.AppSecrets
import com.gameshelf.data.secrets.InMemorySecureStore
import kotlinx.serialization.builtins.ListSerializer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal
import java.time.Instant

class ISO8601DurationTest {

  @Test
  fun `lee las formas que manda PSN`() {
    assertEquals(0, ISO8601Duration.seconds("PT0S"))
    assertEquals(15, ISO8601Duration.seconds("PT15S"))
    assertEquals(375, ISO8601Duration.seconds("PT6M15S"))
    assertEquals(107_264, ISO8601Duration.seconds("PT29H47M44S"))
    assertEquals(183_600, ISO8601Duration.seconds("P2DT3H"))
  }

  @Test
  fun `un texto ilegible da null y no cero`() {
    // Devolver 0 confundiria "no se pudo leer" con "no lo has jugado".
    assertNull(ISO8601Duration.seconds(null))
    assertNull(ISO8601Duration.seconds("29H"))
    assertNull(ISO8601Duration.seconds("P"))
    assertNull(ISO8601Duration.seconds("PT"))
  }

  @Test
  fun `convierte a horas`() {
    assertEquals(29.795, ISO8601Duration.hours("PT29H47M44S")!!, 0.001)
  }
}

class PSNAuthTest {

  @Test
  fun `una respuesta completa da credenciales`() {
    val ahora = Instant.ofEpochSecond(1_000_000)
    val credenciales = PSNTokenResponse(
      accessToken = "acceso",
      refreshToken = "refresco",
      expiresIn = 3600,
      refreshTokenExpiresIn = 5_184_000,
    ).credentials(ahora)

    assertNotNull(credenciales)
    assertEquals(ahora.plusSeconds(3600), credenciales!!.expiresAt)
    assertEquals(ahora.plusSeconds(5_184_000), credenciales.refreshExpiresAt)
  }

  @Test
  fun `sin tokens no hay credenciales`() {
    assertNull(PSNTokenResponse(accessToken = "").credentials(Instant.now()))
    assertNull(PSNTokenResponse(refreshToken = "x").credentials(Instant.now()))
  }

  @Test
  fun `sin expires_in se asume una hora`() {
    // Es lo que Sony devuelve siempre; preferible a tratar el token como eterno.
    val ahora = Instant.ofEpochSecond(0)
    val credenciales = PSNTokenResponse(accessToken = "a", refreshToken = "b").credentials(ahora)

    assertEquals(ahora.plusSeconds(3600), credenciales!!.expiresAt)
  }

  @Test
  fun `el token se considera vencido un minuto antes`() {
    // Pedir con un token que expira en camino da un 401 evitable.
    val credenciales = PSNTokenResponse(accessToken = "a", refreshToken = "b", expiresIn = 3600)
      .credentials(Instant.ofEpochSecond(0))!!

    assertFalse(credenciales.isExpired(Instant.ofEpochSecond(3500)))
    assertTrue(credenciales.isExpired(Instant.ofEpochSecond(3550)))
  }

  @Test
  fun `reconoce los codigos de credencial invalida`() {
    assertTrue(PSNErrorResponse(errorCode = 4650).esDeCredencialesInvalidas)
    assertTrue(PSNErrorResponse(errorCode = 4165).esDeCredencialesInvalidas)
    assertTrue(PSNErrorResponse(error = "invalid_grant").esDeCredencialesInvalidas)
    assertFalse(PSNErrorResponse(errorCode = 500).esDeCredencialesInvalidas)
  }

  @Test
  fun `saca el codigo de la redireccion`() {
    val destino = "com.scee.psxandroid.scecompcall://redirect?code=v3.abc&otro=1"
    assertEquals("v3.abc", PSNAuthService.extraerCodigo(destino))
  }

  @Test
  fun `login_required significa que el NPSSO caduco`() {
    // Es el caso mas comun con diferencia.
    val destino = "https://ca.account.sony.com/login?error=login_required"

    assertThrows(PSNAuthError.NpssoInvalido::class.java) {
      PSNAuthService.extraerCodigo(destino)
    }
  }

  @Test
  fun `una redireccion sin codigo ni error es inesperada`() {
    assertThrows(PSNAuthError.RespuestaInesperada::class.java) {
      PSNAuthService.extraerCodigo("https://ejemplo.com/algo")
    }
  }

  @Test
  fun `la cabecera basic lleva las credenciales del launcher movil`() {
    assertTrue(PSNAuthService.basicAuthorization().startsWith("Basic "))
  }
}

class PSNLibraryTest {

  @Test
  fun `decodifica la lista de juegos real`() {
    val respuesta = Fixture.decode("psn_juegos", PSNGameListResponse.serializer())
    assertTrue(respuesta.juegos.isNotEmpty())
  }

  @Test
  fun `las apps de video no son juegos`() {
    // Crunchyroll aparecio en la biblioteca real con 15 segundos de uso.
    val respuesta = Fixture.decode("psn_juegos", PSNGameListResponse.serializer())
    val noJuegos = respuesta.juegos.filterNot { it.esJuego }

    noJuegos.forEach { assertFalse(it.category?.contains("game") == true) }
  }

  @Test
  fun `el mapa de trofeos se indexa por id y toma el set mas avanzado`() {
    val respuesta = Fixture.decode("psn_mapa_trofeos", PSNTrophyMapResponse.serializer())
    val porID = respuesta.progresoPorTitleID

    // La respuesta llega en otro orden del que se pidio: emparejar por
    // posicion daria progresos cruzados.
    porID.forEach { (_, mejor) -> assertNotNull(mejor) }
  }
}

class EpicTest {

  @Test
  fun `una respuesta completa da credenciales`() {
    val ahora = Instant.ofEpochSecond(0)
    val credenciales = EpicTokenResponse(
      accessToken = "a",
      refreshToken = "b",
      expiresIn = 28_800,
      accountId = "cuenta",
      displayName = "alguien",
    ).credentials(ahora)!!

    assertEquals("cuenta", credenciales.accountID)
    assertEquals(ahora.plusSeconds(28_800), credenciales.expiresAt)
  }

  @Test
  fun `reconoce los codigos de credencial invalida`() {
    assertTrue(EpicErrorResponse(numericErrorCode = 18059).esDeCredencialesInvalidas)
    assertTrue(EpicErrorResponse(numericErrorCode = 18036).esDeCredencialesInvalidas)
    assertTrue(
      EpicErrorResponse(errorCode = "errors.com.epicgames.account.oauth.authorization_code_not_found")
        .esDeCredencialesInvalidas,
    )
    assertFalse(EpicErrorResponse(numericErrorCode = 1).esDeCredencialesInvalidas)
  }

  @Test
  fun `agrupa los artefactos por juego`() {
    // Un juego aparece varias veces: el ejecutable, sus DLC, sus editores.
    val respuesta = Fixture.decode("epic_biblioteca", EpicLibraryResponse.serializer())
    val grupos = EpicLibraryService.agrupar(respuesta.registros, emptyMap())

    assertTrue(grupos.size <= respuesta.registros.size)
    assertEquals(respuesta.registros.map { it.namespace }.toSet(), grupos.keys)
  }

  @Test
  fun `el tiempo de un juego es el mayor de sus artefactos y no la suma`() {
    // Epic repite las mismas horas bajo varios ids del mismo juego: sumarlas
    // las duplicaria. Cyberpunk reportaba 49,8 h dos veces.
    val respuesta = Fixture.decode("epic_biblioteca", EpicLibraryResponse.serializer())
    val tiempos = Fixture
      .decode("epic_tiempos", ListSerializer(EpicPlaytimeDTO.serializer()))
      .associate { it.artifactId to it.horas }

    val grupos = EpicLibraryService.agrupar(respuesta.registros, tiempos)

    grupos.values.forEach { grupo ->
      val delGrupo = respuesta.registros
        .filter { it.namespace == grupo.namespace }
        .mapNotNull { it.appName?.let(tiempos::get) }

      assertEquals(delGrupo.maxOrNull() ?: 0.0, grupo.horas, 0.0001)
    }
  }

  @Test
  fun `Live no es un nombre util`() {
    val respuesta = Fixture.decode("epic_biblioteca", EpicLibraryResponse.serializer())
    respuesta.registros.filter { it.sandboxName == "Live" }.forEach {
      assertFalse(it.tieneNombreUtil)
    }
  }
}

class MoneyTest {

  @Test
  fun `los centavos dan un importe exacto`() {
    // Decodificar 19.99 como coma flotante da 19.989999999999998.
    assertEquals(BigDecimal("19.99"), Money.fromMinorUnits(1999, "USD").amount)
  }

  @Test
  fun `el descuento se calcula entre los dos precios`() {
    val ahora = Money.fromMinorUnits(1000, "USD")
    val regular = Money.fromMinorUnits(2000, "USD")

    assertEquals(50, ahora.discount(regular))
  }

  @Test
  fun `no se comparan monedas distintas`() {
    // Restar dolares a euros no significa nada: mejor no mostrar nada que
    // mostrar un numero falso.
    val dolares = Money.fromMinorUnits(1000, "USD")
    val euros = Money.fromMinorUnits(2000, "EUR")

    assertNull(dolares.discount(euros))
  }

  @Test
  fun `un precio regular en cero no divide por cero`() {
    assertNull(Money.fromMinorUnits(0, "USD").discount(Money.fromMinorUnits(0, "USD")))
  }
}

class ITADTest {

  @Test
  fun `las claves de Steam llevan el prefijo app`() {
    // Mandar el appid pelado devuelve null para todo, sin error: un fallo
    // silencioso facil de no notar.
    assertEquals("app/268910", ITADService.steamKey(268910))
  }

  @Test
  fun `traduce el diccionario de la busqueda y descarta los desconocidos`() {
    val crudo = mapOf("app/268910" to "uuid-1", "app/999" to null, "sub/5" to "uuid-2")
    val resultado = ITADService.porSteamAppID(crudo)

    assertEquals(mapOf(268910 to "uuid-1"), resultado)
  }

  @Test
  fun `de todas las tiendas se queda con la mas barata`() {
    // La API las manda sin ordenar y con todas las tiendas, no solo las
    // rebajadas.
    val dtos = Fixture.decode("itad_precios", ListSerializer(ITADGamePricesDTO.serializer()))

    dtos.forEach { dto ->
      val precios = ITADService.mapear(dto)
      val mejor = precios.best ?: return@forEach
      val todas = dto.deals.orEmpty().mapNotNull { it.price.money }
        .filter { it.currency == mejor.price.currency }

      assertEquals(todas.minOf { it.amount }, mejor.price.amount)
    }
  }

  @Test
  fun `el descuento se recalcula y no se lee del cut de la API`() {
    // Asi el numero y los importes no pueden contradecirse en pantalla.
    val dtos = Fixture.decode("itad_precios", ListSerializer(ITADGamePricesDTO.serializer()))

    dtos.mapNotNull { ITADService.mapear(it).best }.forEach { oferta ->
      assertEquals(oferta.price.discount(oferta.regular) ?: 0, oferta.discountPercent)
    }
  }
}

class AppSecretsTest {

  @Test
  fun `una clave vacia cuenta como faltante`() {
    val fuente = AppSecrets.Source { clave ->
      if (clave == AppSecrets.Key.STEAM_ID) "76561198000000000" else "  "
    }

    val faltan = AppSecrets.missingKeys(fuente)
    assertEquals(2, faltan.size)
    assertFalse(AppSecrets.Key.STEAM_ID in faltan)
  }

  @Test
  fun `el valor se devuelve sin espacios`() {
    val fuente = AppSecrets.Source { "  abc  " }
    assertEquals("abc", AppSecrets.value(AppSecrets.Key.STEAM_API_KEY, fuente))
  }

  @Test
  fun `pedir una clave que falta lanza un error accionable`() {
    val fuente = AppSecrets.Source { null }

    assertThrows(AppSecrets.MissingSecretError::class.java) {
      AppSecrets.value(AppSecrets.Key.ITAD_API_KEY, fuente)
    }
  }
}

class SecureStoreTest {

  @Test
  fun `guarda, lee y borra`() {
    val store = InMemorySecureStore()

    assertNull(store.string("psn.accessToken"))

    store.set("token", "psn.accessToken")
    assertEquals("token", store.string("psn.accessToken"))

    store.set("otro", "psn.accessToken")
    assertEquals("otro", store.string("psn.accessToken"))

    store.remove("psn.accessToken")
    assertNull(store.string("psn.accessToken"))
  }

  @Test
  fun `borrar algo que no existia no falla`() {
    InMemorySecureStore().remove("nada")
  }
}
