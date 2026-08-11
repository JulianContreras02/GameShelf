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
    case .backlog: "Pendiente"
    case .playing: "Jugando"
    case .finished: "Terminado"
    case .abandoned: "Abandonado"
    case .wishlist: "Lista de deseos"
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
    case .backlog: "Lo tienes pero no lo has empezado"
    case .playing: "Lo estas jugando ahora"
    case .finished: "Lo terminaste"
    case .abandoned: "Lo dejaste sin terminar"
    case .wishlist: "Lo quieres pero todavia no lo tienes"
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
