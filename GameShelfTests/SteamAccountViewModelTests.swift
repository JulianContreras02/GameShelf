//
//  SteamAccountViewModelTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Validador de credenciales falso.
final class StubCredentialsValidator: SteamCredentialsValidating, @unchecked Sendable {
  enum Behavior {
    case success
    case failure(Error)
  }

  private let behavior: Behavior
  private(set) var validadas: [SteamService.Credentials] = []

  init(_ behavior: Behavior) {
    self.behavior = behavior
  }

  func validate(_ credentials: SteamService.Credentials) async throws {
    validadas.append(credentials)
    if case .failure(let error) = behavior { throw error }
  }
}

@MainActor
@Suite("Steam: conectar la cuenta")
struct SteamAccountConnectTests {

  @Test("Al conectar verifica las credenciales y las guarda en el llavero")
  func conecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = SteamAccountViewModel(keychain: llavero, validator: StubCredentialsValidator(.success))

    await viewModel.connect(steamID: "76561198000000000", apiKey: "MI_CLAVE")

    #expect(viewModel.state == .conectado)
    #expect(try llavero.string(for: "steam.apiKey") == "MI_CLAVE")
    #expect(try llavero.string(for: "steam.steamID") == "76561198000000000")
  }

  @Test("Quita espacios de los dos campos antes de guardar")
  func quitaEspacios() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = SteamAccountViewModel(keychain: llavero, validator: StubCredentialsValidator(.success))

    await viewModel.connect(steamID: "  76561198000000000  ", apiKey: "  MI_CLAVE  ")

    #expect(try llavero.string(for: "steam.apiKey") == "MI_CLAVE")
    #expect(try llavero.string(for: "steam.steamID") == "76561198000000000")
  }

  @Test("Una API key rechazada no se guarda")
  func credencialesInvalidas() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = SteamAccountViewModel(
      keychain: llavero,
      validator: StubCredentialsValidator(.failure(NetworkError.httpError(statusCode: 403)))
    )

    await viewModel.connect(steamID: "123", apiKey: "MALA")

    guard case .fallo = viewModel.state else {
      Issue.record("Se esperaba estado fallo, quedo en \(viewModel.state)")
      return
    }
    #expect(try llavero.string(for: "steam.apiKey") == nil)
    #expect(try llavero.string(for: "steam.steamID") == nil)
  }

  @Test("Desconectar borra las credenciales del llavero")
  func desconecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = SteamAccountViewModel(keychain: llavero, validator: StubCredentialsValidator(.success))
    await viewModel.connect(steamID: "123", apiKey: "CLAVE")

    viewModel.disconnect()

    #expect(viewModel.state == .desconectado)
    #expect(try llavero.string(for: "steam.apiKey") == nil)
    #expect(try llavero.string(for: "steam.steamID") == nil)
  }

  @Test("Al arrancar recuerda que ya estaba conectado")
  func recuerdaLaSesion() {
    let llavero = InMemoryKeychainStore(valoresIniciales: [
      "steam.apiKey": "CLAVE",
      "steam.steamID": "123"
    ])

    let viewModel = SteamAccountViewModel(keychain: llavero, validator: StubCredentialsValidator(.success))

    #expect(viewModel.state == .conectado)
  }

  @Test("Sin nada guardado arranca desconectado")
  func arranqueLimpio() {
    let viewModel = SteamAccountViewModel(
      keychain: InMemoryKeychainStore(),
      validator: StubCredentialsValidator(.success)
    )

    #expect(viewModel.state == .desconectado)
  }
}
