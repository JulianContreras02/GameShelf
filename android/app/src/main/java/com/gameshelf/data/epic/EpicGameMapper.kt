package com.gameshelf.data.epic

import com.gameshelf.data.steam.SteamGameMapper
import com.gameshelf.domain.Game
import com.gameshelf.domain.Store
import com.gameshelf.domain.StoreEntry
import java.time.Instant

/** Traduce los juegos de Epic a los modelos de dominio. */
object EpicGameMapper {

  /** Crea un `Game` nuevo con su entrada de Epic. */
  fun makeGame(juego: EpicGame): Game {
    val game = Game(
      name = juego.name,
      coverImageURL = juego.coverURL,
      playtimeHours = juego.playtimeHours,
    )
    return game.copy(storeEntries = listOf(makeStoreEntry(juego, game.id)))
  }

  /**
   * Crea la entrada de tienda correspondiente.
   *
   * El `storeGameID` es el namespace y no el appName: un juego tiene varios
   * appName (el ejecutable, sus DLC) y un solo namespace.
   */
  fun makeStoreEntry(juego: EpicGame, gameId: java.util.UUID? = null): StoreEntry = StoreEntry(
    store = Store.EPIC,
    storeGameID = juego.namespace,
    playtimeHours = juego.playtimeHours,
    lastSyncedAt = Instant.now(),
    gameId = gameId,
  )

  /** Actualiza un juego que ya existia. **No toca `status` ni `notes`.** */
  fun update(game: Game, juego: EpicGame): Game {
    // El nombre no se pisa: si el juego ya vino de Steam o PSN, el que tenga
    // suele ser mejor que el de Epic, donde algunos son nombres de sandbox.
    var actualizado = game.copy(coverImageURL = game.coverImageURL ?: juego.coverURL)

    val existente = actualizado.storeEntries.firstOrNull { it.store == Store.EPIC }
    val entradas = if (existente != null) {
      actualizado.storeEntries.map { entrada ->
        if (entrada.id != existente.id) {
          entrada
        } else {
          entrada.copy(
            storeGameID = juego.namespace,
            playtimeHours = juego.playtimeHours,
            lastSyncedAt = Instant.now(),
          )
        }
      }
    } else {
      actualizado.storeEntries + makeStoreEntry(juego, actualizado.id)
    }

    actualizado = actualizado.copy(storeEntries = entradas)
    return SteamGameMapper.recalculatePlaytime(actualizado)
  }
}
