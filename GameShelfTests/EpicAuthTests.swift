//
//  EpicAuthTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Transporte falso: devuelve la respuesta que se le indique.
final class StubFormTransport: FormPostTransporting, @unchecked Sendable {
  private let respuesta: String

  private(set) var camposEnviados: [[String: String]] = []
  private(set) var autorizacionRecibida: String?

  init(responde json: String) {
    self.respuesta = json
  }

  func postForm(_ campos: [String: String], to url: URL, authorization: String) async throws -> Data {
    camposEnviados.append(campos)
    autorizacionRecibida = authorization
    return Data(respuesta.utf8)
  }
}

private let tokensValidos = """
  {"access_token":"ACCESO","refresh_token":"REFRESCO","expires_in":28800,
  "refresh_expires":1987200,"account_id":"abc123","displayName":"Kawaii035"}
  """

@Suite("Epic: iniciar sesion")
struct EpicSignInTests {

  @Test("Con un codigo valido devuelve credenciales")
  func inicioCorrecto() async throws {
    let transporte = StubFormTransport(responde: tokensValidos)
    let ahora = Date(timeIntervalSince1970: 1_000_000)

    let credenciales = try await EpicAuthService(transport: transporte, ahora: { ahora })
      .signIn(authorizationCode: "MI_CODIGO")

    #expect(credenciales.accessToken == "ACCESO")
    #expect(credenciales.refreshToken == "REFRESCO")
    #expect(credenciales.expiresAt == ahora.addingTimeInterval(28_800))
    #expect(credenciales.accountID == "abc123")
    #expect(credenciales.displayName == "Kawaii035")
  }

  @Test("Guarda cuando habra que volver a empezar")
  func fechaDeReconexion() async throws {
    let transporte = StubFormTransport(responde: tokensValidos)
    let ahora = Date(timeIntervalSince1970: 1000)

    let credenciales = try await EpicAuthService(transport: transporte, ahora: { ahora })
      .signIn(authorizationCode: "X")

    #expect(credenciales.refreshExpiresAt == ahora.addingTimeInterval(1_987_200))
  }

  @Test("Manda los campos que espera Epic")
  func camposDelFormulario() async throws {
    let transporte = StubFormTransport(responde: tokensValidos)

    _ = try await EpicAuthService(transport: transporte).signIn(authorizationCode: "  ABC \n")

    let campos = try #require(transporte.camposEnviados.first)
    #expect(campos["grant_type"] == "authorization_code")
    #expect(campos["code"] == "ABC", "Se recortan los espacios al pegar")
    #expect(campos["token_type"] == "eg1")

    // Epic espera la cabecera en minuscula, como la manda su launcher.
    #expect(transporte.autorizacionRecibida?.hasPrefix("basic ") == true)
  }

  @Test("Un codigo vacio no llega ni a pedir")
  func codigoVacio() async {
    let transporte = StubFormTransport(responde: tokensValidos)

    await #expect(throws: EpicAuthError.codigoInvalido) {
      try await EpicAuthService(transport: transporte).signIn(authorizationCode: "   ")
    }
    #expect(transporte.camposEnviados.isEmpty)
  }

  @Test("Un codigo caducado se traduce a algo accionable")
  func codigoCaducado() async {
    // Respuesta real de Epic al mandar un codigo que ya no existe.
    let transporte = StubFormTransport(responde: """
      {"errorCode":"errors.com.epicgames.account.oauth.authorization_code_not_found",
      "errorMessage":"Sorry the authorization code you supplied was not found.",
      "numericErrorCode":18059}
      """)

    let error = await #expect(throws: EpicAuthError.self) {
      try await EpicAuthService(transport: transporte).signIn(authorizationCode: "VIEJO")
    }

    #expect(error == .codigoInvalido)
    // Los codigos de Epic caducan en segundos: la sugerencia tiene que decirlo.
    #expect(error?.recoverySuggestion?.isEmpty == false)
  }

  @Test("Una respuesta incompleta no se toma por buena")
  func respuestaIncompleta() async {
    let transporte = StubFormTransport(responde: #"{"access_token":"SOLO_ESTE"}"#)

    await #expect(throws: EpicAuthError.self) {
      try await EpicAuthService(transport: transporte).signIn(authorizationCode: "X")
    }
  }
}

@Suite("Epic: renovar la sesion")
struct EpicRefreshTests {

  @Test("Renueva con el refresh token")
  func renovacion() async throws {
    let transporte = StubFormTransport(responde: tokensValidos)

    let credenciales = try await EpicAuthService(transport: transporte).refresh(using: "VIEJO")

    #expect(credenciales.accessToken == "ACCESO")

    let campos = try #require(transporte.camposEnviados.first)
    #expect(campos["grant_type"] == "refresh_token")
    #expect(campos["refresh_token"] == "VIEJO")
  }

  @Test("Un refresh token muerto pide volver a empezar")
  func refrescoMuerto() async {
    // Respuesta real de Epic.
    let transporte = StubFormTransport(responde: """
      {"errorCode":"errors.com.epicgames.account.auth_token.invalid_refresh_token",
      "errorMessage":"Sorry the refresh token is invalid.","numericErrorCode":18036}
      """)

    let error = await #expect(throws: EpicAuthError.self) {
      try await EpicAuthService(transport: transporte).refresh(using: "MUERTO")
    }

    #expect(error == .sesionExpirada)
    #expect(error?.necesitaCodigoNuevo == true)
  }

  @Test("Sin expires_in se asume la duracion habitual, no eterno")
  func sinDuracion() async throws {
    let transporte = StubFormTransport(responde: #"{"access_token":"A","refresh_token":"R"}"#)
    let ahora = Date(timeIntervalSince1970: 500)

    let credenciales = try await EpicAuthService(transport: transporte, ahora: { ahora })
      .refresh(using: "X")

    #expect(credenciales.expiresAt == ahora.addingTimeInterval(28_800))
  }
}

@Suite("Epic: las direcciones que ve el usuario")
struct EpicURLTests {

  // Como en PSN, ninguna otra prueba las cubre: la app compila igual con una
  // direccion equivocada y el fallo solo se ve al abrirla en un navegador.

  @Test("La pagina del codigo lleva el client id del launcher")
  func paginaDelCodigo() {
    let url = EpicAuthService.codeURL.absoluteString

    #expect(url.hasPrefix("https://www.epicgames.com/id/api/redirect"))
    #expect(url.contains("clientId=\(EpicAuthService.clientID)"))
    #expect(url.contains("responseType=code"))
  }

  @Test("La pagina de login vuelve a la del codigo al terminar")
  func paginaDeLogin() throws {
    let url = EpicAuthService.loginURL.absoluteString

    #expect(url.hasPrefix("https://www.epicgames.com/id/login?redirectUrl="))

    // El destino va codificado: sin escaparlo, Epic corta la direccion en el
    // primer "&" y el login no sabe a donde volver.
    #expect(!url.contains("redirectUrl=https://"))
    let decodificada = try #require(url.removingPercentEncoding)
    #expect(decodificada.contains("api/redirect"))
  }

  @Test("Todo va por https")
  func seguras() {
    #expect(EpicAuthService.codeURL.scheme == "https")
    #expect(EpicAuthService.loginURL.scheme == "https")
    #expect(EpicAuthService.tokenURL.scheme == "https")
  }
}

@Suite("Epic: vencimiento y mensajes")
struct EpicExpiryTests {

  private func credenciales(venceEn segundos: TimeInterval) -> EpicCredentials {
    EpicCredentials(
      accessToken: "A",
      refreshToken: "R",
      expiresAt: Date(timeIntervalSince1970: 1000 + segundos)
    )
  }

  @Test("Un token a punto de vencer se trata como vencido")
  func margen() {
    let ahora = Date(timeIntervalSince1970: 1000)

    #expect(!credenciales(venceEn: 3600).isExpired(at: ahora))
    #expect(credenciales(venceEn: 30).isExpired(at: ahora))
    #expect(credenciales(venceEn: -1).isExpired(at: ahora))
  }

  @Test("Todos los errores dicen que pasa")
  func mensajes() {
    let casos: [EpicAuthError] = [
      .codigoInvalido, .sesionExpirada, .sinCredenciales, .respuestaInesperada("x")
    ]

    for caso in casos {
      #expect(caso.errorDescription?.isEmpty == false, "Falta mensaje en \(caso)")
    }
  }

  @Test("Solo los de credenciales piden un codigo nuevo")
  func cualesPidenCodigo() {
    #expect(EpicAuthError.codigoInvalido.necesitaCodigoNuevo)
    #expect(EpicAuthError.sesionExpirada.necesitaCodigoNuevo)

    // Que Epic conteste raro no significa que el codigo del usuario este mal.
    #expect(!EpicAuthError.respuestaInesperada("x").necesitaCodigoNuevo)
  }
}

@MainActor
@Suite("Epic: la cuenta")
struct EpicAccountTests {

  private func servicio(_ credenciales: EpicCredentials) -> StubEpicAuthService {
    StubEpicAuthService(.success(credenciales))
  }

  private func credenciales(acceso: String = "ACCESO", vence: TimeInterval = 3600) -> EpicCredentials {
    EpicCredentials(
      accessToken: acceso,
      refreshToken: "REFRESCO",
      expiresAt: Date().addingTimeInterval(vence),
      refreshExpiresAt: Date().addingTimeInterval(1_987_200),
      accountID: "abc123",
      displayName: "Kawaii035"
    )
  }

  @Test("Al conectar guarda todo en el llavero")
  func conecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = EpicAccountViewModel(service: servicio(credenciales()), keychain: llavero)

    await viewModel.connect(authorizationCode: "X")

    #expect(viewModel.state == .conectado)
    #expect(try llavero.string(for: "epic.accessToken") == "ACCESO")
    #expect(try llavero.string(for: "epic.accountID") == "abc123")
    #expect(viewModel.displayName == "Kawaii035")
  }

  @Test("Los tokens NO se guardan en UserDefaults")
  func nadaEnUserDefaults() async throws {
    let marcador = "EPIC-SECRETO-\(UUID().uuidString)"

    for clave in UserDefaults.standard.dictionaryRepresentation().keys where clave.hasPrefix("epic.") {
      UserDefaults.standard.removeObject(forKey: clave)
    }

    let viewModel = EpicAccountViewModel(
      service: servicio(credenciales(acceso: marcador)),
      keychain: InMemoryKeychainStore()
    )
    await viewModel.connect(authorizationCode: "X")

    let guardado = UserDefaults.standard.dictionaryRepresentation()
    for (clave, valor) in guardado {
      #expect(!"\(valor)".contains(marcador), "El token aparecio en UserDefaults, bajo '\(clave)'")
    }
    #expect(guardado.keys.first { $0.hasPrefix("epic.") } == nil)
  }

  @Test("Desconectar borra todo, incluido el nombre y la cuenta")
  func desconecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = EpicAccountViewModel(service: servicio(credenciales()), keychain: llavero)
    await viewModel.connect(authorizationCode: "X")

    viewModel.disconnect()

    for clave in ["epic.accessToken", "epic.refreshToken", "epic.accountID", "epic.displayName"] {
      #expect(try llavero.string(for: clave) == nil, "Quedo \(clave) en el llavero")
    }
    #expect(viewModel.displayName == nil)
    #expect(viewModel.state == .desconectado)
  }

  @Test("Con el token vencido se renueva sola")
  func renuevaSola() async throws {
    let servicio = StubEpicAuthService(
      .success(credenciales(acceso: "VIEJO", vence: -10)),
      alRenovar: .success(credenciales(acceso: "NUEVO"))
    )
    let viewModel = EpicAccountViewModel(service: servicio, keychain: InMemoryKeychainStore())
    await viewModel.connect(authorizationCode: "X")

    let token = try await viewModel.validAccessToken()

    #expect(token == "NUEVO")
    #expect(servicio.renovaciones == 1)
  }

  @Test("Un fallo de red no se confunde con un codigo caducado")
  func falloDeRed() async {
    let viewModel = EpicAccountViewModel(
      service: StubEpicAuthService(.failure(NetworkError.noConnection)),
      keychain: InMemoryKeychainStore()
    )

    await viewModel.connect(authorizationCode: "X")

    guard case .fallo = viewModel.state else {
      Issue.record("Un fallo de red no deberia pedir un codigo nuevo: \(viewModel.state)")
      return
    }
  }

  @Test("Que Epic falle no afecta a las credenciales de PlayStation")
  func aisladoDePSN() async throws {
    // Es el criterio del issue: el conector mas fragil no puede llevarse por
    // delante a los demas.
    let llavero = InMemoryKeychainStore(valoresIniciales: [
      "psn.accessToken": "PSN_INTACTO",
      "psn.refreshToken": "PSN_REFRESCO",
      "psn.expiresAt": String(Date().addingTimeInterval(3600).timeIntervalSince1970)
    ])

    let epic = EpicAccountViewModel(
      service: StubEpicAuthService(.failure(EpicAuthError.codigoInvalido)),
      keychain: llavero
    )
    await epic.connect(authorizationCode: "MALO")
    epic.disconnect()

    #expect(try llavero.string(for: "psn.accessToken") == "PSN_INTACTO")

    let psn = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .failure(PSNAuthError.npssoInvalido)),
      keychain: llavero
    )
    #expect(psn.state == .conectado, "PlayStation sigue conectado")
  }
}

/// Servicio de Epic falso.
final class StubEpicAuthService: EpicAuthenticating, @unchecked Sendable {
  enum Behavior {
    case success(EpicCredentials)
    case failure(Error)
  }

  private let alIniciar: Behavior
  private let alRenovar: Behavior

  private(set) var renovaciones = 0

  init(_ alIniciar: Behavior, alRenovar: Behavior? = nil) {
    self.alIniciar = alIniciar
    self.alRenovar = alRenovar ?? alIniciar
  }

  func signIn(authorizationCode: String) async throws -> EpicCredentials {
    switch alIniciar {
    case .success(let credenciales): return credenciales
    case .failure(let error): throw error
    }
  }

  func refresh(using refreshToken: String) async throws -> EpicCredentials {
    renovaciones += 1
    switch alRenovar {
    case .success(let credenciales): return credenciales
    case .failure(let error): throw error
    }
  }
}
