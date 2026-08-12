//
//  CollectionColor.swift
//  GameShelf
//

import Foundation

/// Color de una coleccion.
///
/// Es un enum con opciones fijas y no un color libre por dos razones: SwiftData
/// no persiste `Color` de forma directa, y una paleta acotada evita que el
/// usuario elija un color ilegible sobre el fondo.
///
/// Se guarda por su `rawValue` de texto para que agregar o reordenar casos no
/// corrompa lo ya guardado.
enum CollectionColor: String, Codable, CaseIterable, Sendable {
  case blue
  case green
  case orange
  case pink
  case purple
  case red
  case teal
  case yellow
  case gray

  /// Color por defecto de una coleccion nueva.
  static let `default` = CollectionColor.blue

  /// Nombre para mostrar en un selector.
  var displayName: String {
    switch self {
    case .blue: String(localized: "Azul", comment: "Color de una coleccion")
    case .green: String(localized: "Verde", comment: "Color de una coleccion")
    case .orange: String(localized: "Naranja", comment: "Color de una coleccion")
    case .pink: String(localized: "Rosa", comment: "Color de una coleccion")
    case .purple: String(localized: "Morado", comment: "Color de una coleccion")
    case .red: String(localized: "Rojo", comment: "Color de una coleccion")
    case .teal: String(localized: "Turquesa", comment: "Color de una coleccion")
    case .yellow: String(localized: "Amarillo", comment: "Color de una coleccion")
    case .gray: String(localized: "Gris", comment: "Color de una coleccion")
    }
  }
}
