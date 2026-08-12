package com.gameshelf.data.sync

import com.gameshelf.data.epic.EpicGame
import com.gameshelf.data.epic.EpicGameMapper
import com.gameshelf.data.psn.PSNGame
import com.gameshelf.data.psn.PSNGameMapper
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.steam.FallbackNames
import com.gameshelf.data.steam.SteamGameDTO
import com.gameshelf.data.steam.SteamGameMapper
import com.gameshelf.data.steam.SteamWishlistGame
import com.gameshelf.data.steam.SteamWishlistMapper
import com.gameshelf.domain.Store

/**
 * Guarda en la base local la biblioteca que llega de Steam.
 *
 * La operacion es **idempotente**: correrla dos veces con los mismos datos
 * deja la base igual, sin duplicados.
 */
object SteamLibrarySyncer {

  /** Que cambio en una sincronizacion. */
  data class Result(
    /** Juegos que no existian y se crearon. */
    val created: Int = 0,
    /** Juegos que ya existian y se refrescaron. */
    val updated: Int = 0,
  ) {
    val total: Int get() = created + updated
  }

  /**
   * Sincroniza la lista de Steam contra lo que ya hay guardado.
   *
   * Un juego se considera "el mismo" si existe una entrada de Steam con su
   * mismo `appID`. Los juegos guardados que ya no vienen en la respuesta **no
   * se borran**: pueden faltar porque la peticion fallo a medias o porque
   * Steam los omitio, y borrar la biblioteca del usuario por eso seria mucho
   * peor que dejar un juego de mas.
   */
  suspend fun sync(
    dtos: List<SteamGameDTO>,
    store: GameStore,
    names: FallbackNames = FallbackNames.Default,
  ): Result {
    if (dtos.isEmpty()) return Result()

    val matcher = LibraryMatcher(Store.STEAM, store.allGames())
    var creados = 0
    var actualizados = 0

    for (dto in dtos) {
      when (val coincidencia = matcher.buscar(dto.appID.toString(), dto.name.orEmpty())) {
        is LibraryMatcher.Coincidencia.MismaTienda -> {
          val actualizado = SteamGameMapper.update(coincidencia.juego, dto)
          store.save(actualizado)
          matcher.registrar(actualizado)
          actualizados++
        }

        // Por nombre no se fusiona en Steam: el appid es el identificador y es
        // fiable. Dos juegos distintos con el mismo nombre son mas probables
        // que un appid equivocado.
        is LibraryMatcher.Coincidencia.OtraTienda,
        LibraryMatcher.Coincidencia.Nuevo,
        -> {
          val nuevo = SteamGameMapper.makeGame(dto, names)
          store.save(nuevo)
          matcher.registrar(nuevo)
          creados++
        }
      }
    }

    return Result(created = creados, updated = actualizados)
  }
}

/**
 * Guarda en la base local la lista de deseos que llega de Steam.
 *
 * Como el de la biblioteca, es **idempotente**.
 *
 * La diferencia con [SteamLibrarySyncer] es que aca si hay que reflejar las
 * bajas. Si compras un juego, Steam lo saca de tu lista y la app tiene que
 * enterarse. Pero "sacarlo de la lista" **nunca** significa borrar el juego ni
 * cambiarte el estado que le pusiste: solo se limpia `wishlistedAt`, que es el
 * dato de la tienda.
 */
object SteamWishlistSyncer {

  data class Result(
    val created: Int = 0,
    val updated: Int = 0,
    /** Juegos que ya no estan en la lista de Steam. */
    val removed: Int = 0,
  ) {
    val total: Int get() = created + updated
  }

  /**
   * Sincroniza la lista de deseos contra lo que ya hay guardado.
   *
   * @param allowRemovals Si se pueden quitar los que ya no vienen. Se pone en
   *   `false` cuando la respuesta llego vacia y no se sabe si es porque la
   *   lista esta vacia de verdad o porque es privada: en la duda, no se toca
   *   nada.
   */
  suspend fun sync(
    juegos: List<SteamWishlistGame>,
    store: GameStore,
    allowRemovals: Boolean = true,
  ): Result {
    val guardados = store.allGames()
    val matcher = LibraryMatcher(Store.STEAM, guardados)

    var creados = 0
    var actualizados = 0

    for (juego in juegos) {
      when (val coincidencia = matcher.buscar(juego.appID.toString(), juego.name)) {
        is LibraryMatcher.Coincidencia.MismaTienda -> {
          val actualizado = SteamWishlistMapper.update(coincidencia.juego, juego)
          store.save(actualizado)
          matcher.registrar(actualizado)
          actualizados++
        }

        is LibraryMatcher.Coincidencia.OtraTienda,
        LibraryMatcher.Coincidencia.Nuevo,
        -> {
          val nuevo = SteamWishlistMapper.makeGame(juego)
          store.save(nuevo)
          matcher.registrar(nuevo)
          creados++
        }
      }
    }

    val quitados = if (allowRemovals) quitarLosQueYaNoEstan(juegos, store) else 0

    return Result(created = creados, updated = actualizados, removed = quitados)
  }

  /**
   * Limpia la marca de wishlist en los juegos que Steam ya no reporta.
   *
   * No borra nada ni cambia el estado: solo deja de decir "esto esta en tu
   * lista de deseos de Steam", que es justo lo que dejo de ser cierto.
   */
  private suspend fun quitarLosQueYaNoEstan(
    juegos: List<SteamWishlistGame>,
    store: GameStore,
  ): Int {
    val vigentes = juegos.map { it.appID.toString() }.toSet()
    var quitados = 0

    store.entries(Store.STEAM)
      .filter { it.wishlistedAt != null && it.storeGameID !in vigentes }
      .forEach { entrada ->
        store.clearWishlisted(entrada.id)
        quitados++
      }

    return quitados
  }
}

/**
 * Guarda en la base local la biblioteca que llega de PlayStation.
 *
 * Igual que el de Steam: **idempotente**, y nunca borra. Un juego guardado que
 * deje de venir puede faltar porque la peticion fallo a medias, no porque el
 * usuario lo haya perdido.
 */
object PSNLibrarySyncer {

  data class Result(
    val created: Int = 0,
    val updated: Int = 0,
    /** Juegos que ya estaban por otra tienda y ahora tambien tienen PSN. */
    val merged: Int = 0,
  ) {
    val total: Int get() = created + updated
  }

  /**
   * Sincroniza los juegos de PSN contra lo que ya hay guardado.
   *
   * Un juego se reconoce por su entrada de PSN. Si no la tiene, se busca por
   * nombre: asi un juego que ya vino de Steam **no se duplica**, sino que suma
   * su entrada de PlayStation. Esa union es justo lo que hace util tener las
   * dos tiendas en la misma app.
   */
  suspend fun sync(juegos: List<PSNGame>, store: GameStore): Result {
    if (juegos.isEmpty()) return Result()

    val matcher = LibraryMatcher(Store.PSN, store.allGames())
    var creados = 0
    var actualizados = 0
    var fusionados = 0

    for (juego in juegos) {
      when (val coincidencia = matcher.buscar(juego.titleId, juego.name)) {
        is LibraryMatcher.Coincidencia.MismaTienda -> {
          val actualizado = PSNGameMapper.update(coincidencia.juego, juego)
          store.save(actualizado)
          matcher.registrar(actualizado)
          actualizados++
        }

        is LibraryMatcher.Coincidencia.OtraTienda -> {
          // El mismo juego, ya guardado desde otra tienda. Por aca entra
          // tambien la version de PC de un juego de consola: mismo nombre,
          // distinto titleId, y `update` le agrega su propia entrada.
          val actualizado = PSNGameMapper.update(coincidencia.juego, juego)
          store.save(actualizado)
          matcher.registrar(actualizado)
          fusionados++
        }

        LibraryMatcher.Coincidencia.Nuevo -> {
          val nuevo = PSNGameMapper.makeGame(juego)
          store.save(nuevo)
          matcher.registrar(nuevo)
          creados++
        }
      }
    }

    return Result(created = creados, updated = actualizados, merged = fusionados)
  }
}

/** Guarda en la base local la biblioteca que llega de Epic. Idempotente, nunca borra. */
object EpicLibrarySyncer {

  data class Result(
    val created: Int = 0,
    val updated: Int = 0,
    /** Juegos que ya estaban por otra tienda y ahora tambien tienen Epic. */
    val merged: Int = 0,
  ) {
    val total: Int get() = created + updated + merged
  }

  suspend fun sync(juegos: List<EpicGame>, store: GameStore): Result {
    if (juegos.isEmpty()) return Result()

    val matcher = LibraryMatcher(Store.EPIC, store.allGames())
    var creados = 0
    var actualizados = 0
    var fusionados = 0

    for (juego in juegos) {
      when (val coincidencia = matcher.buscar(juego.namespace, juego.name)) {
        is LibraryMatcher.Coincidencia.MismaTienda -> {
          val actualizado = EpicGameMapper.update(coincidencia.juego, juego)
          store.save(actualizado)
          matcher.registrar(actualizado)
          actualizados++
        }

        is LibraryMatcher.Coincidencia.OtraTienda -> {
          val actualizado = EpicGameMapper.update(coincidencia.juego, juego)
          store.save(actualizado)
          matcher.registrar(actualizado)
          fusionados++
        }

        LibraryMatcher.Coincidencia.Nuevo -> {
          val nuevo = EpicGameMapper.makeGame(juego)
          store.save(nuevo)
          matcher.registrar(nuevo)
          creados++
        }
      }
    }

    return Result(created = creados, updated = actualizados, merged = fusionados)
  }
}
