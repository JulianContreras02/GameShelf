//
//  PlayStatus.swift
//  GameShelf
//

import Foundation

/// En que punto esta el usuario con un juego.
///
/// Es un dato personal: nunca se sobrescribe al re-sincronizar con una tienda.
enum PlayStatus: String, Codable, CaseIterable, Sendable {
  /// Lo tiene pero no lo ha empezado.
  case backlog
  /// Lo esta jugando ahora.
  case playing
  /// Lo termino.
  case finished
  /// Lo dejo sin terminar.
  case abandoned
  /// No lo tiene todavia, lo quiere.
  case wishlist

  /// Nombre para mostrar en pantalla.
  var displayName: String {
    switch self {
    case .backlog: String(localized: "Pendiente", comment: "Estado de un juego")
    case .playing: String(localized: "Jugando", comment: "Estado de un juego")
    case .finished: String(localized: "Terminado", comment: "Estado de un juego")
    case .abandoned: String(localized: "Abandonado", comment: "Estado de un juego")
    case .wishlist: String(localized: "Lista de deseos", comment: "Estado de un juego")
    }
  }

  /// Si el usuario ya posee el juego. La wishlist es lo unico que no se tiene.
  var isOwned: Bool {
    self != .wishlist
  }

  /// Simbolo del sistema que lo representa.
  ///
  /// Es solo el nombre, no un `Image`: asi el modelo no depende de SwiftUI.
  var symbolName: String {
    switch self {
    case .backlog: "tray.full"
    case .playing: "play.circle.fill"
    case .finished: "checkmark.circle.fill"
    case .abandoned: "xmark.circle"
    case .wishlist: "heart"
    }
  }

  /// Frase corta que explica que significa el estado.
  var explanation: String {
    switch self {
    case .backlog: String(localized: "Lo tienes pero no lo has empezado", comment: "Que significa el estado")
    case .playing: String(localized: "Lo estas jugando ahora", comment: "Que significa el estado")
    case .finished: String(localized: "Lo terminaste", comment: "Que significa el estado")
    case .abandoned: String(localized: "Lo dejaste sin terminar", comment: "Que significa el estado")
    case .wishlist: String(localized: "Lo quieres pero todavia no lo tienes", comment: "Que significa el estado")
    }
  }

  /// Orden en que se muestran los estados.
  ///
  /// Sigue el recorrido natural de un juego, no el alfabetico: primero lo que
  /// no has empezado, al final lo que ni siquiera tienes.
  static let displayOrder: [PlayStatus] = [
    .playing, .backlog, .finished, .abandoned, .wishlist
  ]
}
