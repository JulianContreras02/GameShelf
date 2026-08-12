package com.gameshelf.domain

import java.time.Instant
import java.util.UUID

/**
 * Etiqueta libre que el usuario le pone a sus juegos.
 *
 * Se diferencia de [GameCollection] en como se usa, no en la forma: una
 * coleccion se crea con un formulario (nombre, icono, color) y sirve para
 * agrupar a proposito; una etiqueta se escribe al vuelo mientras miras un
 * juego, y sirve para marcar cosas sueltas ("coop", "para el Deck",
 * "pendiente de DLC").
 */
data class GameTag(
  val id: UUID = UUID.randomUUID(),

  /**
   * Nombre tal como lo escribio el usuario la primera vez.
   *
   * Para comparar se usa [normalized], que ignora mayusculas y tildes: no
   * tiene sentido que "RPG" y "rpg" sean etiquetas distintas.
   */
  val name: String = "",

  val createdAt: Instant = Instant.now(),

  /** Juegos que llevan esta etiqueta. Puede llegar vacia; ver [Game]. */
  val games: List<Game> = emptyList(),
) {
  /** Cuantos juegos la usan. */
  val gameCount: Int get() = games.size

  /** Si no la usa ningun juego. */
  val isOrphan: Boolean get() = games.isEmpty()

  /** Forma con la que se compara: sin espacios sobrantes, en minusculas y sin tildes. */
  val normalized: String get() = normalize(name)

  companion object {
    /** Limite del nombre. Una etiqueta larga deja de servir como etiqueta. */
    const val MAX_NAME_LENGTH = 30

    /**
     * Crea una etiqueta limpiando el nombre, igual que hacia el `init` de iOS.
     */
    fun create(name: String): GameTag = GameTag(name = clean(name))

    /**
     * Quita los espacios sobrantes y colapsa los internos.
     *
     * "  juego   coop " queda como "juego coop".
     */
    fun clean(nombre: String): String =
      nombre.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")

    /**
     * Forma para comparar dos nombres: sin mayusculas ni tildes.
     *
     * Usa la misma regla que la busqueda de juegos, para que escribir "accion"
     * se comporte igual en los dos sitios.
     */
    fun normalize(nombre: String): String = clean(nombre).normalizedForSearch

    /** Si dos nombres son la misma etiqueta. */
    fun areEquivalent(uno: String, otro: String): Boolean = normalize(uno) == normalize(otro)
  }
}
