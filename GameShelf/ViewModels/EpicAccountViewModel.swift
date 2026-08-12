//
//  EpicAccountViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// La conexion con la cuenta de Epic: conectar, renovar y desconectar.
///
/// Guarda las credenciales en el Keychain, igual que PSN. Aca importa aun mas:
/// Epic avisa en su propia pagina de que ese codigo **da acceso completo a la
/// cuenta**.
@Observable
@MainActor
final class EpicAccountViewModel {

  /// En que punto esta la conexion.
  enum State: Equatable {
    case desconectado
    case trabajando
    case conectado
    /// Hay credenciales guardadas pero ya no sirven.
    case necesitaCodigoNuevo(message: String, suggestion: String?)
    /// Fallo por otra cosa, por ejemplo la red.
    case fallo(message: String, suggestion: String?)

    var isWorking: Bool { self == .trabajando }
    var isConnected: Bool { self == .conectado }
  }

  private(set) var state: State = .desconectado

  /// Nombre de la cuenta conectada, si Epic lo dio.
  private(set) var displayName: String?

  /// Cuando habra que volver a generar el codigo.
  private(set) var reconnectBy: Date?

  private let service: EpicAuthenticating
  private let keychain: KeychainStoring

  private enum Clave {
    static let accessToken = "epic.accessToken"
    static let refreshToken = "epic.refreshToken"
    static let expiresAt = "epic.expiresAt"
    static let refreshExpiresAt = "epic.refreshExpiresAt"
    static let accountID = "epic.accountID"
    static let displayName = "epic.displayName"
  }

  init(service: EpicAuthenticating = EpicAuthService(), keychain: KeychainStoring = KeychainStore()) {
    self.service = service
    self.keychain = keychain
    cargarEstadoGuardado()
  }

  // MARK: - Conectar

  /// Canjea el codigo que el usuario pego.
  func connect(authorizationCode: String) async {
    guard !state.isWorking else { return }
    state = .trabajando

    do {
      let credenciales = try await service.signIn(authorizationCode: authorizationCode)
      try guardar(credenciales)
      state = .conectado
    } catch {
      state = Self.estado(para: error)
    }
  }

  /// Devuelve un token de acceso vigente, renovandolo si hace falta.
  @discardableResult
  func validAccessToken(at ahora: Date = Date()) async throws -> String {
    guard let guardadas = try credencialesGuardadas() else {
      state = .desconectado
      throw EpicAuthError.sinCredenciales
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

  /// El identificador de cuenta, que hara falta para pedir la biblioteca.
  func accountID() throws -> String? {
    try keychain.string(for: Clave.accountID)
  }

  /// Borra las credenciales del llavero.
  func disconnect() {
    for clave in [
      Clave.accessToken, Clave.refreshToken, Clave.expiresAt,
      Clave.refreshExpiresAt, Clave.accountID, Clave.displayName
    ] {
      try? keychain.remove(for: clave)
    }
    displayName = nil
    reconnectBy = nil
    state = .desconectado
  }

  // MARK: - Biblioteca

  /// En que punto esta la sincronizacion de la biblioteca de Epic.
  enum LibraryState: Equatable {
    case idle
    case syncing
    case succeeded(created: Int, updated: Int, merged: Int)
    case failed(message: String)

    var isSyncing: Bool { self == .syncing }
  }

  private(set) var libraryState: LibraryState = .idle

  /// Trae los juegos de Epic y los guarda.
  ///
  /// No propaga errores: los deja en `libraryState`. Si la sesion caduco, el
  /// estado de la cuenta pasa a pedir un codigo nuevo.
  func syncLibrary(into context: ModelContext, using client: HTTPClient = URLSessionHTTPClient()) async {
    guard !libraryState.isSyncing else { return }
    libraryState = .syncing

    let servicio = EpicLibraryService(
      client: client,
      accessToken: { [weak self] in
        guard let self else { throw EpicAuthError.sinCredenciales }
        return try await self.validAccessToken()
      },
      accountID: { [weak self] in try self?.accountID() }
    )

    do {
      let juegos = try await servicio.fetchOwnedGames()
      let resultado = try EpicLibrarySyncer.sync(juegos, into: context)
      libraryState = .succeeded(
        created: resultado.created,
        updated: resultado.updated,
        merged: resultado.merged
      )
    } catch let error as EpicAuthError {
      state = Self.estado(para: error)
      libraryState = .failed(message: error.errorDescription ?? "")
    } catch let error as NetworkError {
      libraryState = .failed(
        message: error.errorDescription ?? String(localized: "No se pudo sincronizar.", comment: "Error generico")
      )
    } catch {
      libraryState = .failed(message: error.localizedDescription)
    }
  }

  // MARK: - Guardado

  private func cargarEstadoGuardado() {
    guard let credenciales = (try? credencialesGuardadas()) ?? nil else {
      state = .desconectado
      return
    }

    displayName = credenciales.displayName
    reconnectBy = credenciales.refreshExpiresAt
    state = .conectado
  }

  private func credencialesGuardadas() throws -> EpicCredentials? {
    guard let access = try keychain.string(for: Clave.accessToken),
          let refresh = try keychain.string(for: Clave.refreshToken),
          let vence = try keychain.string(for: Clave.expiresAt),
          let segundos = TimeInterval(vence)
    else { return nil }

    let refrescoVence = (try? keychain.string(for: Clave.refreshExpiresAt))
      .flatMap { $0 }
      .flatMap(TimeInterval.init)
      .map(Date.init(timeIntervalSince1970:))

    return EpicCredentials(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: Date(timeIntervalSince1970: segundos),
      refreshExpiresAt: refrescoVence,
      accountID: try keychain.string(for: Clave.accountID),
      displayName: try keychain.string(for: Clave.displayName)
    )
  }

  private func guardar(_ credenciales: EpicCredentials) throws {
    try keychain.set(credenciales.accessToken, for: Clave.accessToken)
    try keychain.set(credenciales.refreshToken, for: Clave.refreshToken)
    try keychain.set(String(credenciales.expiresAt.timeIntervalSince1970), for: Clave.expiresAt)

    // Estos tres solo se escriben si vinieron: una renovacion no siempre los
    // repite, y borrarlos dejaria la pantalla sin datos que ya se conocian.
    if let vence = credenciales.refreshExpiresAt {
      try keychain.set(String(vence.timeIntervalSince1970), for: Clave.refreshExpiresAt)
      reconnectBy = vence
    }
    if let cuenta = credenciales.accountID {
      try keychain.set(cuenta, for: Clave.accountID)
    }
    if let nombre = credenciales.displayName {
      try keychain.set(nombre, for: Clave.displayName)
      displayName = nombre
    }
  }

  /// Traduce un error al estado que corresponde.
  private static func estado(para error: Error) -> State {
    if let epic = error as? EpicAuthError {
      let mensaje = epic.errorDescription ?? ""
      return epic.necesitaCodigoNuevo
        ? .necesitaCodigoNuevo(message: mensaje, suggestion: epic.recoverySuggestion)
        : .fallo(message: mensaje, suggestion: epic.recoverySuggestion)
    }

    if let red = error as? NetworkError {
      return .fallo(message: red.errorDescription ?? "", suggestion: red.recoverySuggestion)
    }

    return .fallo(message: error.localizedDescription, suggestion: nil)
  }
}
