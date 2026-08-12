//
//  GamePrices.swift
//  GameShelf
//

import Foundation

/// Lo que cuesta un juego ahora mismo, y lo mas barato que ha estado.
///
/// Es el tipo de dominio: la vista y los ViewModels hablan con esto, no con los
/// DTOs de IsThereAnyDeal.
struct GamePrices: Sendable, Equatable {

  /// Identificador del juego dentro de IsThereAnyDeal.
  let itadID: String

  /// La oferta mas barata de todas las tiendas, o `nil` si no se vende en
  /// ninguna (pasa con los juegos que todavia no han salido).
  let best: GameDeal?

  /// Lo mas barato que ha llegado a costar, en cualquier tienda y momento.
  let historicalLow: Money?

  /// Si el precio de ahora iguala o mejora el minimo historico.
  ///
  /// Es la senal que de verdad importa para decidir si comprar: un 50% de
  /// descuento no dice nada si el juego ya estuvo al 75%.
  var isAtHistoricalLow: Bool {
    guard let actual = best?.price, let minimo = historicalLow,
          actual.currency == minimo.currency
    else { return false }
    return actual.amount <= minimo.amount
  }

  /// Si ahora mismo esta rebajado.
  var isOnSale: Bool {
    (best?.discountPercent ?? 0) > 0
  }
}

/// Una oferta concreta en una tienda.
struct GameDeal: Sendable, Equatable {
  let shopName: String

  /// Lo que cuesta ahora.
  let price: Money

  /// Lo que cuesta sin descuento.
  let regular: Money

  /// Enlace a la oferta. Es un redirector de ITAD, no la tienda directamente.
  let url: URL?

  /// Descuento en porcentaje entero.
  ///
  /// Se recalcula a partir de los dos precios en vez de confiar en el `cut` que
  /// manda la API, para que el numero y los importes no puedan contradecirse en
  /// pantalla.
  var discountPercent: Int {
    price.discount(from: regular) ?? 0
  }
}
