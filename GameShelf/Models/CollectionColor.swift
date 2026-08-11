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
    case .blue: "Azul"
    case .green: "Verde"
    case .orange: "Naranja"
    case .pink: "Rosa"
    case .purple: "Morado"
    case .red: "Rojo"
    case .teal: "Turquesa"
    case .yellow: "Amarillo"
    case .gray: "Gris"
    }
  }
}
