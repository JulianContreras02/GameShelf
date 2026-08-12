package com.gameshelf.domain

import java.time.Instant
import java.util.UUID

/**
 * Un juego tal como existe en una tienda concreta.
 *
 * El mismo [Game] puede tener varias entradas: una por cada tienda donde el
 * usuario lo tenga. Aca vive todo lo que depende de la tienda (el id de esa
 * tienda, la URL de su ficha, cuanto se jugo ahi), y en [Game] lo que es comun
 * al juego sin importar donde se compro.
 */
data class StoreEntry(
  val id: UUID = UUID.randomUUID(),

  val store: Store = Store.STEAM,

  /** Identificador del juego dentro de esa tienda. En Steam es el appid. */
  val storeGameID: String = "",

  /** Ficha del juego en la tienda. Texto y no URL, igual que en iOS. */
  val storeURL: String? = null,

  /** Horas jugadas registradas por esta tienda en particular. */
  val playtimeHours: Double = 0.0,

  /**
   * Horas jugadas en las ultimas dos semanas, segun la tienda.
   *
   * `0` si no hubo actividad. Viene de `playtime_2weeks` en Steam, que solo
   * manda el campo cuando el juego se toco hace poco.
   */
  val recentPlaytimeHours: Double = 0.0,

  /**
   * Ultima vez que el usuario jugo, segun la tienda.
   *
   * `null` si nunca lo jugo ahi. Viene de `rtime_last_played` en Steam.
   */
  val lastPlayedAt: Instant? = null,

  /**
   * Cuando el usuario lo puso en la lista de deseos de esta tienda.
   *
   * `null` si no esta en ella. Es un **dato de la tienda**, distinto de
   * `Game.status == WISHLIST`, que es una decision del usuario: puedes tener
   * un juego en tu lista de deseos de Steam y haberlo marcado como terminado
   * porque lo jugaste en consola.
   *
   * Sirve ademas para saber que dejo de estar en la lista: si sincronizas y ya
   * no viene, se pone en `null` sin tocar el estado.
   */
  val wishlistedAt: Instant? = null,

  /**
   * Porcentaje de trofeos o logros conseguidos, de 0 a 100.
   *
   * `null` si la tienda no lleva la cuenta, o si el juego no tiene trofeos.
   * Distinto de `0`, que significa "los tiene y no has conseguido ninguno".
   */
  val trophyProgress: Int? = null,

  /** Cuantas veces se ha abierto el juego, si la tienda lo cuenta. */
  val launchCount: Int? = null,

  /** Trofeos conseguidos, por tipo. */
  val earnedTrophies: TrophyCounts? = null,

  /**
   * Trofeos que tiene el juego en total, por tipo.
   *
   * Va aparte de los conseguidos porque hacen falta los dos para decir
   * "llevas 52 de 58 bronces".
   */
  val definedTrophies: TrophyCounts? = null,

  /**
   * Si la tienda dice que el juego todavia no ha salido.
   *
   * No basta con mirar `Game.releaseDate`: Steam informa el lanzamiento de una
   * de dos formas y nunca de las dos a la vez. O manda una fecha aproximada
   * (el 31 de diciembre quiere decir "en algun momento de este ano"), o manda
   * solo un texto ("Proximamente") y ninguna fecha. En ese segundo caso, sin
   * este campo el juego pareceria ya lanzado.
   */
  val comingSoon: Boolean = false,

  /** Ultima vez que se sincronizo con la tienda. */
  val lastSyncedAt: Instant? = null,

  /** Id del juego al que pertenece. La relacion inversa esta en [Game.storeEntries]. */
  val gameId: UUID? = null,
)
