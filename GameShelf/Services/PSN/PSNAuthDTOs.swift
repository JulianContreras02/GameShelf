//
//  PSNAuthDTOs.swift
//  GameShelf
//

import Foundation

/// Respuesta buena del endpoint de tokens.
struct PSNTokenResponse: Decodable, Sendable {
  let accessToken: String?
  let refreshToken: String?

  /// Segundos que le quedan de vida al token de acceso. Suele ser 3600.
  let expiresIn: Int?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case expiresIn = "expires_in"
  }

  /// Convierte la respuesta en credenciales, o `nil` si venia incompleta.
  ///
  /// Se pide la hora en vez de leerla aca para que las pruebas puedan fijarla.
  func credentials(ahora: Date) -> PSNCredentials? {
    guard let accessToken, !accessToken.isEmpty,
          let refreshToken, !refreshToken.isEmpty
    else { return nil }

    // Sin expires_in se asume una hora, que es lo que Sony devuelve siempre.
    // Es preferible a tratar el token como eterno.
    let duracion = TimeInterval(expiresIn ?? 3600)

    return PSNCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: ahora.addingTimeInterval(duracion)
    )
  }
}

/// Respuesta de error del endpoint de tokens.
///
/// Forma real, comprobada contra la API:
/// ```json
/// { "error": "invalid_grant",
///   "error_description": "Invalid authorization code",
///   "error_code": 4650 }
/// ```
struct PSNErrorResponse: Decodable, Sendable {
  let error: String?
  let errorDescription: String?
  let errorCode: Int?

  enum CodingKeys: String, CodingKey {
    case error
    case errorDescription = "error_description"
    case errorCode = "error_code"
  }

  /// Codigos que significan "lo que mandaste ya no sirve".
  ///
  /// Son los que se comprobaron pidiendo con datos invalidos:
  /// - `4650` codigo de autorizacion invalido
  /// - `4150` peticion invalida (sale con un refresh token que ya no vale)
  /// - `4165` el usuario no esta autenticado (el NPSSO caduco)
  static let codigosDeCredencialInvalida: Set<Int> = [4650, 4150, 4165]

  var esDeCredencialesInvalidas: Bool {
    if let errorCode, Self.codigosDeCredencialInvalida.contains(errorCode) { return true }
    return error == "invalid_grant" || error == "invalid_request"
  }

  var descripcion: String {
    errorDescription ?? error ?? "sin detalle"
  }
}
