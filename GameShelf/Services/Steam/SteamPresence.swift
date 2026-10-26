//
//  SteamPresence.swift
//  GameShelf
//

import Foundation

/// Que esta jugando el usuario en Steam en este momento.
///
/// Tiene un tercer caso ademas de "jugando" y "no jugando" porque Steam no
/// siempre lo dice: con el perfil privado la respuesta es igual tanto si esta
/// jugando como si no, y tratarla como "no jugando" haria que la deteccion
/// automatica (#49) cerrara sesiones que siguen abiertas.
nonisolated enum SteamPresence: Equatable, Sendable {
  /// Jugando a algo.
  ///
  /// `appID` es `nil` cuando el juego no es de la tienda: Steam deja agregar
  /// juegos de fuera a la biblioteca, y de esos solo manda el nombre. `name`
  /// es `nil` si Steam no lo mando.
  case playing(appID: Int?, name: String?)

  /// Conectado o no, pero sin jugar a nada.
  ///
  /// Ojo: si el perfil es publico pero los **detalles de juego** son
  /// privados, Steam tampoco manda el juego en curso, y eso se ve igual que no
  /// estar jugando. No hay forma de distinguirlo desde la API.
  case notPlaying

  /// Steam no deja saberlo: el perfil no es publico, o no encontro la cuenta.
  case unavailable

  /// Traduce la respuesta de `GetPlayerSummaries` para la cuenta `steamID`.
  init(_ respuesta: SteamPlayerSummariesResponse, steamID: String) {
    // Se pide un solo perfil, pero se busca por id en vez de tomar el primero:
    // si un dia la consulta trae mas, no se confunde la cuenta.
    guard let perfil = respuesta.response.players.first(where: { $0.steamID == steamID }) else {
      self = .unavailable
      return
    }

    let nombre = perfil.gameExtraInfo.flatMap { $0.isEmpty ? nil : $0 }
    let id = perfil.gameID.flatMap { $0.isEmpty ? nil : $0 }

    if id != nil || nombre != nil {
      self = .playing(appID: id.flatMap(Self.appID(desde:)), name: nombre)
    } else if perfil.isPublic {
      self = .notPlaying
    } else {
      self = .unavailable
    }
  }

  /// El appid de la tienda, si `gameID` es uno.
  ///
  /// Los appids de Steam caben en 32 bits. Los juegos de fuera de la tienda
  /// llegan con un id de 64 bits armado por el propio cliente de Steam
  /// (`"13280471429706432512"`), que no corresponde a nada en la tienda.
  static func appID(desde gameID: String) -> Int? {
    guard let valor = UInt32(gameID), valor > 0 else { return nil }
    return Int(valor)
  }

  /// Si esta jugando a algo.
  var isPlaying: Bool {
    if case .playing = self { return true }
    return false
  }
}
