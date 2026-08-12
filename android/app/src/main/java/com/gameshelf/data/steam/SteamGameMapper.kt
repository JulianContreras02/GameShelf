package com.gameshelf.data.steam

import com.gameshelf.domain.Game
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.StoreEntry
import java.time.Instant

/**
 * Nombre de respaldo cuando una tienda no manda el titulo.
 *
 * Va detras de una interfaz porque el texto es traducible y los servicios no
 * conocen `Context`. La implementacion por defecto usa el idioma base de la
 * app; la de produccion, en la capa de UI, lo saca de `strings.xml`.
 */
fun interface FallbackNames {
  fun steamGame(appID: Int): String

  companion object {
    val Default = FallbackNames { appID -> "Juego de Steam $appID" }
  }
}

/**
 * Traduce los DTOs de Steam a los modelos de dominio.
 *
 * Vive aparte del sincronizador a proposito: la traduccion es una funcion pura
 * sin base de datos de por medio, y eso la hace facil de probar.
 *
 * Donde la version de iOS mutaba el objeto guardado, aca [update] devuelve una
 * copia: el modelo de Android es inmutable y quien escribe es el repositorio.
 * La regla importante no cambia.
 */
object SteamGameMapper {

  /**
   * Nombre a usar cuando Steam no manda uno.
   *
   * Pasa cuando se consulta sin `include_appinfo=1`. Es preferible mostrar el
   * appID a dejar la fila en blanco. El numero va como texto y no formateado:
   * con separador de miles salia "Juego de Steam 1.245.620".
   */
  fun fallbackName(appID: Int, names: FallbackNames = FallbackNames.Default): String =
    names.steamGame(appID)

  /**
   * Crea un `Game` nuevo con su entrada de Steam.
   *
   * El `status` queda en `BACKLOG` y las notas vacias: son datos del usuario,
   * no de Steam.
   */
  fun makeGame(dto: SteamGameDTO, names: FallbackNames = FallbackNames.Default): Game {
    val game = Game(
      name = dto.name ?: fallbackName(dto.appID, names),
      coverImageURL = dto.coverURL,
      playtimeHours = dto.playtimeHours,
    )
    return game.copy(storeEntries = listOf(makeStoreEntry(dto, game.id)))
  }

  /** Crea la entrada de tienda correspondiente al DTO. */
  fun makeStoreEntry(dto: SteamGameDTO, gameId: java.util.UUID? = null): StoreEntry = StoreEntry(
    store = Store.STEAM,
    storeGameID = dto.appID.toString(),
    storeURL = dto.storeURL,
    playtimeHours = dto.playtimeHours,
    recentPlaytimeHours = dto.playtimeLast2WeeksHours,
    lastPlayedAt = dto.lastPlayed,
    lastSyncedAt = Instant.now(),
    gameId = gameId,
  )

  /**
   * Actualiza un juego existente con datos frescos de Steam.
   *
   * **Solo toca lo que es de Steam.** Las notas, el estado y las colecciones
   * son del usuario y no se sobrescriben nunca: esa es la regla mas importante
   * de la sincronizacion.
   */
  fun update(game: Game, dto: SteamGameDTO): Game {
    // Datos de Steam: se refrescan
    var actualizado = game.copy(
      name = dto.name ?: game.name,
      coverImageURL = dto.coverURL,
    )

    // La entrada de Steam se actualiza, o se crea si el juego ya existia por
    // otra tienda
    val existente = actualizado.storeEntries.firstOrNull { it.store == Store.STEAM }
    val entradas = if (existente != null) {
      actualizado.storeEntries.map { entrada ->
        if (entrada.id != existente.id) {
          entrada
        } else {
          entrada.copy(
            storeGameID = dto.appID.toString(),
            storeURL = dto.storeURL,
            playtimeHours = dto.playtimeHours,
            recentPlaytimeHours = dto.playtimeLast2WeeksHours,
            lastPlayedAt = dto.lastPlayed,
            lastSyncedAt = Instant.now(),
          )
        }
      }
    } else {
      actualizado.storeEntries + makeStoreEntry(dto, actualizado.id)
    }

    actualizado = actualizado.copy(storeEntries = entradas)

    // game.notes, game.status y game.addedAt NO se tocan: son del usuario.
    return recalculatePlaytime(actualizado)
  }

  /**
   * Recalcula las horas totales sumando todas las tiendas.
   *
   * Hace falta porque `Game.playtimeHours` es el total y cada entrada lleva lo
   * suyo: si solo se actualizara la entrada, el total quedaria viejo.
   */
  fun recalculatePlaytime(game: Game): Game =
    game.copy(playtimeHours = game.storeEntries.sumOf { it.playtimeHours })
}

/**
 * Traduce los juegos de la lista de deseos a los modelos de dominio.
 *
 * Va aparte de [SteamGameMapper] por la misma razon que en iOS: es una funcion
 * pura, sin base de datos, y asi se prueba sola.
 */
object SteamWishlistMapper {

  /**
   * Crea un `Game` nuevo a partir de un juego de la lista de deseos.
   *
   * Nace con `status = WISHLIST`, que es lo que el usuario espera ver.
   * `playtimeHours` queda en 0: no lo tiene, no lo ha jugado.
   */
  fun makeGame(juego: SteamWishlistGame): Game {
    val game = Game(
      name = juego.name,
      coverImageURL = juego.coverURL,
      releaseDate = juego.releaseDate,
      status = PlayStatus.WISHLIST,
    )
    return game.copy(storeEntries = listOf(makeStoreEntry(juego, game.id)))
  }

  /** Crea la entrada de tienda correspondiente. */
  fun makeStoreEntry(juego: SteamWishlistGame, gameId: java.util.UUID? = null): StoreEntry =
    StoreEntry(
      store = Store.STEAM,
      storeGameID = juego.appID.toString(),
      storeURL = juego.storeURL,
      wishlistedAt = juego.addedAt ?: Instant.now(),
      comingSoon = juego.isComingSoon,
      lastSyncedAt = Instant.now(),
      gameId = gameId,
    )

  /**
   * Actualiza un juego que ya existia.
   *
   * **No toca `status`.** Es la misma regla que en la biblioteca: si marcaste
   * como terminado un juego que sigue en tu lista de deseos de Steam porque lo
   * jugaste en consola, la sincronizacion no te lo cambia. Lo unico que se
   * escribe es el hecho de la tienda: que esta en la lista, y desde cuando.
   *
   * Tampoco pisa las horas jugadas: un juego puede estar en la lista de deseos
   * y a la vez ser uno que ya tienes (pasa con los DLC y las ediciones
   * completas), y ahi las horas las manda la biblioteca, no la wishlist.
   */
  fun update(game: Game, juego: SteamWishlistGame): Game {
    var actualizado = game.copy(
      name = juego.name,
      // La caratula solo se pone si falta: la que ya tenga viene de la
      // biblioteca, que es igual de buena y evita que la fila parpadee.
      coverImageURL = game.coverImageURL ?: juego.coverURL,
      releaseDate = game.releaseDate ?: juego.releaseDate,
    )

    val existente = actualizado.storeEntries.firstOrNull { it.store == Store.STEAM }
    val entradas = if (existente != null) {
      actualizado.storeEntries.map { entrada ->
        if (entrada.id != existente.id) {
          entrada
        } else {
          entrada.copy(
            storeGameID = juego.appID.toString(),
            storeURL = entrada.storeURL ?: juego.storeURL,
            // Se conserva la fecha que ya estuviera: es cuando lo deseaste por
            // primera vez, y Steam a veces la reporta distinta.
            wishlistedAt = entrada.wishlistedAt ?: juego.addedAt ?: Instant.now(),
            // Esto si se refresca cada vez: un juego que sale deja de ser futuro.
            comingSoon = juego.isComingSoon,
            lastSyncedAt = Instant.now(),
          )
        }
      }
    } else {
      actualizado.storeEntries + makeStoreEntry(juego, actualizado.id)
    }

    // game.status, game.notes, game.playtimeHours y las colecciones NO se
    // tocan: o son del usuario, o los manda la sincronizacion de la biblioteca.
    return actualizado.copy(storeEntries = entradas)
  }
}
