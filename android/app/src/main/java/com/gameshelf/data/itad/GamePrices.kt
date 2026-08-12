package com.gameshelf.data.itad

/**
 * Lo que cuesta un juego ahora mismo, y lo mas barato que ha estado.
 *
 * Es el tipo de dominio: la vista y los ViewModels hablan con esto, no con los
 * DTOs de IsThereAnyDeal.
 */
data class GamePrices(
  /** Identificador del juego dentro de IsThereAnyDeal. */
  val itadID: String,

  /**
   * La oferta mas barata de todas las tiendas, o `null` si no se vende en
   * ninguna (pasa con los juegos que todavia no han salido).
   */
  val best: GameDeal?,

  /** Lo mas barato que ha llegado a costar, en cualquier tienda y momento. */
  val historicalLow: Money?,
) {
  /**
   * Si el precio de ahora iguala o mejora el minimo historico.
   *
   * Es la senal que de verdad importa para decidir si comprar: un 50% de
   * descuento no dice nada si el juego ya estuvo al 75%.
   */
  val isAtHistoricalLow: Boolean
    get() {
      val actual = best?.price ?: return false
      val minimo = historicalLow ?: return false
      if (actual.currency != minimo.currency) return false
      return actual.amount <= minimo.amount
    }

  /** Si ahora mismo esta rebajado. */
  val isOnSale: Boolean get() = (best?.discountPercent ?: 0) > 0
}

/** Una oferta concreta en una tienda. */
data class GameDeal(
  val shopName: String,
  /** Lo que cuesta ahora. */
  val price: Money,
  /** Lo que cuesta sin descuento. */
  val regular: Money,
  /** Enlace a la oferta. Es un redirector de ITAD, no la tienda directamente. */
  val url: String?,
) {
  /**
   * Descuento en porcentaje entero.
   *
   * Se recalcula a partir de los dos precios en vez de confiar en el `cut` que
   * manda la API, para que el numero y los importes no puedan contradecirse en
   * pantalla.
   */
  val discountPercent: Int get() = price.discount(regular) ?: 0
}
