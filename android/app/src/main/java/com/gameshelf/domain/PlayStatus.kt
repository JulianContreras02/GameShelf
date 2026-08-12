package com.gameshelf.domain

import androidx.annotation.StringRes
import com.gameshelf.R

/**
 * En que punto esta el usuario con un juego.
 *
 * Es un dato personal: nunca se sobrescribe al re-sincronizar con una tienda.
 *
 * A diferencia de la version de iOS, los textos no se resuelven aca sino que
 * se exponen como ids de recurso. Resolver una cadena en Android necesita un
 * `Context`, y meterlo en el modelo obligaria a levantar Android para probar
 * algo que es logica pura.
 */
enum class PlayStatus(
  val id: String,
  @StringRes val displayNameRes: Int,
  @StringRes val explanationRes: Int,
  val iconName: StatusIcon,
) {
  /** Lo tiene pero no lo ha empezado. */
  BACKLOG("backlog", R.string.status_backlog, R.string.status_backlog_explanation, StatusIcon.TRAY),

  /** Lo esta jugando ahora. */
  PLAYING("playing", R.string.status_playing, R.string.status_playing_explanation, StatusIcon.PLAY),

  /** Lo termino. */
  FINISHED("finished", R.string.status_finished, R.string.status_finished_explanation, StatusIcon.CHECK),

  /** Lo dejo sin terminar. */
  ABANDONED("abandoned", R.string.status_abandoned, R.string.status_abandoned_explanation, StatusIcon.CROSS),

  /** No lo tiene todavia, lo quiere. */
  WISHLIST("wishlist", R.string.status_wishlist, R.string.status_wishlist_explanation, StatusIcon.HEART);

  /** Si el usuario ya posee el juego. La wishlist es lo unico que no se tiene. */
  val isOwned: Boolean get() = this != WISHLIST

  companion object {
    /**
     * Orden en que se muestran los estados.
     *
     * Sigue el recorrido natural de un juego, no el alfabetico: primero lo que
     * estas jugando, al final lo que ni siquiera tienes.
     */
    val displayOrder: List<PlayStatus> = listOf(PLAYING, BACKLOG, FINISHED, ABANDONED, WISHLIST)

    fun fromId(id: String): PlayStatus? = entries.firstOrNull { it.id == id }
  }
}

/**
 * Icono que representa cada estado, como valor de dominio.
 *
 * El modelo nombra el icono pero no lo construye: la traduccion a un
 * `ImageVector` de Material vive en la capa de UI, igual que en iOS el modelo
 * solo guardaba el nombre del SF Symbol.
 */
enum class StatusIcon { TRAY, PLAY, CHECK, CROSS, HEART }
