//
//  SteamCredentialsValidating.swift
//  GameShelf
//

import Foundation

/// Comprueba unas credenciales de Steam contra la API antes de guardarlas.
///
/// Steam no tiene un endpoint de "verificar credenciales": se usa el mismo que
/// trae la biblioteca, descartando el resultado. Asi un SteamID mal copiado o
/// una API key invalida se detectan al conectar, no en la siguiente
/// sincronizacion.
protocol SteamCredentialsValidating: Sendable {
  /// Falla si Steam rechaza las credenciales.
  ///
  /// - Throws: `NetworkError`, igual que la peticion de la biblioteca.
  func validate(_ credentials: SteamService.Credentials) async throws
}

/// Implementacion real: pide la biblioteca con las credenciales y descarta el resultado.
nonisolated struct SteamAPICredentialsValidator: SteamCredentialsValidating {
  let client: HTTPClient

  /// - Parameter client: Por donde salen las peticiones.
  init(client: HTTPClient = URLSessionHTTPClient()) {
    self.client = client
  }

  /// Pide la biblioteca y la descarta: si Steam la entrega, las credenciales sirven.
  func validate(_ credentials: SteamService.Credentials) async throws {
    _ = try await SteamService(client: client, credentials: credentials).fetchOwnedGames()
  }
}
