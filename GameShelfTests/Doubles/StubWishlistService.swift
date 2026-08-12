//
//  StubWishlistService.swift
//  GameShelfTests
//

import Foundation

@testable import GameShelf

/// Servicio de wishlist falso: devuelve lo que se le indique, sin red.
final class StubWishlistService: SteamWishlistServicing, @unchecked Sendable {

  enum Behavior {
    case success([SteamWishlistGame])
    case failure(Error)
  }

  private let behavior: Behavior

  /// Retardo antes de responder, para poder provocar llamadas solapadas.
  private let delay: Duration?

  private(set) var callCount = 0

  init(_ behavior: Behavior, delay: Duration? = nil) {
    self.behavior = behavior
    self.delay = delay
  }

  func fetchWishlist() async throws -> [SteamWishlistGame] {
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

/// Cliente HTTP que responde distinto segun lo que pida la URL.
///
/// Hace falta porque traer la wishlist son **dos** llamadas encadenadas (la
/// lista de appids y despues las fichas de la tienda), y con un stub de una
/// sola respuesta no se puede probar que se encadenen bien.
final class RoutingHTTPClient: HTTPClient, @unchecked Sendable {

  /// Pares (fragmento que debe aparecer en la URL, JSON a devolver).
  private let rutas: [(String, String)]
  private let decoder = JSONDecoder()

  private(set) var requestedURLs: [URL] = []

  init(rutas: [(String, String)]) {
    self.rutas = rutas
  }

  func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    requestedURLs.append(url)

    let texto = url.absoluteString
    guard let json = rutas.first(where: { texto.contains($0.0) })?.1 else {
      throw NetworkError.invalidURL("Ninguna ruta del doble coincide con \(texto)")
    }

    do {
      return try decoder.decode(T.self, from: Data(json.utf8))
    } catch {
      throw NetworkError.decodingFailed(description: "\(error)")
    }
  }
}

extension SteamWishlistGame {
  /// Atajo para armar juegos de prueba sin repetir todos los campos.
  static func ejemplo(
    appID: Int,
    name: String = "Juego",
    addedAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
    isComingSoon: Bool = false
  ) -> SteamWishlistGame {
    SteamWishlistGame(
      appID: appID,
      name: name,
      coverURL: URL(string: "https://ejemplo.test/\(appID).jpg"),
      storeURL: URL(string: "https://store.steampowered.com/app/\(appID)"),
      addedAt: addedAt,
      priority: 0,
      releaseDate: nil,
      isComingSoon: isComingSoon
    )
  }
}
