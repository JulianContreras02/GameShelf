//
//  XboxAccountViewModel.swift
//  GameShelf
//

import Foundation

/// La conexion con la cuenta de Xbox: la app de Azure, conectar, renovar y
/// desconectar.
///
/// Va en dos piezas independientes, a diferencia de PSN y Epic:
/// - **La app de Azure** (client id y client secret) es del usuario, no de la
///   sesion. Azure solo muestra el secret una vez al crearlo, asi que
///   desconectar la cuenta no lo borra: perderlo obligaria a crear un secret
///   nuevo solo para volver a conectar.
/// - **La sesion** (el resto de las credenciales) si se borra al desconectar,
///   igual que en PSN y Epic.
@Observable
@MainActor
final class XboxAccountViewModel {

  enum State: Equatable {
    case desconectado
    case trabajando
    case conectado
    /// Hay credenciales guardadas pero ya no sirven.
    case necesitaCodigoNuevo(message: String, suggestion: String?)
    /// Fallo por otra cosa, por ejemplo la red o la app de Azure.
    case fallo(message: String, suggestion: String?)

    var isWorking: Bool { self == .trabajando }
    var isConnected: Bool { self == .conectado }
  }

  private(set) var state: State = .desconectado
  private(set) var gamertag: String?

  private let service: XboxAuthenticating
  private let keychain: KeychainStoring

  private enum Clave {
    static let clientID = "xbox.clientID"
    static let clientSecret = "xbox.clientSecret"
    static let refreshToken = "xbox.refreshToken"
    static let xstsToken = "xbox.xstsToken"
    static let userHash = "xbox.userHash"
    static let expiresAt = "xbox.expiresAt"
    static let xuid = "xbox.xuid"
    static let gamertag = "xbox.gamertag"
  }

  init(service: XboxAuthenticating = XboxAuthService(), keychain: KeychainStoring = KeychainStore()) {
    self.service = service
    self.keychain = keychain
    cargarEstadoGuardado()
  }

  // MARK: - App de Azure

  /// Si ya se guardo el client id y el client secret de la app de Azure.
  var hasAppCredentials: Bool {
    savedClientID != nil
  }

  /// El client id guardado, para armar la URL de inicio de sesion sin volver
  /// a pedirlo en pantalla. A diferencia del secret, no es sensible: es un
  /// identificador publico de la app, no una credencial.
  var savedClientID: String? {
    (try? keychain.string(for: Clave.clientID)) ?? nil
  }

  /// Guarda el client id y el client secret que el usuario registro en Azure.
  ///
  /// No se verifican aca: la unica forma de comprobarlos es canjeando un
  /// codigo de verdad, que pasa en `connect`.
  func saveAppCredentials(clientID: String, clientSecret: String) {
    let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    let secreto = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty, !secreto.isEmpty else { return }

    try? keychain.set(id, for: Clave.clientID)
    try? keychain.set(secreto, for: Clave.clientSecret)
  }

  // MARK: - Conectar

  /// Canjea el codigo que el usuario pego, con la app de Azure ya guardada.
  func connect(authorizationCode: String) async {
    guard !state.isWorking else { return }

    guard let clientID = try? keychain.string(for: Clave.clientID),
          let clientSecret = try? keychain.string(for: Clave.clientSecret)
    else {
      state = Self.estado(para: XboxAuthError.sinCredencialesDeApp)
      return
    }

    state = .trabajando

    do {
      let credenciales = try await service.signIn(
        authorizationCode: authorizationCode,
        clientID: clientID,
        clientSecret: clientSecret
      )
      try guardar(credenciales)
      state = .conectado
    } catch {
      state = Self.estado(para: error)
    }
  }

  /// Devuelve la cabecera `Authorization` vigente, renovandola si hace falta.
  @discardableResult
  func validAuthorizationHeader(at ahora: Date = Date()) async throws -> String {
    guard let guardadas = try credencialesGuardadas() else {
      state = .desconectado
      throw XboxAuthError.sinCredenciales
    }

    guard guardadas.isExpired(at: ahora) else {
      state = .conectado
      return guardadas.authorizationHeader
    }

    do {
      let renovadas = try await service.refresh(using: guardadas)
      try guardar(renovadas)
      state = .conectado
      return renovadas.authorizationHeader
    } catch {
      state = Self.estado(para: error)
      throw error
    }
  }

  /// Borra la sesion del llavero. El client id y el client secret **no** se
  /// tocan: son de la app registrada, no de la sesion.
  func disconnect() {
    for clave in [
      Clave.refreshToken, Clave.xstsToken, Clave.userHash,
      Clave.expiresAt, Clave.xuid, Clave.gamertag
    ] {
      try? keychain.remove(for: clave)
    }
    gamertag = nil
    state = .desconectado
  }

  // MARK: - Guardado

  private func cargarEstadoGuardado() {
    guard let credenciales = (try? credencialesGuardadas()) ?? nil else {
      state = .desconectado
      return
    }
    gamertag = credenciales.gamertag
    state = .conectado
  }

  private func credencialesGuardadas() throws -> XboxCredentials? {
    guard let clientID = try keychain.string(for: Clave.clientID),
          let clientSecret = try keychain.string(for: Clave.clientSecret),
          let refresh = try keychain.string(for: Clave.refreshToken),
          let xsts = try keychain.string(for: Clave.xstsToken),
          let userHash = try keychain.string(for: Clave.userHash),
          let vence = try keychain.string(for: Clave.expiresAt),
          let segundos = TimeInterval(vence)
    else { return nil }

    return XboxCredentials(
      clientID: clientID,
      clientSecret: clientSecret,
      microsoftRefreshToken: refresh,
      xstsToken: xsts,
      userHash: userHash,
      expiresAt: Date(timeIntervalSince1970: segundos),
      xuid: try keychain.string(for: Clave.xuid),
      gamertag: try keychain.string(for: Clave.gamertag)
    )
  }

  private func guardar(_ credenciales: XboxCredentials) throws {
    try keychain.set(credenciales.microsoftRefreshToken, for: Clave.refreshToken)
    try keychain.set(credenciales.xstsToken, for: Clave.xstsToken)
    try keychain.set(credenciales.userHash, for: Clave.userHash)
    try keychain.set(String(credenciales.expiresAt.timeIntervalSince1970), for: Clave.expiresAt)

    if let xuid = credenciales.xuid {
      try keychain.set(xuid, for: Clave.xuid)
    }
    if let gamertag = credenciales.gamertag {
      try keychain.set(gamertag, for: Clave.gamertag)
      self.gamertag = gamertag
    }
  }

  /// Traduce un error al estado que corresponde.
  private static func estado(para error: Error) -> State {
    if let xbox = error as? XboxAuthError {
      let mensaje = xbox.errorDescription ?? ""
      return xbox.necesitaCodigoNuevo
        ? .necesitaCodigoNuevo(message: mensaje, suggestion: xbox.recoverySuggestion)
        : .fallo(message: mensaje, suggestion: xbox.recoverySuggestion)
    }

    if let red = error as? NetworkError {
      return .fallo(message: red.errorDescription ?? "", suggestion: red.recoverySuggestion)
    }

    return .fallo(message: error.localizedDescription, suggestion: nil)
  }
}
