//
//  PSNAccountViewModel.swift
//  GameShelf
//

import Foundation

/// La conexion con la cuenta de PlayStation: conectar, renovar y desconectar.
///
/// Guarda las credenciales en el Keychain, nunca en `UserDefaults`: el token de
/// acceso vale por la cuenta entera de Sony, y `UserDefaults` es un archivo sin
/// cifrar dentro del contenedor de la app.
@Observable
@MainActor
final class PSNAccountViewModel {

  /// En que punto esta la conexion.
  enum State: Equatable {
    /// Nunca se ha conectado, o se desconecto.
    case desconectado
    /// Canjeando el codigo o renovando.
    case trabajando
    /// Conectado y con token vigente.
    case conectado
    /// Hay credenciales guardadas pero ya no sirven.
    case necesitaTokenNuevo(message: String, suggestion: String?)
    /// Fallo por otra cosa, por ejemplo la red.
    case fallo(message: String, suggestion: String?)

    var isWorking: Bool { self == .trabajando }

    var isConnected: Bool { self == .conectado }
  }

  private(set) var state: State = .desconectado

  /// Cuando caduca el token de acceso actual. Solo para mostrarlo.
  private(set) var expiresAt: Date?

  private let service: PSNAuthenticating
  private let keychain: KeychainStoring

  /// Claves dentro del llavero.
  private enum Clave {
    static let accessToken = "psn.accessToken"
    static let refreshToken = "psn.refreshToken"
    static let expiresAt = "psn.expiresAt"
  }

  init(service: PSNAuthenticating = PSNAuthService(), keychain: KeychainStoring = KeychainStore()) {
    self.service = service
    self.keychain = keychain
    cargarEstadoGuardado()
  }

  // MARK: - Conectar

  /// Canjea el codigo que el usuario pego y guarda las credenciales.
  ///
  /// No propaga errores: los deja en `state` para que la vista los muestre.
  func connect(npsso: String) async {
    guard !state.isWorking else { return }
    state = .trabajando

    do {
      let credenciales = try await service.signIn(npsso: npsso)
      try guardar(credenciales)
      state = .conectado
    } catch {
      state = Self.estado(para: error)
    }
  }

  /// Devuelve un token de acceso vigente, renovandolo si hace falta.
  ///
  /// Es lo que usaran las llamadas a la API de PSN. Renueva sola mientras el
  /// refresh token siga sirviendo; cuando deja de servir, el estado pasa a
  /// `necesitaTokenNuevo` y hay que pedirle al usuario un NPSSO nuevo.
  ///
  /// - Throws: `PSNAuthError` si no hay credenciales o si ya no se pueden
  ///   renovar.
  @discardableResult
  func validAccessToken(at ahora: Date = Date()) async throws -> String {
    guard let guardadas = try credencialesGuardadas() else {
      state = .desconectado
      throw PSNAuthError.sinCredenciales
    }

    guard guardadas.isExpired(at: ahora) else {
      state = .conectado
      return guardadas.accessToken
    }

    do {
      let renovadas = try await service.refresh(using: guardadas.refreshToken)
      try guardar(renovadas)
      state = .conectado
      return renovadas.accessToken
    } catch {
      state = Self.estado(para: error)
      throw error
    }
  }

  /// Borra las credenciales del llavero.
  func disconnect() {
    try? keychain.remove(for: Clave.accessToken)
    try? keychain.remove(for: Clave.refreshToken)
    try? keychain.remove(for: Clave.expiresAt)
    expiresAt = nil
    state = .desconectado
  }

  // MARK: - Guardado

  /// Lee lo guardado al arrancar, para saber si mostrar "conectado".
  private func cargarEstadoGuardado() {
    guard let credenciales = (try? credencialesGuardadas()) ?? nil else {
      state = .desconectado
      return
    }

    expiresAt = credenciales.expiresAt

    // Un token de acceso vencido no es problema: se renueva solo en la primera
    // peticion. Se muestra como conectado porque, de cara al usuario, lo esta.
    state = .conectado
  }

  private func credencialesGuardadas() throws -> PSNCredentials? {
    guard let access = try keychain.string(for: Clave.accessToken),
          let refresh = try keychain.string(for: Clave.refreshToken),
          let vence = try keychain.string(for: Clave.expiresAt),
          let segundos = TimeInterval(vence)
    else { return nil }

    return PSNCredentials(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: Date(timeIntervalSince1970: segundos)
    )
  }

  private func guardar(_ credenciales: PSNCredentials) throws {
    try keychain.set(credenciales.accessToken, for: Clave.accessToken)
    try keychain.set(credenciales.refreshToken, for: Clave.refreshToken)
    try keychain.set(String(credenciales.expiresAt.timeIntervalSince1970), for: Clave.expiresAt)
    expiresAt = credenciales.expiresAt
  }

  /// Traduce un error al estado que corresponde.
  ///
  /// La distincion importa: si hace falta un token nuevo, la pantalla tiene que
  /// mostrar las instrucciones otra vez; si fue la red, basta con reintentar.
  private static func estado(para error: Error) -> State {
    if let psn = error as? PSNAuthError {
      let mensaje = psn.errorDescription ?? ""
      return psn.necesitaTokenNuevo
        ? .necesitaTokenNuevo(message: mensaje, suggestion: psn.recoverySuggestion)
        : .fallo(message: mensaje, suggestion: psn.recoverySuggestion)
    }

    if let red = error as? NetworkError {
      return .fallo(message: red.errorDescription ?? "", suggestion: red.recoverySuggestion)
    }

    return .fallo(message: error.localizedDescription, suggestion: nil)
  }
}
