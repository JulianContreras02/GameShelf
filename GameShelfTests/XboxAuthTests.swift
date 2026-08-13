//
//  XboxAuthTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Transporte falso: responde lo que se le indique para cada URL, en orden.
final class StubXboxAuthTransport: XboxAuthTransporting, @unchecked Sendable {
  private var respuestasDeFormulario: [String]
  private var respuestasDeJSON: [String]

  private(set) var camposDeFormulario: [[String: String]] = []
  private(set) var jsonEnviados: [[String: Any]] = []
  private(set) var urlsDeJSON: [URL] = []

  init(formulario: [String], json: [String]) {
    self.respuestasDeFormulario = formulario
    self.respuestasDeJSON = json
  }

  func postForm(_ campos: [String: String], to url: URL) async throws -> Data {
    camposDeFormulario.append(campos)
    guard !respuestasDeFormulario.isEmpty else { return Data() }
    return Data(respuestasDeFormulario.removeFirst().utf8)
  }

  func postXboxJSON(_ body: Data, to url: URL) async throws -> Data {
    urlsDeJSON.append(url)
    if let objeto = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
      jsonEnviados.append(objeto)
    }
    guard !respuestasDeJSON.isEmpty else { return Data() }
    return Data(respuestasDeJSON.removeFirst().utf8)
  }
}

private let tokenDeMicrosoft = """
  {"token_type":"bearer","expires_in":3600,"scope":"Xboxlive.signin Xboxlive.offline_access",
  "access_token":"MS_ACCESO","refresh_token":"MS_REFRESCO","user_id":"123"}
  """

private let tokenDeUsuario = """
  {"IssueInstant":"2026-01-01T00:00:00.0000000Z","NotAfter":"2026-01-01T01:00:00.0000000Z",
  "Token":"USER_TOKEN","DisplayClaims":{"xui":[{"uhs":"EL_HASH"}]}}
  """

private let tokenXSTS = """
  {"IssueInstant":"2026-01-01T00:00:00.0000000Z","NotAfter":"2999-10-24T03:04:29.6037497Z",
  "Token":"XSTS_TOKEN","DisplayClaims":{"xui":[
  {"uhs":"EL_HASH","xid":"123456789","gtg":"MiGamertag"}]}}
  """

@Suite("Xbox: iniciar sesion")
struct XboxSignInTests {

  private func transporte() -> StubXboxAuthTransport {
    StubXboxAuthTransport(formulario: [tokenDeMicrosoft], json: [tokenDeUsuario, tokenXSTS])
  }

  @Test("Con un codigo valido hace los tres pasos y arma las credenciales")
  func inicioCorrecto() async throws {
    let credenciales = try await XboxAuthService(transport: transporte())
      .signIn(authorizationCode: "MI_CODIGO", clientID: "ID", clientSecret: "SECRETO")

    #expect(credenciales.xstsToken == "XSTS_TOKEN")
    #expect(credenciales.userHash == "EL_HASH")
    #expect(credenciales.xuid == "123456789")
    #expect(credenciales.gamertag == "MiGamertag")
    #expect(credenciales.microsoftRefreshToken == "MS_REFRESCO")
    #expect(credenciales.clientID == "ID")
    #expect(credenciales.clientSecret == "SECRETO")
  }

  @Test("La fecha de vencimiento viene del XSTS, con mas digitos de fraccion de los normales")
  func vencimiento() async throws {
    let credenciales = try await XboxAuthService(transport: transporte())
      .signIn(authorizationCode: "X", clientID: "ID", clientSecret: "SECRETO")

    // "2999-10-24T03:04:29.6037497Z": si no se recorta la fraccion, no se
    // parsea y la prueba de mas abajo (parseo) lo detecta antes que esta.
    let esperado = ISO8601DateFormatter().date(from: "2999-10-24T03:04:29Z")
    #expect(credenciales.expiresAt == esperado)
  }

  @Test("Manda el codigo, el client id y el client secret en el formulario")
  func camposDelFormulario() async throws {
    let transporte = transporte()

    _ = try await XboxAuthService(transport: transporte)
      .signIn(authorizationCode: "  ABC \n", clientID: "MI_ID", clientSecret: "MI_SECRETO")

    let campos = try #require(transporte.camposDeFormulario.first)
    #expect(campos["grant_type"] == "authorization_code")
    #expect(campos["code"] == "ABC", "Se recortan los espacios al pegar")
    #expect(campos["client_id"] == "MI_ID")
    #expect(campos["client_secret"] == "MI_SECRETO")
  }

  @Test("El token de usuario manda el access token de Microsoft como RpsTicket")
  func tokenDeUsuarioCorrecto() async throws {
    let transporte = transporte()

    _ = try await XboxAuthService(transport: transporte)
      .signIn(authorizationCode: "X", clientID: "ID", clientSecret: "SECRETO")

    let primero = try #require(transporte.jsonEnviados.first)
    let propiedades = try #require(primero["Properties"] as? [String: Any])
    #expect(propiedades["RpsTicket"] as? String == "d=MS_ACCESO")
    #expect(primero["RelyingParty"] as? String == "http://auth.xboxlive.com")
  }

  @Test("El XSTS manda el token de usuario recien conseguido")
  func xstsCorrecto() async throws {
    let transporte = transporte()

    _ = try await XboxAuthService(transport: transporte)
      .signIn(authorizationCode: "X", clientID: "ID", clientSecret: "SECRETO")

    let segundo = try #require(transporte.jsonEnviados.dropFirst().first)
    let propiedades = try #require(segundo["Properties"] as? [String: Any])
    #expect((propiedades["UserTokens"] as? [String])?.first == "USER_TOKEN")
    #expect(segundo["RelyingParty"] as? String == "http://xboxlive.com")
  }

  @Test("Un codigo vacio no llega ni a pedir")
  func codigoVacio() async {
    let transporte = transporte()

    let servicio = XboxAuthService(transport: transporte)
    await #expect(throws: XboxAuthError.codigoInvalido) {
      try await servicio.signIn(authorizationCode: "   ", clientID: "ID", clientSecret: "S")
    }
    #expect(transporte.camposDeFormulario.isEmpty)
  }

  @Test("Sin app de Azure guardada, avisa antes de pedir nada")
  func sinAppDeAzure() async {
    let transporte = transporte()
    let servicio = XboxAuthService(transport: transporte)

    await #expect(throws: XboxAuthError.sinCredencialesDeApp) {
      try await servicio.signIn(authorizationCode: "X", clientID: "  ", clientSecret: "S")
    }
    #expect(transporte.camposDeFormulario.isEmpty)
  }

  @Test("invalid_grant se traduce a codigo invalido")
  func codigoRechazado() async {
    let transporte = StubXboxAuthTransport(
      formulario: [#"{"error":"invalid_grant","error_description":"The provided authorization code is invalid"}"#],
      json: []
    )

    let servicio = XboxAuthService(transport: transporte)
    let error = await #expect(throws: XboxAuthError.self) {
      try await servicio.signIn(authorizationCode: "VIEJO", clientID: "ID", clientSecret: "S")
    }

    #expect(error == .codigoInvalido)
    #expect(error?.necesitaCodigoNuevo == true)
  }

  @Test("invalid_client se traduce a credenciales de app invalidas")
  func appRechazada() async {
    let transporte = StubXboxAuthTransport(
      formulario: [#"{"error":"invalid_client","error_description":"Invalid client secret"}"#],
      json: []
    )

    let servicio = XboxAuthService(transport: transporte)
    let error = await #expect(throws: XboxAuthError.self) {
      try await servicio.signIn(authorizationCode: "X", clientID: "MALO", clientSecret: "MALO")
    }

    #expect(error == .credencialesDeAppInvalidas)
    #expect(error?.necesitaCodigoNuevo == false, "Un client id malo no se arregla con un codigo nuevo")
  }

  @Test("Xbox Live rechazando el user token da un error accionable, no un crash")
  func userTokenRechazado() async {
    let transporte = StubXboxAuthTransport(formulario: [tokenDeMicrosoft], json: [])

    await #expect(throws: XboxAuthError.self) {
      try await XboxAuthService(transport: transporte).signIn(authorizationCode: "X", clientID: "ID", clientSecret: "S")
    }
  }
}

@Suite("Xbox: renovar la sesion")
struct XboxRefreshTests {

  private func credenciales() -> XboxCredentials {
    XboxCredentials(
      clientID: "ID",
      clientSecret: "SECRETO",
      microsoftRefreshToken: "VIEJO_REFRESCO",
      xstsToken: "VIEJO_XSTS",
      userHash: "HASH",
      expiresAt: Date(timeIntervalSince1970: 1000),
      xuid: "1",
      gamertag: "Antiguo"
    )
  }

  @Test("Renueva con el refresh token de Microsoft, reusando la app guardada")
  func renovacion() async throws {
    let transporte = StubXboxAuthTransport(formulario: [tokenDeMicrosoft], json: [tokenDeUsuario, tokenXSTS])

    let credenciales = try await XboxAuthService(transport: transporte).refresh(using: credenciales())

    #expect(credenciales.xstsToken == "XSTS_TOKEN")
    #expect(credenciales.clientID == "ID")
    #expect(credenciales.clientSecret == "SECRETO")

    let campos = try #require(transporte.camposDeFormulario.first)
    #expect(campos["grant_type"] == "refresh_token")
    #expect(campos["refresh_token"] == "VIEJO_REFRESCO")
  }

  @Test("Un refresh token muerto pide volver a empezar")
  func refrescoMuerto() async {
    let transporte = StubXboxAuthTransport(
      formulario: [#"{"error":"invalid_grant","error_description":"The refresh token has expired"}"#],
      json: []
    )

    let error = await #expect(throws: XboxAuthError.self) {
      try await XboxAuthService(transport: transporte).refresh(using: credenciales())
    }

    #expect(error == .sesionExpirada)
  }
}

@Suite("Xbox: la URL de inicio de sesion")
struct XboxURLTests {

  @Test("Lleva el client id, la escala y el redirect de la app")
  func urlDeAutorizacion() throws {
    let url = try #require(XboxAuthService.authorizeURL(clientID: "MI_CLIENT_ID"))
    let texto = url.absoluteString

    #expect(texto.hasPrefix("https://login.live.com/oauth20_authorize.srf"))
    #expect(texto.contains("client_id=MI_CLIENT_ID"))
    #expect(texto.contains("response_type=code"))
    #expect(texto.contains("Xboxlive.signin"))
  }

  @Test("Todo va por https, menos el redirect de localhost")
  func seguras() {
    #expect(XboxAuthService.authorizeBaseURL.scheme == "https")
    #expect(XboxAuthService.tokenURL.scheme == "https")
    #expect(XboxAuthService.userTokenURL.scheme == "https")
    #expect(XboxAuthService.xstsURL.scheme == "https")
  }
}

@Suite("Xbox: vencimiento y mensajes")
struct XboxExpiryTests {

  private func credenciales(venceEn segundos: TimeInterval) -> XboxCredentials {
    XboxCredentials(
      clientID: "ID",
      clientSecret: "S",
      microsoftRefreshToken: "R",
      xstsToken: "T",
      userHash: "H",
      expiresAt: Date(timeIntervalSince1970: 1000 + segundos),
      xuid: nil,
      gamertag: nil
    )
  }

  @Test("Un token a punto de vencer se trata como vencido")
  func margen() {
    let ahora = Date(timeIntervalSince1970: 1000)

    #expect(!credenciales(venceEn: 3600).isExpired(at: ahora))
    #expect(credenciales(venceEn: 30).isExpired(at: ahora))
    #expect(credenciales(venceEn: -1).isExpired(at: ahora))
  }

  @Test("La cabecera lleva el user hash y el token, en el formato que pide Xbox Live")
  func cabecera() {
    let credenciales = credenciales(venceEn: 3600)
    #expect(credenciales.authorizationHeader == "XBL3.0 x=H;T")
  }

  @Test("Todos los errores dicen que pasa")
  func mensajes() {
    let casos: [XboxAuthError] = [
      .codigoInvalido, .sesionExpirada, .credencialesDeAppInvalidas,
      .sinCredenciales, .sinCredencialesDeApp, .respuestaInesperada("x")
    ]

    for caso in casos {
      #expect(caso.errorDescription?.isEmpty == false, "Falta mensaje en \(caso)")
    }
  }

  @Test("Solo los de codigo o sesion piden uno nuevo")
  func cualesPidenCodigo() {
    #expect(XboxAuthError.codigoInvalido.necesitaCodigoNuevo)
    #expect(XboxAuthError.sesionExpirada.necesitaCodigoNuevo)

    // Un client id malo no se arregla pegando otro codigo: hay que corregir
    // la app de Azure primero.
    #expect(!XboxAuthError.credencialesDeAppInvalidas.necesitaCodigoNuevo)
    #expect(!XboxAuthError.respuestaInesperada("x").necesitaCodigoNuevo)
  }
}
