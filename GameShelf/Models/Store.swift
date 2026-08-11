//
//  Store.swift
//  GameShelf
//

import Foundation

/// Tienda de la que proviene un juego.
///
/// Se guarda como `String` en SwiftData (no como entero) para que agregar o
/// reordenar casos no corrompa los datos ya guardados.
enum Store: String, Codable, CaseIterable, Sendable {
  case steam
  case psn
  case epic

  /// Nombre para mostrar en pantalla.
  var displayName: String {
    switch self {
    case .steam: "Steam"
    case .psn: "PlayStation Network"
    case .epic: "Epic Games"
    }
  }
}
