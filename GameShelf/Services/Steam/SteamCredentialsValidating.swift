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
  func validate(_ credentials: SteamService.Credentials) async throws
}

struct SteamAPICredentialsValidator: SteamCredentialsValidating {
  let client: HTTPClient

  init(client: HTTPClient = URLSessionHTTPClient()) {
    self.client = client
  }

  func validate(_ credentials: SteamService.Credentials) async throws {
    _ = try await SteamService(client: client, credentials: credentials).fetchOwnedGames()
  }
}
