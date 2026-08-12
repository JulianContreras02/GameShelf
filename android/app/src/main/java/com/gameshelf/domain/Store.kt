package com.gameshelf.domain

/**
 * Tienda de la que proviene un juego.
 *
 * Se persiste por su [id] de texto (no por el ordinal del enum) para que
 * agregar o reordenar casos no corrompa los datos ya guardados. Es la misma
 * decision que en la version de iOS.
 */
enum class Store(val id: String) {
  STEAM("steam"),
  PSN("psn"),
  EPIC("epic");

  /**
   * Nombre para mostrar en pantalla.
   *
   * Son nombres propios de marca: no se traducen, por eso viven aca y no en
   * `strings.xml`.
   */
  val displayName: String
    get() = when (this) {
      STEAM -> "Steam"
      PSN -> "PlayStation Network"
      EPIC -> "Epic Games"
    }

  companion object {
    /** Busca una tienda por su id guardado. `null` si no se reconoce. */
    fun fromId(id: String): Store? = entries.firstOrNull { it.id == id }
  }
}
