//
//  EpicAuthService.swift
//  GameShelf
//

import Foundation

/// Respuesta buena del endpoint de tokens de Epic.
struct EpicTokenResponse: Decodable, Sendable {
  let accessToken: String?
  let refreshToken: String?
  let expiresIn: Int?
  let refreshExpires: Int?
  let accountId: String?
  let displayName: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case expiresIn = "expires_in"
    case refreshExpires = "refresh_expires"
    case accountId = "account_id"
    case displayName
  }

  /// Convierte la respuesta en credenciales, o `nil` si venia incompleta.
  func credentials(ahora: Date) -> EpicCredentials? {
    guard let accessToken, !accessToken.isEmpty,
          let refreshToken, !refreshToken.isEmpty
    else { return nil }

    return EpicCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      // Epic da unas ocho horas; si no lo dice, se asume eso en vez de tratar
      // el token como eterno.
      expiresAt: ahora.addingTimeInterval(TimeInterval(expiresIn ?? 28_800)),
      refreshExpiresAt: refreshExpires.map { ahora.addingTimeInterval(TimeInterval($0)) },
      accountID: accountId,
      displayName: displayName
    )
  }
}

/// Respuesta de error de Epic.
///
/// Forma real, comprobada contra la API:
/// ```json
/// { "errorCode": "errors.com.epicgames.account.oauth.authorization_code_not_found",
///   "numericErrorCode": 18059 }
/// ```
struct EpicErrorResponse: Decodable, Sendable {
  let errorCode: String?
  let errorMessage: String?
  let numericErrorCode: Int?

  /// Codigos que significan "lo que mandaste ya no sirve", comprobados
  /// pidiendo con datos invalidos:
  /// - `18059` el codigo de autorizacion no existe o ya se uso
  /// - `18036` el refresh token no vale
  static let codigosDeCredencialInvalida: Set<Int> = [18059, 18036]

  var esDeCredencialesInvalidas: Bool {
    if let numericErrorCode, Self.codigosDeCredencialInvalida.contains(numericErrorCode) {
      return true
    }
    return errorCode?.contains("authorization_code") == true
      || errorCode?.contains("refresh_token") == true
  }

  var descripcion: String {
    errorMessage ?? errorCode ?? "sin detalle"
  }
}

/// Inicia y mantiene la sesion con Epic Games.
///
/// **API no oficial**, y la mas fragil de las tres: Epic no publica un flujo
/// para apps de terceros. Todo lo que sabe de su forma vive detras de este
/// protocolo.
protocol EpicAuthenticating: Sendable {
  /// Canjea el codigo que el usuario copio del navegador.
  func signIn(authorizationCode: String) async throws -> EpicCredentials

  /// Pide credenciales nuevas con el token de refresco.
  func refresh(using refreshToken: String) async throws -> EpicCredentials
}

/// Implementacion real contra los endpoints de Epic.
struct EpicAuthService: EpicAuthenticating {

  /// Credenciales del launcher de Epic.
  ///
  /// No son secretas ni del usuario: van dentro del launcher, se pueden sacar
  /// de el y las usan todas las herramientas abiertas del ecosistema. Van aca
  /// por lo mismo que las de PSN: no hay nada que proteger.
  static let clientID = "34a02cf8f4414e29b15921876da36f9a"
  static let clientSecret = "daafbccc737745039dffe53d94fc76cf"

  static var tokenURL: URL {
    url("https://account-public-service-prod.ol.epicgames.com/account/api/oauth/token")
  }

  /// Donde el usuario ve su codigo, si ya inicio sesion.
  ///
  /// Sin sesion responde con `authorizationCode: null`, no con un error.
  static var codeURL: URL {
    url("https://www.epicgames.com/id/api/redirect?clientId=\(clientID)&responseType=code")
  }

  /// La pagina de login, que despues lleva al codigo.
  ///
  /// El destino va codificado: sin escaparlo, Epic corta la direccion en el
  /// primer "&" y el login no sabe a donde volver.
  static var loginURL: URL {
    let destino = codeURL.absoluteString
      .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? codeURL.absoluteString
    return url("https://www.epicgames.com/id/login?redirectUrl=\(destino)")
  }

  /// Arma una URL constante del servicio.
  ///
  /// Son direcciones fijas escritas en el codigo, no datos de fuera: si alguna
  /// dejara de ser valida seria un error de programacion, y las pruebas de
  /// `EpicURLTests` lo detectarian antes de llegar a nadie.
  private static func url(_ texto: String) -> URL {
    guard let url = URL(string: texto) else {
      preconditionFailure("Direccion de Epic mal escrita: \(texto)")
    }
    return url
  }

  private let transport: FormPostTransporting
  private let ahora: @Sendable () -> Date

  init(
    transport: FormPostTransporting = PSNAuthTransport(),
    ahora: @escaping @Sendable () -> Date = Date.init
  ) {
    self.transport = transport
    self.ahora = ahora
  }

  func signIn(authorizationCode: String) async throws -> EpicCredentials {
    let limpio = authorizationCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !limpio.isEmpty else { throw EpicAuthError.codigoInvalido }

    return try await tokens(campos: [
      "grant_type": "authorization_code",
      "code": limpio,
      "token_type": "eg1"
    ], errorSiFalla: .codigoInvalido)
  }

  func refresh(using refreshToken: String) async throws -> EpicCredentials {
    try await tokens(campos: [
      "grant_type": "refresh_token",
      "refresh_token": refreshToken,
      "token_type": "eg1"
    ], errorSiFalla: .sesionExpirada)
  }

  private func tokens(campos: [String: String], errorSiFalla: EpicAuthError) async throws -> EpicCredentials {
    let datos = try await transport.postForm(
      campos,
      to: Self.tokenURL,
      authorization: Self.basicAuthorization
    )

    let decodificador = JSONDecoder()

    if let respuesta = try? decodificador.decode(EpicTokenResponse.self, from: datos),
       let credenciales = respuesta.credentials(ahora: ahora()) {
      return credenciales
    }

    if let error = try? decodificador.decode(EpicErrorResponse.self, from: datos) {
      throw error.esDeCredencialesInvalidas ? errorSiFalla : EpicAuthError.respuestaInesperada(error.descripcion)
    }

    throw EpicAuthError.respuestaInesperada("No se entendio la respuesta")
  }

  /// La cabecera `Authorization: basic` con las credenciales del launcher.
  ///
  /// Epic la espera en minuscula. Con "Basic" tambien responde, pero se manda
  /// tal como lo hace su launcher para no depender de esa tolerancia.
  static var basicAuthorization: String {
    let par = "\(clientID):\(clientSecret)"
    return "basic \(Data(par.utf8).base64EncodedString())"
  }
}
