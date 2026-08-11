//
//  StubSteamService.swift
//  GameShelfTests
//

import Foundation

@testable import GameShelf

/// Servicio de Steam falso: devuelve lo que se le indique, sin red.
final class StubSteamService: SteamServicing, @unchecked Sendable {

  enum Behavior {
    case success([SteamGameDTO])
    case failure(Error)
  }

  private let behavior: Behavior

  /// Cuantas veces se llamo. Sirve para comprobar que no se dispararon
  /// sincronizaciones de mas.
  private(set) var callCount = 0

  init(_ behavior: Behavior) {
    self.behavior = behavior
  }

  func fetchOwnedGames() async throws -> [SteamGameDTO] {
    callCount += 1
    switch behavior {
    case .success(let juegos): return juegos
    case .failure(let error): throw error
    }
  }
}
