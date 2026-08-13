//
//  XboxAccountViewModelTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Servicio de Xbox falso.
final class StubXboxAuthService: XboxAuthenticating, @unchecked Sendable {
  enum Behavior {
    case success(XboxCredentials)
    case failure(Error)
  }

  private let alIniciar: Behavior
  private let alRenovar: Behavior

  private(set) var renovaciones = 0
  private(set) var clientIDsRecibidos: [String] = []

  init(_ alIniciar: Behavior, alRenovar: Behavior? = nil) {
    self.alIniciar = alIniciar
    self.alRenovar = alRenovar ?? alIniciar
  }

  func signIn(authorizationCode: String, clientID: String, clientSecret: String) async throws -> XboxCredentials {
    clientIDsRecibidos.append(clientID)
    switch alIniciar {
    case .success(let credenciales): return credenciales
    case .failure(let error): throw error
    }
  }

  func refresh(using credentials: XboxCredentials) async throws -> XboxCredentials {
    renovaciones += 1
    switch alRenovar {
    case .success(let credenciales): return credenciales
    case .failure(let error): throw error
    }
  }
}

private func credenciales(
  xsts: String = "XSTS",
  vence: TimeInterval = 3600,
  gamertag: String? = "MiGamertag"
) -> XboxCredentials {
  XboxCredentials(
    clientID: "ID",
    clientSecret: "SECRETO",
    microsoftRefreshToken: "MS_REFRESCO",
    xstsToken: xsts,
    userHash: "HASH",
    expiresAt: Date().addingTimeInterval(vence),
    xuid: "123",
    gamertag: gamertag
  )
}

@MainActor
@Suite("Xbox: la app de Azure")
struct XboxAppCredentialsTests {

  @Test("Guardar deja hasAppCredentials en true")
  func guarda() throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = XboxAccountViewModel(service: StubXboxAuthService(.success(credenciales())), keychain: llavero)

    viewModel.saveAppCredentials(clientID: "MI_ID", clientSecret: "MI_SECRETO")

    #expect(viewModel.hasAppCredentials)
    #expect(viewModel.savedClientID == "MI_ID")
    #expect(try llavero.string(for: "xbox.clientSecret") == "MI_SECRETO")
  }

  @Test("Un campo vacio no se guarda")
  func campoVacio() {
    let viewModel = XboxAccountViewModel(
      service: StubXboxAuthService(.success(credenciales())),
      keychain: InMemoryKeychainStore()
    )

    viewModel.saveAppCredentials(clientID: "ID", clientSecret: "   ")

    #expect(!viewModel.hasAppCredentials)
  }

  @Test("Desconectar la sesion NO borra la app de Azure")
  func desconectarConservaLaApp() async {
    let llavero = InMemoryKeychainStore()
    let viewModel = XboxAccountViewModel(service: StubXboxAuthService(.success(credenciales())), keychain: llavero)
    viewModel.saveAppCredentials(clientID: "MI_ID", clientSecret: "MI_SECRETO")
    await viewModel.connect(authorizationCode: "X")

    viewModel.disconnect()

    #expect(viewModel.hasAppCredentials, "Azure solo muestra el secret una vez: perderlo obligaria a crear otro")
    #expect(viewModel.state == .desconectado)
  }
}

@MainActor
@Suite("Xbox: conectar la cuenta")
struct XboxAccountConnectTests {

  @Test("Al conectar guarda la sesion en el llavero, sin tocar la app")
  func conecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = XboxAccountViewModel(service: StubXboxAuthService(.success(credenciales())), keychain: llavero)
    viewModel.saveAppCredentials(clientID: "MI_ID", clientSecret: "MI_SECRETO")

    await viewModel.connect(authorizationCode: "MI_CODIGO")

    #expect(viewModel.state == .conectado)
    #expect(viewModel.gamertag == "MiGamertag")
    #expect(try llavero.string(for: "xbox.xstsToken") == "XSTS")
  }

  @Test("Sin app de Azure guardada, avisa en vez de intentar conectar")
  func sinAppGuardada() async {
    let servicio = StubXboxAuthService(.success(credenciales()))
    let viewModel = XboxAccountViewModel(service: servicio, keychain: InMemoryKeychainStore())

    await viewModel.connect(authorizationCode: "X")

    guard case .fallo = viewModel.state else {
      Issue.record("Se esperaba estado fallo, quedo en \(viewModel.state)")
      return
    }
    #expect(servicio.clientIDsRecibidos.isEmpty, "No deberia haber intentado conectar sin la app guardada")
  }

  @Test("Los tokens NO se guardan en UserDefaults")
  func nadaEnUserDefaults() async throws {
    let marcador = "XBOX-SECRETO-\(UUID().uuidString)"

    for clave in UserDefaults.standard.dictionaryRepresentation().keys where clave.hasPrefix("xbox.") {
      UserDefaults.standard.removeObject(forKey: clave)
    }

    let viewModel = XboxAccountViewModel(
      service: StubXboxAuthService(.success(credenciales(xsts: marcador))),
      keychain: InMemoryKeychainStore()
    )
    viewModel.saveAppCredentials(clientID: "ID", clientSecret: "SECRETO")
    await viewModel.connect(authorizationCode: "X")

    let guardado = UserDefaults.standard.dictionaryRepresentation()
    for (clave, valor) in guardado {
      #expect(!"\(valor)".contains(marcador), "El token aparecio en UserDefaults, bajo '\(clave)'")
    }
    #expect(guardado.keys.first { $0.hasPrefix("xbox.") } == nil)
  }

  @Test("Un codigo invalido deja el estado pidiendo uno nuevo")
  func codigoInvalido() async {
    let viewModel = XboxAccountViewModel(
      service: StubXboxAuthService(.failure(XboxAuthError.codigoInvalido)),
      keychain: InMemoryKeychainStore()
    )
    viewModel.saveAppCredentials(clientID: "ID", clientSecret: "SECRETO")

    await viewModel.connect(authorizationCode: "MALO")

    guard case .necesitaCodigoNuevo = viewModel.state else {
      Issue.record("Se esperaba necesitaCodigoNuevo, quedo en \(viewModel.state)")
      return
    }
  }

  @Test("Credenciales de app invalidas no piden un codigo nuevo, piden revisar Azure")
  func credencialesDeAppInvalidas() async {
    let viewModel = XboxAccountViewModel(
      service: StubXboxAuthService(.failure(XboxAuthError.credencialesDeAppInvalidas)),
      keychain: InMemoryKeychainStore()
    )
    viewModel.saveAppCredentials(clientID: "MALO", clientSecret: "MALO")

    await viewModel.connect(authorizationCode: "X")

    guard case .fallo(_, let sugerencia) = viewModel.state else {
      Issue.record("Se esperaba estado fallo, quedo en \(viewModel.state)")
      return
    }
    #expect(sugerencia?.contains("azure") == true)
  }
}

@MainActor
@Suite("Xbox: renovar sola")
struct XboxAccountRefreshTests {

  @Test("Con el XSTS vigente no se renueva de gratis")
  func noRenuevaSiNoHaceFalta() async throws {
    let servicio = StubXboxAuthService(.success(credenciales(xsts: "PRIMERO")))
    let viewModel = XboxAccountViewModel(service: servicio, keychain: InMemoryKeychainStore())
    viewModel.saveAppCredentials(clientID: "ID", clientSecret: "SECRETO")
    await viewModel.connect(authorizationCode: "X")

    let cabecera = try await viewModel.validAuthorizationHeader()

    #expect(cabecera.contains("PRIMERO"))
    #expect(servicio.renovaciones == 0)
  }

  @Test("Con el XSTS vencido se renueva sin molestar al usuario")
  func renuevaSola() async throws {
    let servicio = StubXboxAuthService(
      .success(credenciales(xsts: "VIEJO", vence: -10)),
      alRenovar: .success(credenciales(xsts: "NUEVO"))
    )
    let llavero = InMemoryKeychainStore()
    let viewModel = XboxAccountViewModel(service: servicio, keychain: llavero)
    viewModel.saveAppCredentials(clientID: "ID", clientSecret: "SECRETO")
    await viewModel.connect(authorizationCode: "X")

    let cabecera = try await viewModel.validAuthorizationHeader()

    #expect(cabecera.contains("NUEVO"))
    #expect(servicio.renovaciones == 1)
    #expect(try llavero.string(for: "xbox.xstsToken") == "NUEVO")
    #expect(viewModel.state == .conectado)
  }

  @Test("Si el refresco tampoco sirve, se pide un codigo nuevo")
  func refrescoMuerto() async {
    let servicio = StubXboxAuthService(
      .success(credenciales(vence: -10)),
      alRenovar: .failure(XboxAuthError.sesionExpirada)
    )
    let viewModel = XboxAccountViewModel(service: servicio, keychain: InMemoryKeychainStore())
    viewModel.saveAppCredentials(clientID: "ID", clientSecret: "SECRETO")
    await viewModel.connect(authorizationCode: "X")

    await #expect(throws: XboxAuthError.sesionExpirada) {
      try await viewModel.validAuthorizationHeader()
    }

    guard case .necesitaCodigoNuevo = viewModel.state else {
      Issue.record("Deberia pedir un codigo nuevo, y quedo en \(viewModel.state)")
      return
    }
  }

  @Test("Sin credenciales lo dice, en vez de fallar raro")
  func sinCredenciales() async {
    let viewModel = XboxAccountViewModel(
      service: StubXboxAuthService(.success(credenciales())),
      keychain: InMemoryKeychainStore()
    )

    await #expect(throws: XboxAuthError.sinCredenciales) {
      try await viewModel.validAuthorizationHeader()
    }
    #expect(viewModel.state == .desconectado)
  }
}

@MainActor
@Suite("Xbox: al arrancar")
struct XboxAccountStartupTests {

  @Test("Recuerda que ya estaba conectado")
  func recuerdaLaSesion() {
    let llavero = InMemoryKeychainStore(valoresIniciales: [
      "xbox.clientID": "ID",
      "xbox.clientSecret": "SECRETO",
      "xbox.refreshToken": "R",
      "xbox.xstsToken": "T",
      "xbox.userHash": "H",
      "xbox.expiresAt": String(Date().addingTimeInterval(3600).timeIntervalSince1970),
      "xbox.gamertag": "MiGamertag"
    ])

    let viewModel = XboxAccountViewModel(service: StubXboxAuthService(.success(credenciales())), keychain: llavero)

    #expect(viewModel.state == .conectado)
    #expect(viewModel.gamertag == "MiGamertag")
    #expect(viewModel.hasAppCredentials)
  }

  @Test("Sin nada guardado arranca desconectado")
  func arranqueLimpio() {
    let viewModel = XboxAccountViewModel(
      service: StubXboxAuthService(.success(credenciales())),
      keychain: InMemoryKeychainStore()
    )

    #expect(viewModel.state == .desconectado)
    #expect(!viewModel.hasAppCredentials)
  }
}
