package com.gameshelf

import com.gameshelf.data.steam.SteamGameDTO
import com.gameshelf.data.steam.SteamGameMapper
import com.gameshelf.data.steam.SteamOwnedGamesResponse
import com.gameshelf.data.steam.SteamStoreItemsResponse
import com.gameshelf.data.steam.SteamWishlistResponse
import com.gameshelf.data.sync.SteamLibrarySyncer
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Los DTOs de Steam contra las respuestas reales guardadas. */
class SteamDTOTest {

  @Test
  fun `decodifica la biblioteca real`() {
    val respuesta = Fixture.decode("steam_owned_games", SteamOwnedGamesResponse.serializer())
    val juegos = respuesta.response.games

    assertTrue(juegos.isNotEmpty())
    assertEquals(juegos.size, respuesta.response.count)
    assertFalse(respuesta.response.isEmpty)
  }

  @Test
  fun `una respuesta vacia no es un error`() {
    // Steam manda `{"response":{}}` con HTTP 200 cuando el perfil es privado
    // **o** cuando la biblioteca esta vacia: no hay forma de distinguirlos.
    val respuesta = Fixture.decode("steam_empty_library", SteamOwnedGamesResponse.serializer())

    assertTrue(respuesta.response.isEmpty)
    assertEquals(0, respuesta.response.count)
    assertTrue(respuesta.response.games.isEmpty())
  }

  @Test
  fun `los minutos se convierten a horas`() {
    val dto = SteamGameDTO(appID = 1, playtimeMinutes = 90)
    assertEquals(1.5, dto.playtimeHours, 0.0001)
  }

  @Test
  fun `sin actividad reciente el campo no viene y eso significa cero`() {
    // Steam solo manda `playtime_2weeks` si hubo actividad. Que falte no es un
    // dato perdido: significa "no lo has tocado".
    val dto = SteamGameDTO(appID = 1, playtimeMinutes = 600)

    assertEquals(0.0, dto.playtimeLast2WeeksHours, 0.0001)
    assertFalse(dto.isRecentlyPlayed)
  }

  @Test
  fun `un timestamp en cero significa que nunca se jugo`() {
    assertNull(SteamGameDTO(appID = 1, lastPlayedTimestamp = 0).lastPlayed)
    assertNotNull(SteamGameDTO(appID = 1, lastPlayedTimestamp = 1_700_000_000).lastPlayed)
  }

  @Test
  fun `el icono necesita su hash`() {
    assertNull(SteamGameDTO(appID = 1).iconURL)
    assertNull(SteamGameDTO(appID = 1, iconHash = "").iconURL)
    assertNotNull(SteamGameDTO(appID = 1, iconHash = "abc").iconURL)
  }

  @Test
  fun `decodifica las fichas de tienda`() {
    val respuesta = Fixture.decode("steam_store_items", SteamStoreItemsResponse.serializer())
    assertTrue(respuesta.items.isNotEmpty())
    assertTrue(respuesta.items.any { it.isUsable })
  }

  @Test
  fun `decodifica la lista de deseos`() {
    val respuesta = Fixture.decode("steam_wishlist", SteamWishlistResponse.serializer())
    assertTrue(respuesta.items.isNotEmpty())
    assertFalse(respuesta.isMissingItems)
  }

  @Test
  fun `una wishlist privada llega sin la lista`() {
    val respuesta = Fixture.decode("steam_wishlist_privada", SteamWishlistResponse.serializer())
    assertTrue(respuesta.isMissingItems)
    assertTrue(respuesta.items.isEmpty())
  }
}

/** El mapeo de Steam al dominio. */
class SteamGameMapperTest {

  @Test
  fun `sin nombre se usa el appID`() {
    val juego = SteamGameMapper.makeGame(SteamGameDTO(appID = 620))
    assertTrue(juego.name.contains("620"))
  }

  @Test
  fun `un juego nuevo nace en backlog y sin notas`() {
    // El estado y las notas son del usuario, no de Steam.
    val juego = SteamGameMapper.makeGame(SteamGameDTO(appID = 620, name = "Portal 2"))

    assertEquals(PlayStatus.BACKLOG, juego.status)
    assertEquals("", juego.notes)
    assertEquals(1, juego.storeEntries.size)
    assertEquals(Store.STEAM, juego.storeEntries.first().store)
  }

  @Test
  fun `actualizar no pisa el estado ni las notas`() {
    // Es la regla mas importante de toda la sincronizacion.
    val original = SteamGameMapper
      .makeGame(SteamGameDTO(appID = 620, name = "Portal 2", playtimeMinutes = 60))
      .copy(status = PlayStatus.FINISHED, notes = "Lo termine en 2019")

    val actualizado = SteamGameMapper.update(
      original,
      SteamGameDTO(appID = 620, name = "Portal 2", playtimeMinutes = 300),
    )

    assertEquals(PlayStatus.FINISHED, actualizado.status)
    assertEquals("Lo termine en 2019", actualizado.notes)
    assertEquals(5.0, actualizado.playtimeHours, 0.0001)
  }

  @Test
  fun `si el juego venia de otra tienda se le agrega la entrada de Steam`() {
    val original = SteamGameMapper.makeGame(SteamGameDTO(appID = 620, name = "Portal 2"))
      .let { it.copy(storeEntries = it.storeEntries.map { e -> e.copy(store = Store.PSN) }) }

    val actualizado = SteamGameMapper.update(original, SteamGameDTO(appID = 620, name = "Portal 2"))

    assertEquals(2, actualizado.storeEntries.size)
    assertTrue(actualizado.isAvailable(Store.STEAM))
    assertTrue(actualizado.isAvailable(Store.PSN))
  }

  @Test
  fun `el total suma las horas de todas las tiendas`() {
    val juego = SteamGameMapper.makeGame(SteamGameDTO(appID = 1, playtimeMinutes = 60))
    val conDos = juego.copy(
      storeEntries = juego.storeEntries + juego.storeEntries.first()
        .copy(id = java.util.UUID.randomUUID(), store = Store.PSN, playtimeHours = 2.0),
    )

    assertEquals(3.0, SteamGameMapper.recalculatePlaytime(conDos).playtimeHours, 0.0001)
  }
}

/** La sincronizacion de la biblioteca. */
class SteamLibrarySyncerTest {

  @Test
  fun `crea los juegos que no existian`() = runTest {
    val store = FakeGameStore()
    val dtos = Fixture.decode("steam_owned_games", SteamOwnedGamesResponse.serializer())
      .response.games

    val resultado = SteamLibrarySyncer.sync(dtos, store)

    assertEquals(dtos.size, resultado.created)
    assertEquals(0, resultado.updated)
    assertEquals(dtos.size, store.gameCount())
  }

  @Test
  fun `correrla dos veces no duplica nada`() = runTest {
    // La propiedad que importa de verdad: es idempotente.
    val store = FakeGameStore()
    val dtos = Fixture.decode("steam_owned_games", SteamOwnedGamesResponse.serializer())
      .response.games

    SteamLibrarySyncer.sync(dtos, store)
    val segunda = SteamLibrarySyncer.sync(dtos, store)

    assertEquals(0, segunda.created)
    assertEquals(dtos.size, segunda.updated)
    assertEquals(dtos.size, store.gameCount())
  }

  @Test
  fun `no borra los juegos que dejaron de venir`() = runTest {
    // Pueden faltar porque la peticion fallo a medias. Borrar la biblioteca
    // del usuario por eso seria mucho peor que dejar un juego de mas.
    val store = FakeGameStore()
    val todos = Fixture.decode("steam_owned_games", SteamOwnedGamesResponse.serializer())
      .response.games

    SteamLibrarySyncer.sync(todos, store)
    SteamLibrarySyncer.sync(todos.take(1), store)

    assertEquals(todos.size, store.gameCount())
  }

  @Test
  fun `una lista vacia no toca nada`() = runTest {
    val store = FakeGameStore()
    val resultado = SteamLibrarySyncer.sync(emptyList(), store)

    assertEquals(0, resultado.total)
    assertEquals(0, store.escrituras)
  }
}
