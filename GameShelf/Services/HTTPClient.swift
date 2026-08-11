//
//  HTTPClient.swift
//  GameShelf
//

import Foundation

/// Trae datos de una URL y los convierte al tipo que se le pida.
///
/// Es un protocolo, no una clase, para que los servicios dependan de esta
/// forma y no de `URLSession`. En las pruebas se inyecta un doble que devuelve
/// respuestas fijas, sin tocar la red.
///
/// No sabe nada de Steam, de juegos ni de ninguna API concreta: eso vive en los
/// servicios que lo usan.
protocol HTTPClient: Sendable {
  /// Pide los datos de `url` y los decodifica como `T`.
  ///
  /// - Throws: `NetworkError` con el motivo del fallo.
  func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T
}

/// Implementacion real, sobre `URLSession`.
struct URLSessionHTTPClient: HTTPClient {
  private let session: URLSession
  private let decoder: JSONDecoder

  /// - Parameters:
  ///   - session: Sesion a usar. Se puede cambiar en pruebas de integracion.
  ///   - decoder: Decodificador. Se expone para poder ajustar estrategias de
  ///     fecha o de nombres segun la API.
  init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
    self.session = session
    self.decoder = decoder
  }

  func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(from: url)
    } catch let error as URLError {
      // Se traducen los errores de red a los nuestros para que las capas de
      // arriba no tengan que conocer URLError.
      let sinRed: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dataNotAllowed
      ]
      throw sinRed.contains(error.code) ? NetworkError.noConnection : NetworkError.invalidResponse
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw NetworkError.httpError(statusCode: httpResponse.statusCode)
    }

    do {
      return try decoder.decode(T.self, from: data)
    } catch let error as DecodingError {
      throw NetworkError.decodingFailed(description: Self.describe(error))
    } catch {
      throw NetworkError.decodingFailed(description: error.localizedDescription)
    }
  }

  /// Convierte un `DecodingError` en un texto que dice donde fallo.
  ///
  /// El mensaje por defecto de `DecodingError` no dice que campo estaba mal, y
  /// eso es justo lo que se necesita para depurar un cambio de formato en una
  /// API ajena.
  private static func describe(_ error: DecodingError) -> String {
    switch error {
    case .keyNotFound(let key, _):
      "Falta el campo '\(key.stringValue)'."
    case .typeMismatch(let type, let context):
      "El campo '\(Self.path(of: context))' no es del tipo \(type)."
    case .valueNotFound(let type, let context):
      "El campo '\(Self.path(of: context))' llego vacio y se esperaba \(type)."
    case .dataCorrupted(let context):
      "Datos corruptos: \(context.debugDescription)"
    @unknown default:
      error.localizedDescription
    }
  }

  private static func path(of context: DecodingError.Context) -> String {
    context.codingPath.map(\.stringValue).joined(separator: ".")
  }
}
