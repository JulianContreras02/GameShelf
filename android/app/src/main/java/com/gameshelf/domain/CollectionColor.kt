package com.gameshelf.domain

import androidx.annotation.StringRes
import com.gameshelf.R

/**
 * Color de una coleccion.
 *
 * Es un enum con opciones fijas y no un color libre por dos razones: la base
 * de datos no persiste un color de forma directa, y una paleta acotada evita
 * que el usuario elija un color ilegible sobre el fondo.
 *
 * Se guarda por su [id] de texto para que agregar o reordenar casos no
 * corrompa lo ya guardado.
 */
enum class CollectionColor(val id: String, @StringRes val displayNameRes: Int) {
  BLUE("blue", R.string.color_blue),
  GREEN("green", R.string.color_green),
  ORANGE("orange", R.string.color_orange),
  PINK("pink", R.string.color_pink),
  PURPLE("purple", R.string.color_purple),
  RED("red", R.string.color_red),
  TEAL("teal", R.string.color_teal),
  YELLOW("yellow", R.string.color_yellow),
  GRAY("gray", R.string.color_gray);

  companion object {
    /** Color por defecto de una coleccion nueva. */
    val DEFAULT = BLUE

    fun fromId(id: String): CollectionColor? = entries.firstOrNull { it.id == id }
  }
}
