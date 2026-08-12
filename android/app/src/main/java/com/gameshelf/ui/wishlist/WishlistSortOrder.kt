package com.gameshelf.ui.wishlist

import androidx.annotation.StringRes
import com.gameshelf.R
import com.gameshelf.data.itad.GameDeal
import com.gameshelf.data.itad.GamePrices
import com.gameshelf.domain.Game
import com.gameshelf.domain.NameOrder
import com.gameshelf.ui.library.SortIcon

/** Como ordenar la lista de deseos. */
enum class WishlistSortOrder(
  val id: String,
  @StringRes val displayNameRes: Int,
  val icon: SortIcon,
) {
  /** Lo ultimo que quisiste, primero. */
  DESEADO_HACE_POCO("deseadoHacePoco", R.string.wishlist_sort_recent, SortIcon.CALENDAR),

  /** La rebaja mas grande, primero. */
  MAYOR_DESCUENTO("mayorDescuento", R.string.wishlist_sort_discount, SortIcon.TAG),

  /** El mas barato, primero. */
  PRECIO_MAS_BAJO("precioMasBajo", R.string.wishlist_sort_price, SortIcon.ARROW_DOWN);

  /**
   * Si el orden depende de tener los precios cargados.
   *
   * Sirve para avisar en vez de mostrar una lista que parece desordenada
   * mientras los precios todavia estan en camino.
   */
  val needsPrices: Boolean get() = this != DESEADO_HACE_POCO

  /**
   * Ordena los juegos.
   *
   * Los juegos sin precio van siempre al final, sin importar el orden: uno del
   * que no se sabe el precio no es "el mas barato", es uno sin datos. Entre
   * ellos se ordenan por nombre para que la lista no baile en cada carga.
   */
  fun sort(juegos: List<Game>, precios: Map<Int, GamePrices>): List<Game> = when (this) {
    DESEADO_HACE_POCO -> porFechaDeseado(juegos)

    MAYOR_DESCUENTO -> ordenar(juegos, precios) { izq, der ->
      der.second.discountPercent.compareTo(izq.second.discountPercent)
    }

    PRECIO_MAS_BAJO -> ordenar(juegos, precios) { izq, der ->
      izq.second.price.amount.compareTo(der.second.price.amount)
    }
  }

  /**
   * Separa los que tienen precio de los que no, ordena los primeros con el
   * criterio dado y deja los segundos al final.
   */
  private fun ordenar(
    juegos: List<Game>,
    precios: Map<Int, GamePrices>,
    criterio: Comparator<Pair<Game, GameDeal>>,
  ): List<Game> {
    val conPrecio = mutableListOf<Pair<Game, GameDeal>>()
    val sinPrecio = mutableListOf<Game>()

    juegos.forEach { juego ->
      val mejor = juego.steamAppID?.let { precios[it]?.best }
      if (mejor != null) conPrecio += juego to mejor else sinPrecio += juego
    }

    return conPrecio.sortedWith(criterio).map { it.first } +
      sinPrecio.sortedWith(NameOrder.byName())
  }

  /** Los mas recientes primero; los que no traen fecha, al final por nombre. */
  private fun porFechaDeseado(juegos: List<Game>): List<Game> {
    val (conFecha, sinFecha) = juegos.partition { it.wishlistedAt != null }
    return conFecha.sortedByDescending { it.wishlistedAt } +
      sinFecha.sortedWith(NameOrder.byName())
  }

  companion object {
    val DEFAULT = DESEADO_HACE_POCO

    fun fromId(id: String?): WishlistSortOrder = entries.firstOrNull { it.id == id } ?: DEFAULT
  }
}
