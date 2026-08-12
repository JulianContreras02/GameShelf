package com.gameshelf.data.psn

import com.gameshelf.data.steam.SteamGameMapper
import com.gameshelf.domain.Game
import com.gameshelf.domain.Store
import com.gameshelf.domain.StoreEntry
import java.time.Instant

/**
 * Traduce los juegos de PSN a los modelos de dominio.
 *
 * Igual que su equivalente de Steam: funcion pura, sin base de datos, para
 * poder probarla sola.
 */
object PSNGameMapper {

  /**
   * Crea un `Game` nuevo con su entrada de PlayStation.
   *
   * Nace en `BACKLOG`: el estado lo pone el usuario, no la tienda.
   */
  fun makeGame(juego: PSNGame): Game {
    val game = Game(
      name = juego.name,
      coverImageURL = juego.coverURL,
      playtimeHours = juego.playtimeHours ?: 0.0,
    )
    return game.copy(storeEntries = listOf(makeStoreEntry(juego, game.id)))
  }

  /** Crea la entrada de tienda correspondiente. */
  fun makeStoreEntry(juego: PSNGame, gameId: java.util.UUID? = null): StoreEntry = StoreEntry(
    store = Store.PSN,
    storeGameID = juego.titleId,
    playtimeHours = juego.playtimeHours ?: 0.0,
    lastPlayedAt = juego.lastPlayedAt,
    trophyProgress = juego.trophyProgress,
    launchCount = juego.playCount,
    earnedTrophies = juego.earnedTrophies,
    definedTrophies = juego.definedTrophies,
    lastSyncedAt = Instant.now(),
    gameId = gameId,
  )

  /**
   * Actualiza un juego que ya existia.
   *
   * **No toca `status` ni `notes`.** Misma regla que en Steam: son del usuario
   * y ninguna sincronizacion los cambia.
   */
  fun update(game: Game, juego: PSNGame): Game {
    var actualizado = game.copy(
      name = juego.name,
      coverImageURL = juego.coverURL ?: game.coverImageURL,
    )

    // Se busca por id de juego y no solo por tienda: PSN lista el mismo juego
    // dos veces cuando existe en consola y en PC (`ps5_native_game` y
    // `pspc_game`), con titleId y horas distintas. Buscando solo por tienda, la
    // segunda version pisaria a la primera y se perderian sus horas. Asi cada
    // version tiene su entrada y el total las suma.
    val existente = actualizado.storeEntries.firstOrNull {
      it.store == Store.PSN && it.storeGameID == juego.titleId
    }

    val entradas = if (existente != null) {
      actualizado.storeEntries.map { entrada ->
        if (entrada.id == existente.id) actualizar(entrada, juego) else entrada
      }
    } else {
      actualizado.storeEntries + makeStoreEntry(juego, actualizado.id)
    }

    actualizado = actualizado.copy(storeEntries = entradas)
    return SteamGameMapper.recalculatePlaytime(actualizado)
  }

  /**
   * Solo se pisa lo que llego bien.
   *
   * Si PSN mando una duracion ilegible, la que ya estaba guardada es mejor que
   * un cero.
   */
  private fun actualizar(entrada: StoreEntry, juego: PSNGame): StoreEntry = entrada.copy(
    playtimeHours = juego.playtimeHours ?: entrada.playtimeHours,
    lastPlayedAt = juego.lastPlayedAt ?: entrada.lastPlayedAt,
    trophyProgress = juego.trophyProgress ?: entrada.trophyProgress,
    earnedTrophies = juego.earnedTrophies ?: entrada.earnedTrophies,
    definedTrophies = juego.definedTrophies ?: entrada.definedTrophies,
    launchCount = juego.playCount ?: entrada.launchCount,
    lastSyncedAt = Instant.now(),
  )
}
