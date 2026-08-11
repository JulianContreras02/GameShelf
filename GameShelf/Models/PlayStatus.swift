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
}
