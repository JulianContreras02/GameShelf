//
//  SteamAccountViewModel.swift
//  GameShelf
//

import Foundation

/// La conexion con la cuenta de Steam: conectar, verificar y desconectar.
///
/// A diferencia de PSN y Epic no hay OAuth ni token que renovar: son dos datos
/// publicos por cuenta (SteamID64 y API key) que Steam entrega directo en su
/// web. Guardarlos en el llavero, y no en `Secrets.xcconfig`, es lo que permite
/// que cada persona que instale la app conecte su propia cuenta sin recompilar.
@Observable
@MainActor
final class SteamAccountViewModel {

  enum State: Equatable {
    case desconectado
    case trabajando
    case conectado
    /// Fallo al verificar, por ejemplo credenciales invalidas o sin red.
    case fallo(message: String, suggestion: String?)

    var isWorking: Bool { self == .trabajando }
    var isConnected: Bool { self == .conectado }
  }

  private(set) var state: State = .desconectado

  private let keychain: KeychainStoring
  private let validator: SteamCredentialsValidating

  init(
    keychain: KeychainStoring = KeychainStore(),
    validator: SteamCredentialsValidating = SteamAPICredentialsValidator()
  ) {
    self.keychain = keychain
    self.validator = validator
    cargarEstadoGuardado()
  }

  /// Verifica las credenciales contra la API y, si sirven, las guarda.
  func connect(steamID: String, apiKey: String) async {
    guard !state.isWorking else { return }
    state = .trabajando

    let credenciales = SteamService.Credentials(
      apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
      steamID: steamID.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    do {
      try await validator.validate(credenciales)
      try credenciales.save(to: keychain)
      state = .conectado
    } catch {
      state = Self.estado(para: error)
    }
  }

  /// Borra las credenciales del llavero.
  func disconnect() {
    try? SteamService.Credentials.removeFromKeychain(keychain)
    state = .desconectado
  }

  private func cargarEstadoGuardado() {
    let guardadas = (try? SteamService.Credentials.fromKeychain(keychain)) ?? nil
    state = guardadas != nil ? .conectado : .desconectado
  }

  private static func estado(para error: Error) -> State {
    if let red = error as? NetworkError {
      return .fallo(message: red.errorDescription ?? "", suggestion: red.recoverySuggestion)
    }
    return .fallo(message: error.localizedDescription, suggestion: nil)
  }
}
