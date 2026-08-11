//
//  StubHTTPClient.swift
//  GameShelfTests
//

import Foundation

@testable import GameShelf

/// Cliente HTTP falso para pruebas: devuelve lo que se le indique, sin red.
///
/// Permite provocar a voluntad casos que con red real son dificiles o
/// imposibles de reproducir, como un JSON corrupto o un 503.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {

  /// Que debe hacer el cliente cuando le pidan datos.
  enum Behavior {
    /// Devolver estos bytes crudos, para que los decodifique quien llama.
    case success(Data)
    /// Fallar con este error.
    case failure(NetworkError)
  }

  private let behavior: Behavior
  private let decoder = JSONDecoder()

  /// URLs que se pidieron, en orden. Sirve para comprobar que un servicio
  /// construyo bien la URL.
  private(set) var requestedURLs: [URL] = []

  init(_ behavior: Behavior) {
    self.behavior = behavior
  }

  /// Atajo para responder con un JSON escrito como texto en la prueba.
  convenience init(json: String) {
    self.init(.success(Data(json.utf8)))
  }

  func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    requestedURLs.append(url)

    switch behavior {
    case .failure(let error):
      throw error

    case .success(let data):
      do {
        return try decoder.decode(T.self, from: data)
      } catch {
        throw NetworkError.decodingFailed(description: "\(error)")
      }
    }
  }
}
