//
//  Money.swift
//  GameShelf
//

import Foundation

/// Un importe con su moneda.
///
/// Lleva la moneda pegada al numero a proposito. La API devuelve la moneda que
/// use la tienda en el pais que se le pida, y no siempre es la que uno
/// esperaria: para Colombia responde en **USD**, porque Steam y las demas
/// tiendas facturan en dolares aca. Guardar solo el numero y asumir la moneda
/// seria mostrar precios equivocados.
struct Money: Sendable, Equatable, Hashable {

  /// El valor, ya en unidades enteras de la moneda (19.99, no 1999).
  let amount: Decimal

  /// Codigo ISO 4217: "USD", "EUR", "COP"...
  let currency: String

  /// Crea el importe a partir de los centavos que manda la API.
  ///
  /// Se usa `amountInt` y no `amount` porque el segundo llega como numero de
  /// coma flotante, y decodificarlo a `Decimal` pasa por `Double`: 19.99 se
  /// convierte en 19.989999999999998. Con los centavos la cuenta es exacta.
  init(minorUnits: Int, currency: String) {
    self.amount = Decimal(minorUnits) / 100
    self.currency = currency
  }

  init(amount: Decimal, currency: String) {
    self.amount = amount
    self.currency = currency
  }

  /// El precio como se le muestra al usuario.
  ///
  /// El simbolo y la separacion de miles salen del idioma del sistema, pero la
  /// moneda es la que dijo la tienda: un usuario en Colombia viendo un precio
  /// en dolares tiene que ver "US$19.99", no "$19.99" a secas, que se leeria
  /// como pesos.
  func formatted(locale: Locale = .current) -> String {
    amount.formatted(.currency(code: currency).locale(locale))
  }

  /// Cuanto mas barato es este importe que otro, en porcentaje entero.
  ///
  /// Devuelve `nil` si las monedas no coinciden: restar dolares a euros no
  /// significa nada, y es mejor no mostrar nada que mostrar un numero falso.
  func discount(from regular: Money) -> Int? {
    guard currency == regular.currency, regular.amount > 0 else { return nil }
    let proporcion = (regular.amount - amount) / regular.amount
    return Int((proporcion * 100 as NSDecimalNumber).doubleValue.rounded())
  }
}
