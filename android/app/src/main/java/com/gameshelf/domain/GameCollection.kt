package com.gameshelf.domain

import java.time.Instant
import java.util.UUID

/**
 * Una carpeta creada por el usuario para agrupar juegos.
 *
 * Es lo que ninguna tienda permite: juntar en un mismo grupo juegos de Steam,
 * PSN y Epic. Un juego puede estar en varias colecciones a la vez.
 *
 * El tipo se llama `GameCollection` y no `Collection` por la misma razon que
 * en la version de iOS: ahi sombreaba `Swift.Collection`, y aca sombrearia
 * `kotlin.collections.Collection`.
 *
 * Borrar una coleccion **no borra los juegos**, solo deshace la agrupacion:
 * en Room eso es un `ON DELETE CASCADE` sobre la tabla puente, no sobre los
 * juegos.
 */
data class GameCollection(
  val id: UUID = UUID.randomUUID(),

  val name: String = "",

  /** Nombre del icono, como valor de dominio. La UI lo traduce a un vector. */
  val symbol: CollectionSymbol = DEFAULT_SYMBOL,

  /** Color de la coleccion. */
  val color: CollectionColor = CollectionColor.DEFAULT,

  /** Posicion en la lista. El usuario las reordena arrastrando. */
  val sortOrder: Int = 0,

  val createdAt: Instant = Instant.now(),

  /**
   * Juegos que contiene.
   *
   * Puede llegar vacia cuando la coleccion viaja dentro de un [Game]: ver la
   * nota sobre el ciclo en la documentacion de [Game].
   */
  val games: List<Game> = emptyList(),
) {
  /** Cuantos juegos tiene. */
  val gameCount: Int get() = games.size

  /** Si no tiene ningun juego. */
  val isEmpty: Boolean get() = games.isEmpty()

  /** Horas jugadas sumando todos sus juegos. */
  val totalPlaytimeHours: Double get() = games.sumOf { it.playtimeHours }

  /** Agrega un juego, sin duplicarlo si ya estaba. */
  fun add(game: Game): GameCollection =
    if (contains(game)) this else copy(games = games + game)

  /** Quita un juego de la coleccion. El juego no se borra. */
  fun remove(game: Game): GameCollection =
    copy(games = games.filterNot { it.id == game.id })

  /** Si el juego ya esta en la coleccion. */
  fun contains(game: Game): Boolean = games.any { it.id == game.id }

  companion object {
    val DEFAULT_SYMBOL = CollectionSymbol.FOLDER
  }
}

/**
 * Iconos que puede llevar una coleccion.
 *
 * En iOS esto era un nombre libre de SF Symbol. Aca es un enum cerrado: los
 * iconos de Material se referencian por propiedad, no por cadena, asi que un
 * nombre guardado que ya no exista no puede resolverse en tiempo de ejecucion.
 * Cerrar el conjunto convierte ese fallo en imposible.
 */
enum class CollectionSymbol(val id: String) {
  FOLDER("folder"),
  STAR("star"),
  HEART("heart"),
  BOOKMARK("bookmark"),
  FLAG("flag"),
  TROPHY("trophy"),
  GAMEPAD("gamepad"),
  CLOCK("clock"),
  SPARKLES("sparkles"),
  LIST("list");

  companion object {
    /** Busca por id guardado; si no se reconoce, cae al icono por defecto. */
    fun fromId(id: String): CollectionSymbol =
      entries.firstOrNull { it.id == id } ?: FOLDER
  }
}
