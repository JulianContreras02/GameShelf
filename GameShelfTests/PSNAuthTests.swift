//
//  PSNAuthTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Transporte falso: devuelve la redireccion y la respuesta que se le digan.
final class StubPSNTransport: PSNAuthTransporting, @unchecked Sendable {
  enum Redireccion {
    case destino(String)
    case error(Error)
  }

  private let redireccion: Redireccion
  private let respuesta: String

  private(set) var camposEnviados: [[String: String]] = []
  private(set) var npssoRecibido: String?
  private(set) var autorizacionRecibida: String?

  init(
    redirigeA destino: String = "com.scee.psxandroid.scecompcall://redirect?code=v3.CODIGO",
    responde json: String = ""
  ) {
    self.redireccion = .destino(destino)
    self.respuesta = json
  }

  init(falla error: Error) {
    self.redireccion = .error(error)
    self.respuesta = ""
  }

  func redirectLocation(for url: URL, npsso: String) async throws -> URL {
    npssoRecibido = npsso
    switch redireccion {
    case .error(let error): throw error
    case .destino(let destino):
      guard let url = URL(string: destino) else { throw NetworkError.invalidResponse }
      return url
    }
  }

  func postForm(_ campos: [String: String], to url: URL, authorization: String) async throws -> Data {
    camposEnviados.append(campos)
    autorizacionRecibida = authorization
    return Data(respuesta.utf8)
  }
}

private let tokensValidos = """
  {"access_token":"ACCESO","refresh_token":"REFRESCO","expires_in":3600}
  """

@Suite("PSN: leer la redireccion")
struct PSNRedirectTests {

  @Test("Saca el codigo de la redireccion")
  func codigoValido() throws {
    let destino = try #require(URL(string: "com.scee.psxandroid.scecompcall://redirect?code=v3.ABC123"))

    #expect(try PSNAuthService.extraerCodigo(de: destino) == "v3.ABC123")
  }

  @Test("Un NPSSO caducado se reconoce por login_required")
  func tokenCaducado() throws {
    // Es lo que responde Sony de verdad: redirige a la pantalla de login con
    // error=login_required y error_code=4165.
    let destino = try #require(URL(
      string: "https://my.account.sony.com/sonyacct/signin/?error=login_required&error_code=4165"
    ))

    #expect(throws: PSNAuthError.npssoInvalido) {
      try PSNAuthService.extraerCodigo(de: destino)
    }
  }

  @Test("Otro error no se confunde con un token caducado")
  func otroError() throws {
    let destino = try #require(URL(string: "https://example.com/?error=server_error"))

    let error = #expect(throws: PSNAuthError.self) {
      try PSNAuthService.extraerCodigo(de: destino)
    }

    #expect(error != .npssoInvalido, "Decirle al usuario que copie otro codigo no arreglaria esto")
  }

  @Test("Una redireccion sin codigo ni error no se da por buena")
  func redireccionVacia() throws {
    let destino = try #require(URL(string: "https://example.com/"))

    #expect(throws: PSNAuthError.self) {
      try PSNAuthService.extraerCodigo(de: destino)
    }
  }
}

@Suite("PSN: iniciar sesion")
struct PSNSignInTests {

  @Test("Con un codigo valido devuelve credenciales")
  func inicioCorrecto() async throws {
    let transporte = StubPSNTransport(responde: tokensValidos)
    let ahora = Date(timeIntervalSince1970: 1_000_000)
    let servicio = PSNAuthService(transport: transporte, ahora: { ahora })

    let credenciales = try await servicio.signIn(npsso: "MI_TOKEN")

    #expect(credenciales.accessToken == "ACCESO")
    #expect(credenciales.refreshToken == "REFRESCO")
    #expect(credenciales.expiresAt == ahora.addingTimeInterval(3600))
    #expect(transporte.npssoRecibido == "MI_TOKEN")
  }

  @Test("Se recortan los espacios que se cuelan al pegar")
  func recortaEspacios() async throws {
    let transporte = StubPSNTransport(responde: tokensValidos)

    _ = try await PSNAuthService(transport: transporte).signIn(npsso: "  MI_TOKEN\n")

    #expect(transporte.npssoRecibido == "MI_TOKEN")
  }

  @Test("Un codigo vacio no llega ni a pedir")
  func codigoVacio() async {
    let transporte = StubPSNTransport(responde: tokensValidos)

    await #expect(throws: PSNAuthError.npssoInvalido) {
      try await PSNAuthService(transport: transporte).signIn(npsso: "   ")
    }
    #expect(transporte.npssoRecibido == nil)
  }

  @Test("Manda los campos del formulario que espera Sony")
  func camposDelFormulario() async throws {
    let transporte = StubPSNTransport(responde: tokensValidos)

    _ = try await PSNAuthService(transport: transporte).signIn(npsso: "X")

    let campos = try #require(transporte.camposEnviados.first)
    #expect(campos["grant_type"] == "authorization_code")
    #expect(campos["code"] == "v3.CODIGO")
    #expect(campos["redirect_uri"] == PSNAuthService.redirectURI)
    #expect(transporte.autorizacionRecibida?.hasPrefix("Basic ") == true)
  }

  @Test("Un error de Sony se traduce a algo accionable")
  func errorDeSony() async {
    // Es la respuesta real cuando el codigo ya no sirve.
    let transporte = StubPSNTransport(
      responde: #"{"error":"invalid_grant","error_description":"Invalid authorization code","error_code":4650}"#
    )

    await #expect(throws: PSNAuthError.npssoInvalido) {
      try await PSNAuthService(transport: transporte).signIn(npsso: "X")
    }
  }

  @Test("Una respuesta incompleta no se toma por buena")
  func respuestaIncompleta() async {
    // Sin refresh_token no se podria renovar nunca: mejor fallar ahora.
    let transporte = StubPSNTransport(responde: #"{"access_token":"SOLO_ESTE"}"#)

    await #expect(throws: PSNAuthError.self) {
      try await PSNAuthService(transport: transporte).signIn(npsso: "X")
    }
  }
}

@Suite("PSN: renovar la sesion")
struct PSNRefreshTests {

  @Test("Renueva con el refresh token")
  func renovacion() async throws {
    let transporte = StubPSNTransport(responde: tokensValidos)

    let credenciales = try await PSNAuthService(transport: transporte).refresh(using: "VIEJO")

    #expect(credenciales.accessToken == "ACCESO")

    let campos = try #require(transporte.camposEnviados.first)
    #expect(campos["grant_type"] == "refresh_token")
    #expect(campos["refresh_token"] == "VIEJO")
  }

  @Test("Un refresh token muerto pide volver a empezar")
  func refrescoMuerto() async {
    // Respuesta real al mandar un refresh_token invalido.
    let transporte = StubPSNTransport(
      responde: #"{"error":"invalid_request","error_description":"Invalid request","error_code":4150}"#
    )

    let error = await #expect(throws: PSNAuthError.self) {
      try await PSNAuthService(transport: transporte).refresh(using: "MUERTO")
    }

    #expect(error == .sesionExpirada)
    #expect(error?.necesitaTokenNuevo == true)
  }

  @Test("Sin expires_in se asume una hora en vez de tratarlo como eterno")
  func sinDuracion() async throws {
    let transporte = StubPSNTransport(responde: #"{"access_token":"A","refresh_token":"R"}"#)
    let ahora = Date(timeIntervalSince1970: 500)

    let credenciales = try await PSNAuthService(transport: transporte, ahora: { ahora })
      .refresh(using: "X")

    #expect(credenciales.expiresAt == ahora.addingTimeInterval(3600))
  }
}

@Suite("PSN: vencimiento del token")
struct PSNExpiryTests {

  private func credenciales(venceEn segundos: TimeInterval) -> PSNCredentials {
    PSNCredentials(
      accessToken: "A",
      refreshToken: "R",
      expiresAt: Date(timeIntervalSince1970: 1000 + segundos)
    )
  }

  private let ahora = Date(timeIntervalSince1970: 1000)

  @Test("Un token con tiempo de sobra vale")
  func vigente() {
    #expect(!credenciales(venceEn: 3600).isExpired(at: ahora))
  }

  @Test("Un token vencido no vale")
  func vencido() {
    #expect(credenciales(venceEn: -1).isExpired(at: ahora))
  }

  @Test("Un token a punto de vencer se trata como vencido")
  func casiVencido() {
    // Con el margen de un minuto se evita el 401 de un token que expira
    // mientras la peticion va en camino.
    #expect(credenciales(venceEn: 30).isExpired(at: ahora))
    #expect(!credenciales(venceEn: 120).isExpired(at: ahora))
  }
}

@Suite("PSN: mensajes de error")
struct PSNErrorMessageTests {

  @Test("Todos los errores dicen que pasa")
  func todosTienenMensaje() {
    let casos: [PSNAuthError] = [
      .npssoInvalido, .sesionExpirada, .sinCredenciales, .respuestaInesperada("x")
    ]

    for caso in casos {
      #expect(caso.errorDescription?.isEmpty == false, "Falta mensaje en \(caso)")
    }
  }

  @Test("Los que se arreglan copiando otro codigo lo dicen")
  func sugerencias() {
    #expect(PSNAuthError.npssoInvalido.recoverySuggestion?.isEmpty == false)
    #expect(PSNAuthError.sesionExpirada.recoverySuggestion?.isEmpty == false)

    // Este no se arregla haciendo nada distinto, y sugerir algo seria enganar.
    #expect(PSNAuthError.respuestaInesperada("x").recoverySuggestion == nil)
  }

  @Test("Solo los de credenciales piden un token nuevo")
  func cualesPidenTokenNuevo() {
    #expect(PSNAuthError.npssoInvalido.necesitaTokenNuevo)
    #expect(PSNAuthError.sesionExpirada.necesitaTokenNuevo)
    #expect(PSNAuthError.sinCredenciales.necesitaTokenNuevo)

    // Que Sony conteste raro no significa que el token del usuario este mal.
    #expect(!PSNAuthError.respuestaInesperada("x").necesitaTokenNuevo)
  }
}

@Suite("PSN: codificar el formulario")
struct PSNFormTests {

  @Test("Escapa los caracteres que romperian el cuerpo")
  func escapa() throws {
    let datos = PSNAuthTransport.formulario(["redirect_uri": "com.scee://redirect", "b": "a b&c=d"])
    let texto = try #require(String(data: datos, encoding: .utf8))

    #expect(texto.contains("com.scee%3A%2F%2Fredirect"))
    #expect(texto.contains("a%20b%26c%3Dd"))
    #expect(!texto.contains("a b"))
  }

  @Test("Las claves salen ordenadas, para que el cuerpo sea predecible")
  func ordenado() throws {
    let datos = PSNAuthTransport.formulario(["z": "1", "a": "2", "m": "3"])
    let texto = try #require(String(data: datos, encoding: .utf8))

    #expect(texto == "a=2&m=3&z=1")
  }
}
