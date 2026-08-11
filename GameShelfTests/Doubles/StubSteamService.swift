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

  /// Retardo antes de responder.
  ///
  /// Sin esto el doble nunca suspende, o sea que dos llamadas seguidas jamas
  /// se solapan y no se puede probar que las concurrentes se descarten.
  private let delay: Duration?

  /// Cuantas veces se llamo. Sirve para comprobar que no se dispararon
  /// sincronizaciones de mas.
  private(set) var callCount = 0

  init(_ behavior: Behavior, delay: Duration? = nil) {
    self.behavior = behavior
    self.delay = delay
  }

  func fetchOwnedGames() async throws -> [SteamGameDTO] {
    callCount += 1

    if let delay {
      try? await Task.sleep(for: delay)
    }

    switch behavior {
    case .success(let juegos): return juegos
    case .failure(let error): throw error
    }
  }
}
