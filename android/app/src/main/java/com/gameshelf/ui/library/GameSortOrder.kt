package com.gameshelf.ui.library

import androidx.annotation.StringRes
import com.gameshelf.R
import com.gameshelf.domain.Game
import com.gameshelf.domain.NameOrder
import java.time.Instant

/**
 * Como se ordena la biblioteca.
 *
 * Se guarda por su [id] de texto para que agregar o reordenar casos no
 * invalide la preferencia que ya tiene guardada el usuario.
 */
enum class GameSortOrder(
  val id: String,
  @StringRes val displayNameRes: Int,
  val icon: SortIcon,
) {
  NAME_ASCENDING("nameAscending", R.string.sort_name_asc, SortIcon.ALPHABET),
  PLAYTIME_DESCENDING("playtimeDescending", R.string.sort_playtime_desc, SortIcon.CLOCK_BACK),
  PLAYTIME_ASCENDING("playtimeAscending", R.string.sort_playtime_asc, SortIcon.CLOCK),
  LAST_PLAYED_DESCENDING("lastPlayedDescending", R.string.sort_last_played, SortIcon.CALENDAR),
  RELEASE_DATE_DESCENDING("releaseDateDescending", R.string.sort_release_date, SortIcon.SPARKLE),
  RECENTLY_ADDED("recentlyAdded", R.string.sort_recently_added, SortIcon.INBOX);

  /**
   * Aviso cuando el orden no puede funcionar con los datos que hay.
   *
   * Hoy solo aplica a la fecha de lanzamiento: `GetOwnedGames` de Steam no la
   * devuelve, asi que esta vacia en todos los juegos. Se deja el orden porque
   * el dato puede llegar de otra API mas adelante, pero se avisa en vez de
   * dejar al usuario preguntandose por que no pasa nada.
   */
  @get:StringRes
  val unavailableNoteRes: Int?
    get() = if (this == RELEASE_DATE_DESCENDING) R.string.sort_release_date_unavailable else null

  /**
   * Ordena la lista.
   *
   * Los juegos sin el dato correspondiente van siempre al final, sin importar
   * el orden: un juego sin fecha no es "el mas antiguo", es uno del que no se
   * sabe.
   */
  fun sort(juegos: List<Game>): List<Game> {
    val porNombre = NameOrder.byName()

    return when (this) {
      NAME_ASCENDING -> juegos.sortedWith(porNombre)

      PLAYTIME_DESCENDING ->
        juegos.sortedWith(compareByDescending<Game> { it.playtimeHours }.then(porNombre))

      PLAYTIME_ASCENDING ->
        juegos.sortedWith(compareBy<Game> { it.playtimeHours }.then(porNombre))

      LAST_PLAYED_DESCENDING -> ordenarPorFecha(juegos, porNombre) { it.lastPlayedAt }

      RELEASE_DATE_DESCENDING -> ordenarPorFecha(juegos, porNombre) { it.releaseDate }

      RECENTLY_ADDED ->
        juegos.sortedWith(compareByDescending<Game> { it.addedAt }.then(porNombre))
    }
  }

  /**
   * Ordena de mas reciente a mas antiguo, dejando los que no tienen fecha al
   * final y ordenados por nombre entre ellos.
   */
  private fun ordenarPorFecha(
    juegos: List<Game>,
    porNombre: Comparator<Game>,
    fecha: (Game) -> Instant?,
  ): List<Game> {
    val (conFecha, sinFecha) = juegos.partition { fecha(it) != null }

    val ordenados = conFecha.sortedWith(
      compareByDescending<Game> { fecha(it) }.then(porNombre),
    )

    return ordenados + sinFecha.sortedWith(porNombre)
  }

  companion object {
    val DEFAULT = NAME_ASCENDING

    fun fromId(id: String?): GameSortOrder = entries.firstOrNull { it.id == id } ?: DEFAULT
  }
}

/**
 * Icono de cada criterio de orden, como valor.
 *
 * Igual que con los estados: el modelo nombra el icono y la UI lo traduce a un
 * vector de Material.
 */
enum class SortIcon { ALPHABET, CLOCK_BACK, CLOCK, CALENDAR, SPARKLE, INBOX, TAG, ARROW_DOWN }
