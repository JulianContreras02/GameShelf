package com.gameshelf.ui.library

import com.gameshelf.domain.Game
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.normalizedForSearch
import java.util.UUID

/**
 * Que juegos se muestran.
 *
 * Cada campo es un conjunto de valores permitidos. Un conjunto **vacio** no
 * filtra nada: significa "cualquiera", no "ninguno". Asi el filtro por defecto
 * muestra toda la biblioteca.
 *
 * Entre categorias se aplica Y (tienda **y** estado), pero dentro de una
 * categoria se aplica O (Steam **o** PSN). Es lo que espera cualquiera al
 * marcar dos casillas de la misma lista.
 */
data class GameFilter(
  val stores: Set<Store> = emptySet(),
  val statuses: Set<PlayStatus> = emptySet(),
  val collectionIDs: Set<UUID> = emptySet(),
  val tagIDs: Set<UUID> = emptySet(),
) {
  /** Si hay algun filtro puesto. */
  val isActive: Boolean
    get() = stores.isNotEmpty() || statuses.isNotEmpty() ||
      collectionIDs.isNotEmpty() || tagIDs.isNotEmpty()

  /** Cuantos criterios hay puestos en total. Sirve para el contador del boton. */
  val activeCount: Int
    get() = stores.size + statuses.size + collectionIDs.size + tagIDs.size

  /** Si un juego pasa el filtro. */
  fun matches(juego: Game): Boolean =
    cumpleTienda(juego) && cumpleEstado(juego) && cumpleColeccion(juego) && cumpleEtiqueta(juego)

  /** Aplica el filtro a una lista. */
  fun apply(juegos: List<Game>): List<Game> =
    if (!isActive) juegos else juegos.filter(::matches)

  // --- Cada criterio -------------------------------------------------------

  private fun cumpleTienda(juego: Game): Boolean =
    stores.isEmpty() || juego.storeEntries.any { it.store in stores }

  private fun cumpleEstado(juego: Game): Boolean =
    statuses.isEmpty() || juego.status in statuses

  private fun cumpleColeccion(juego: Game): Boolean =
    collectionIDs.isEmpty() || juego.collections.any { it.id in collectionIDs }

  private fun cumpleEtiqueta(juego: Game): Boolean =
    tagIDs.isEmpty() || juego.tags.any { it.id in tagIDs }

  companion object {
    val NONE = GameFilter()
  }
}

/**
 * Lo que hay que aplicar para obtener la lista que se ve: buscar, filtrar y
 * ordenar.
 *
 * Se junta en un solo tipo para que el orden de las operaciones sea siempre el
 * mismo y este probado, en vez de repartirlo por la vista.
 */
data class GameQuery(
  val search: String = "",
  val filter: GameFilter = GameFilter.NONE,
  val sort: GameSortOrder = GameSortOrder.DEFAULT,
) {
  /**
   * Aplica todo, en este orden: filtrar, buscar y ordenar.
   *
   * El orden importa. Buscar va antes de ordenar porque la busqueda ya ordena
   * por relevancia, y ese resultado se reemplaza a proposito por el orden que
   * eligio el usuario: si pidio "mas jugados", eso es lo que quiere ver,
   * tambien entre los resultados de la busqueda.
   */
  fun apply(juegos: List<Game>): List<Game> {
    val filtrados = filter.apply(juegos)
    val buscados = GameSearch.filter(filtrados, search)
    return sort.sort(buscados)
  }

  /** Si hay algo puesto que reduzca la lista. */
  val isNarrowing: Boolean
    get() = filter.isActive || search.normalizedForSearch.isNotEmpty()
}
