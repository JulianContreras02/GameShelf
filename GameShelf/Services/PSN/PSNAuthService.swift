//
//  PSNAuthService.swift
//  GameShelf
//

import Foundation

/// Inicia y mantiene la sesion con PlayStation Network.
///
/// **Es una API no oficial.** Sony no la documenta ni promete que siga
/// existiendo. Todo lo que sabe de su forma vive detras de este protocolo, para
/// que el dia que cambie el dano quede en un solo archivo.
protocol PSNAuthenticating: Sendable {
  /// Canjea el codigo que el usuario copio del navegador por credenciales.
  ///
  /// - Throws: `PSNAuthError.npssoInvalido` si el codigo no sirve o caduco.
  func signIn(npsso: String) async throws -> PSNCredentials

  /// Pide un token de acceso nuevo con el de refresco.
  ///
  /// - Throws: `PSNAuthError.sesionExpirada` si el refresco tampoco sirve ya.
  func refresh(using refreshToken: String) async throws -> PSNCredentials
}

/// Implementacion real contra los endpoints de Sony.
struct PSNAuthService: PSNAuthenticating {

  /// Credenciales de la app movil de PlayStation.
  ///
  /// No son secretas ni son del usuario: van dentro de la app de Sony, se
  /// pueden sacar de ella y las usan todas las librerias abiertas de PSN. Van
  /// aca y no en el archivo de secretos justamente por eso: no hay nada que
  /// proteger, y ponerlas en la configuracion sugeriria que cada quien tiene
  /// las suyas.
  static let clientID = "09515159-7237-4370-9b40-3806e67c0891"
  static let clientSecret = "ucPjka5tntB2KqsP"
  static let redirectURI = "com.scee.psxandroid.scecompcall://redirect"
  static let scope = "psn:mobile.v2.core psn:clientapp"

  static let authorizeURL = URL(string: "https://ca.account.sony.com/api/authz/v3/oauth/authorize")!
  static let tokenURL = URL(string: "https://ca.account.sony.com/api/authz/v3/oauth/token")!

  /// Donde el usuario ve su NPSSO. Se muestra en la pantalla de conexion.
  static let npssoURL = URL(string: "https://ca.account.sony.com/api/v1/ssocookie")!

  private let transport: PSNAuthTransporting
  private let ahora: @Sendable () -> Date

  init(transport: PSNAuthTransporting = PSNAuthTransport(), ahora: @escaping @Sendable () -> Date = Date.init) {
    self.transport = transport
    self.ahora = ahora
  }

  func signIn(npsso: String) async throws -> PSNCredentials {
    let limpio = npsso.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !limpio.isEmpty else { throw PSNAuthError.npssoInvalido }

    let codigo = try await authorizationCode(npsso: limpio)
    return try await tokens(campos: [
      "code": codigo,
      "redirect_uri": Self.redirectURI,
      "grant_type": "authorization_code",
      "token_format": "jwt"
    ], errorSiFalla: .npssoInvalido)
  }

  func refresh(using refreshToken: String) async throws -> PSNCredentials {
    try await tokens(campos: [
      "refresh_token": refreshToken,
      "grant_type": "refresh_token",
      "token_format": "jwt",
      "scope": Self.scope
    ], errorSiFalla: .sesionExpirada)
  }

  /// Primer paso: cambiar el NPSSO por un codigo de autorizacion.
  ///
  /// El codigo no viene en el cuerpo sino en la **redireccion**: Sony responde
  /// 302 hacia `com.scee.psxandroid.scecompcall://redirect?code=v3.xxx`. Si el
  /// NPSSO no sirve, redirige a la pantalla de login con
  /// `error=login_required`.
  func authorizationCode(npsso: String) async throws -> String {
    guard var componentes = URLComponents(url: Self.authorizeURL, resolvingAgainstBaseURL: false) else {
      throw NetworkError.invalidURL(Self.authorizeURL.absoluteString)
    }

    componentes.queryItems = [
      URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "client_id", value: Self.clientID),
      URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: Self.scope)
    ]

    guard let url = componentes.url else {
      throw NetworkError.invalidURL(Self.authorizeURL.absoluteString)
    }

    let destino = try await transport.redirectLocation(for: url, npsso: npsso)
    return try Self.extraerCodigo(de: destino)
  }

  /// Saca el `code` de la URL de redireccion.
  ///
  /// Se expone para poder probarlo sin red: es donde se decide si el token del
  /// usuario sirve o hay que pedirle uno nuevo.
  static func extraerCodigo(de destino: URL) throws -> String {
    let componentes = URLComponents(url: destino, resolvingAgainstBaseURL: false)
    let parametros = componentes?.queryItems ?? []

    if let codigo = parametros.first(where: { $0.name == "code" })?.value, !codigo.isEmpty {
      return codigo
    }

    // Sony manda a la pantalla de login con error=login_required (codigo 4165)
    // cuando el NPSSO caduco. Es el caso mas comun con diferencia.
    if let error = parametros.first(where: { $0.name == "error" })?.value {
      throw error == "login_required"
        ? PSNAuthError.npssoInvalido
        : PSNAuthError.respuestaInesperada(error)
    }

    throw PSNAuthError.respuestaInesperada("Redireccion sin codigo ni error")
  }

  /// Segundo paso: cambiar el codigo (o el refresco) por tokens.
  private func tokens(campos: [String: String], errorSiFalla: PSNAuthError) async throws -> PSNCredentials {
    let datos = try await transport.postForm(
      campos,
      to: Self.tokenURL,
      authorization: Self.basicAuthorization
    )

    let decodificador = JSONDecoder()

    if let respuesta = try? decodificador.decode(PSNTokenResponse.self, from: datos),
       let credenciales = respuesta.credentials(ahora: ahora()) {
      return credenciales
    }

    // Sony devuelve el motivo en el cuerpo, con 400. Se traduce a algo que el
    // usuario pueda accionar.
    if let error = try? decodificador.decode(PSNErrorResponse.self, from: datos) {
      throw error.esDeCredencialesInvalidas ? errorSiFalla : PSNAuthError.respuestaInesperada(error.descripcion)
    }

    throw PSNAuthError.respuestaInesperada("No se entendio la respuesta")
  }

  /// La cabecera `Authorization: Basic` con las credenciales de la app movil.
  static var basicAuthorization: String {
    let par = "\(clientID):\(clientSecret)"
    let codificado = Data(par.utf8).base64EncodedString()
    return "Basic \(codificado)"
  }
}
