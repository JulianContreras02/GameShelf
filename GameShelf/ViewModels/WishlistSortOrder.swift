//
//  WishlistSortOrder.swift
//  GameShelf
//

import Foundation

/// Como ordenar la lista de deseos.
enum WishlistSortOrder: String, CaseIterable, Sendable {
  /// Lo ultimo que quisiste, primero.
  case deseadoHacePoco
  /// La rebaja mas grande, primero.
  case mayorDescuento
  /// El mas barato, primero.
  case precioMasBajo

  static let `default` = WishlistSortOrder.deseadoHacePoco

  var displayName: String {
    switch self {
    case .deseadoHacePoco: String(localized: "Deseado hace poco", comment: "Orden de la lista de deseos")
    case .mayorDescuento: String(localized: "Mayor descuento", comment: "Orden de la lista de deseos")
    case .precioMasBajo: String(localized: "Precio mas bajo", comment: "Orden de la lista de deseos")
    }
  }

  var symbolName: String {
    switch self {
    case .deseadoHacePoco: "calendar.badge.clock"
    case .mayorDescuento: "tag"
    case .precioMasBajo: "arrow.down.circle"
    }
  }

  /// Si el orden depende de tener los precios cargados.
  ///
  /// Sirve para avisar en vez de mostrar una lista que parece desordenada
  /// mientras los precios todavia estan en camino.
  var needsPrices: Bool {
    self != .deseadoHacePoco
  }

  /// Ordena los juegos.
  ///
  /// - Parameters:
  ///   - juegos: Los juegos a ordenar.
  ///   - precios: Precios ya cargados, indexados por appid de Steam.
  ///
  /// Los juegos sin precio van siempre al final, sin importar el orden: uno del
  /// que no se sabe el precio no es "el mas barato", es uno sin datos. Entre
  /// ellos se ordenan por nombre para que la lista no baile en cada carga.
  func sort(_ juegos: [Game], precios: [Int: GamePrices]) -> [Game] {
    switch self {
    case .deseadoHacePoco:
      return juegos.sorted(by: porFechaDeseado)

    case .mayorDescuento:
      return ordenar(juegos, precios: precios) { izq, der in
        izq.mejor.discountPercent > der.mejor.discountPercent
      }

    case .precioMasBajo:
      return ordenar(juegos, precios: precios) { izq, der in
        izq.mejor.price.amount < der.mejor.price.amount
      }
    }
  }

  /// Separa los que tienen precio de los que no, ordena los primeros con el
  /// criterio dado y deja los segundos al final.
  private func ordenar(
    _ juegos: [Game],
    precios: [Int: GamePrices],
    por criterio: ((juego: Game, mejor: GameDeal), (juego: Game, mejor: GameDeal)) -> Bool
  ) -> [Game] {
    var conPrecio: [(juego: Game, mejor: GameDeal)] = []
    var sinPrecio: [Game] = []

    for juego in juegos {
      if let appID = juego.steamAppID, let mejor = precios[appID]?.best {
        conPrecio.append((juego, mejor))
      } else {
        sinPrecio.append(juego)
      }
    }

    return conPrecio.sorted(by: criterio).map(\.juego)
      + sinPrecio.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  /// Los mas recientes primero; los que no traen fecha, al final por nombre.
  private func porFechaDeseado(_ izq: Game, _ der: Game) -> Bool {
    switch (izq.wishlistedAt, der.wishlistedAt) {
    case let (fechaIzq?, fechaDer?): fechaIzq > fechaDer
    case (nil, _?): false
    case (_?, nil): true
    case (nil, nil): izq.name.localizedStandardCompare(der.name) == .orderedAscending
    }
  }
}

/// Preferencias de la lista de deseos que sobreviven al cierre de la app.
@Observable
@MainActor
final class WishlistPreferences {

  private let defaults: UserDefaults
  private static let sortKey = "wishlist.sortOrder"

  /// Orden elegido. Al cambiarlo se guarda solo.
  var sortOrder: WishlistSortOrder {
    didSet {
      guard sortOrder != oldValue else { return }
      defaults.set(sortOrder.rawValue, forKey: Self.sortKey)
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

    let guardado = defaults.string(forKey: Self.sortKey)
    self.sortOrder = guardado.flatMap(WishlistSortOrder.init(rawValue:)) ?? .default
  }
}
