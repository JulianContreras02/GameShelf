//
//  LibraryPreferences.swift
//  GameShelf
//

import Foundation

/// Preferencias de la biblioteca que sobreviven al cierre de la app.
///
/// Solo se guarda el **orden**. Los filtros son deliberadamente pasajeros:
/// abrir la app y encontrarse media biblioteca escondida por un filtro que se
/// puso ayer se siente como que faltan juegos.
@Observable
@MainActor
final class LibraryPreferences {

  private let defaults: UserDefaults
  private static let sortKey = "library.sortOrder"

  /// Orden elegido. Al cambiarlo se guarda solo.
  var sortOrder: GameSortOrder {
    didSet {
      guard sortOrder != oldValue else { return }
      defaults.set(sortOrder.rawValue, forKey: Self.sortKey)
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

    // Si lo guardado no se reconoce (por ejemplo tras quitar un caso), se
    // vuelve al valor por defecto en vez de fallar.
    let guardado = defaults.string(forKey: Self.sortKey)
    self.sortOrder = guardado.flatMap(GameSortOrder.init(rawValue:)) ?? .default
  }
}
