//
//  XboxAuthService.swift
//  GameShelf
//

import Foundation

/// Inicia y mantiene la sesion con Xbox Live.
///
/// **Es una API no oficial** para apps de terceros: Microsoft no ofrece un
/// client publico como el que PSN y Epic filtran de sus propias apps moviles,
/// asi que cada usuario tiene que registrar su propia app en Azure y usar su
/// client id y client secret. Todo lo que sabe de la forma de la API vive
/// detras de este protocolo.
///
/// El canje son tres pasos encadenados, documentados por proyectos abiertos
/// como OpenXbox/xbox-webapi (no por Microsoft): el codigo se cambia por un
/// token de Microsoft, ese por un "user token" de Xbox Live, y ese por el
/// XSTS que de verdad se usa en cada peticion.
protocol XboxAuthenticating: Sendable {
  /// Canjea el codigo que el usuario copio del navegador.
  ///
  /// - Throws: `XboxAuthError.codigoInvalido` si el codigo no sirve,
  ///   `.credencialesDeAppInvalidas` si el client id o el secret no sirven.
  func signIn(authorizationCode: String, clientID: String, clientSecret: String) async throws -> XboxCredentials

  /// Rehace toda la cadena con el refresh token de Microsoft.
  ///
  /// - Throws: `XboxAuthError.sesionExpirada` si el refresh token ya no sirve.
  func refresh(using credentials: XboxCredentials) async throws -> XboxCredentials
}

/// Implementacion real contra login.live.com y xboxlive.com.
struct XboxAuthService: XboxAuthenticating {

  static let scope = "Xboxlive.signin Xboxlive.offline_access"

  /// Tiene que coincidir con el que el usuario registro en Azure como
  /// Redirect URI de tipo "Web". No es un esquema de la app: Microsoft no
  /// acepta parametros de consulta en el redirect de cuentas personales, y un
  /// esquema propio los llevaria igual. Por eso el usuario copia el codigo a
  /// mano de la barra de direcciones, en vez de que la app lo reciba sola.
  static let redirectURI = "http://localhost/auth/callback"

  static let authorizeBaseURL = URL(string: "https://login.live.com/oauth20_authorize.srf")!
  static let tokenURL = URL(string: "https://login.live.com/oauth20_token.srf")!
  static let userTokenURL = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
  static let xstsURL = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!

  /// Donde el usuario inicia sesion y autoriza la app, con su propio client id.
  static func authorizeURL(clientID: String) -> URL? {
    guard var componentes = URLComponents(url: authorizeBaseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    componentes.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "approval_prompt", value: "auto"),
      URLQueryItem(name: "scope", value: scope),
      URLQueryItem(name: "redirect_uri", value: redirectURI)
    ]
    return componentes.url
  }

  private let transport: XboxAuthTransporting
  private let ahora: @Sendable () -> Date

  init(transport: XboxAuthTransporting = XboxAuthTransport(), ahora: @escaping @Sendable () -> Date = Date.init) {
    self.transport = transport
    self.ahora = ahora
  }

  func signIn(authorizationCode: String, clientID: String, clientSecret: String) async throws -> XboxCredentials {
    let codigo = authorizationCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !codigo.isEmpty else { throw XboxAuthError.codigoInvalido }

    let (id, secreto) = try Self.credencialesDeApp(clientID, clientSecret)

    let microsoft = try await microsoftToken(
      campos: [
        "grant_type": "authorization_code",
        "code": codigo,
        "scope": Self.scope,
        "redirect_uri": Self.redirectURI
      ],
      clientID: id,
      clientSecret: secreto,
      errorSiFalla: .codigoInvalido
    )

    return try await xboxCredentials(desde: microsoft, clientID: id, clientSecret: secreto)
  }

  func refresh(using credentials: XboxCredentials) async throws -> XboxCredentials {
    let microsoft = try await microsoftToken(
      campos: [
        "grant_type": "refresh_token",
        "refresh_token": credentials.microsoftRefreshToken,
        "scope": Self.scope
      ],
      clientID: credentials.clientID,
      clientSecret: credentials.clientSecret,
      errorSiFalla: .sesionExpirada
    )

    return try await xboxCredentials(
      desde: microsoft,
      clientID: credentials.clientID,
      clientSecret: credentials.clientSecret
    )
  }

  private static func credencialesDeApp(_ clientID: String, _ clientSecret: String) throws -> (String, String) {
    let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    let secreto = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty, !secreto.isEmpty else { throw XboxAuthError.sinCredencialesDeApp }
    return (id, secreto)
  }

  // MARK: - Paso 1: codigo o refresh token por un token de Microsoft

  private func microsoftToken(
    campos: [String: String],
    clientID: String,
    clientSecret: String,
    errorSiFalla: XboxAuthError
  ) async throws -> MicrosoftTokenResponse {
    var todos = campos
    todos["client_id"] = clientID
    todos["client_secret"] = clientSecret

    let datos = try await transport.postForm(todos, to: Self.tokenURL)
    let decodificador = JSONDecoder()

    if let respuesta = try? decodificador.decode(MicrosoftTokenResponse.self, from: datos),
       let acceso = respuesta.accessToken, !acceso.isEmpty {
      return respuesta
    }

    // Formato estandar de OAuth2 (RFC 6749): invalid_client es la app,
    // invalid_grant es el codigo o el refresh token. No se pudo comprobar
    // contra la API real como con PSN y Epic -- hace falta una app de Azure
    // registrada para llegar hasta aca -- asi que esto sigue el estandar en
    // vez de un caso ya visto.
    if let error = try? decodificador.decode(MicrosoftErrorResponse.self, from: datos), let codigo = error.error {
      switch codigo {
      case "invalid_client":
        throw XboxAuthError.credencialesDeAppInvalidas
      case "invalid_grant":
        throw errorSiFalla
      default:
        throw XboxAuthError.respuestaInesperada(error.errorDescription ?? codigo)
      }
    }

    throw XboxAuthError.respuestaInesperada("No se entendio la respuesta")
  }

  // MARK: - Pasos 2 y 3: token de usuario y XSTS

  private func xboxCredentials(
    desde microsoft: MicrosoftTokenResponse,
    clientID: String,
    clientSecret: String
  ) async throws -> XboxCredentials {
    guard let accessToken = microsoft.accessToken, let refreshToken = microsoft.refreshToken else {
      throw XboxAuthError.respuestaInesperada("Microsoft no devolvio los tokens esperados")
    }

    let tokenDeUsuario = try await xboxToken(
      XboxUserTokenRequest(rpsTicket: "d=\(accessToken)"),
      to: Self.userTokenURL
    )

    let xsts = try await xboxToken(
      XboxXSTSRequest(userToken: tokenDeUsuario.token),
      to: Self.xstsURL
    )

    guard let claims = xsts.displayClaims.xui.first, let userHash = claims["uhs"] else {
      throw XboxAuthError.respuestaInesperada("La respuesta de Xbox Live no traia el user hash")
    }
    guard let vence = xsts.notAfter else {
      throw XboxAuthError.respuestaInesperada("La respuesta de Xbox Live no traia una fecha de vencimiento valida")
    }

    return XboxCredentials(
      clientID: clientID,
      clientSecret: clientSecret,
      microsoftRefreshToken: refreshToken,
      xstsToken: xsts.token,
      userHash: userHash,
      expiresAt: vence,
      xuid: claims["xid"],
      gamertag: claims["gtg"]
    )
  }

  private func xboxToken<Body: Encodable>(_ body: Body, to url: URL) async throws -> XboxTokenResponse {
    let datos: Data
    do {
      datos = try JSONEncoder().encode(body)
    } catch {
      throw XboxAuthError.respuestaInesperada("No se pudo armar la peticion")
    }

    let respuesta = try await transport.postXboxJSON(datos, to: url)

    guard let decodificada = try? JSONDecoder().decode(XboxTokenResponse.self, from: respuesta) else {
      throw XboxAuthError.respuestaInesperada("Xbox Live rechazo la peticion")
    }
    return decodificada
  }
}

// MARK: - Respuestas de login.live.com

private struct MicrosoftTokenResponse: Decodable {
  let accessToken: String?
  let refreshToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
  }
}

private struct MicrosoftErrorResponse: Decodable {
  let error: String?
  let errorDescription: String?

  enum CodingKeys: String, CodingKey {
    case error
    case errorDescription = "error_description"
  }
}

// MARK: - Respuestas de user.auth.xboxlive.com y xsts.auth.xboxlive.com

/// Misma forma para el token de usuario y para el XSTS.
private struct XboxTokenResponse: Decodable {
  let token: String
  private let notAfterRaw: String
  let displayClaims: DisplayClaims

  struct DisplayClaims: Decodable {
    let xui: [[String: String]]
  }

  enum CodingKeys: String, CodingKey {
    case token = "Token"
    case notAfterRaw = "NotAfter"
    case displayClaims = "DisplayClaims"
  }

  /// Xbox manda mas digitos de fraccion de los que admite
  /// `ISO8601DateFormatter` (`"2999-10-24T03:04:29.6037497Z"`). Solo importa
  /// la parte entera: la app nunca decide nada con precision de microsegundos.
  var notAfter: Date? {
    let sinFraccion = notAfterRaw.split(separator: ".").first.map(String.init) ?? notAfterRaw
    return ISO8601DateFormatter().date(from: sinFraccion + "Z")
  }
}

private struct XboxUserTokenRequest: Encodable {
  let relyingParty = "http://auth.xboxlive.com"
  let tokenType = "JWT"
  let properties: XboxUserTokenProperties

  init(rpsTicket: String) {
    properties = XboxUserTokenProperties(authMethod: "RPS", siteName: "user.auth.xboxlive.com", rpsTicket: rpsTicket)
  }

  enum CodingKeys: String, CodingKey {
    case relyingParty = "RelyingParty"
    case tokenType = "TokenType"
    case properties = "Properties"
  }
}

private struct XboxUserTokenProperties: Encodable {
  let authMethod: String
  let siteName: String
  let rpsTicket: String

  enum CodingKeys: String, CodingKey {
    case authMethod = "AuthMethod"
    case siteName = "SiteName"
    case rpsTicket = "RpsTicket"
  }
}

private struct XboxXSTSRequest: Encodable {
  let relyingParty = "http://xboxlive.com"
  let tokenType = "JWT"
  let properties: XboxXSTSProperties

  init(userToken: String) {
    properties = XboxXSTSProperties(userTokens: [userToken], sandboxId: "RETAIL")
  }

  enum CodingKeys: String, CodingKey {
    case relyingParty = "RelyingParty"
    case tokenType = "TokenType"
    case properties = "Properties"
  }
}

private struct XboxXSTSProperties: Encodable {
  let userTokens: [String]
  let sandboxId: String

  enum CodingKeys: String, CodingKey {
    case userTokens = "UserTokens"
    case sandboxId = "SandboxId"
  }
}
