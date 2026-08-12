//
//  EpicCredentials.swift
//  GameShelf
//

import Foundation

/// Lo que hace falta para hablar con Epic en nombre del usuario.
struct EpicCredentials: Sendable, Equatable {
  let accessToken: String
  let refreshToken: String

  /// Cuando deja de servir el token de acceso. Epic da unas ocho horas.
  let expiresAt: Date

  /// Cuando deja de servir el de refresco. Epic si manda este dato.
  var refreshExpiresAt: Date?

  /// Identificador de la cuenta, que hace falta para pedir la biblioteca.
  var accountID: String?

  /// Nombre visible de la cuenta. Solo para mostrarlo.
  var displayName: String?

  /// Si el token de acceso ya no sirve, o le queda muy poco.
  ///
  /// Se adelanta un minuto, igual que en PSN: pedir con un token que expira
  /// mientras la peticion va en camino da un 401 evitable.
  func isExpired(at fecha: Date = Date(), margen: TimeInterval = 60) -> Bool {
    fecha.addingTimeInterval(margen) >= expiresAt
  }
}

/// Por que fallo la autenticacion con Epic.
///
/// Los codigos vienen de la respuesta real y se comprobaron contra la API.
enum EpicAuthError: LocalizedError, Equatable {
  /// El codigo no existe o ya se uso. Duran muy poco.
  case codigoInvalido

  /// El refresh token ya no sirve: toca copiar un codigo nuevo.
  case sesionExpirada

  /// Epic respondio algo que no se esperaba.
  case respuestaInesperada(String)

  /// No hay credenciales guardadas todavia.
  case sinCredenciales

  var errorDescription: String? {
    switch self {
    case .codigoInvalido:
      String(
        localized: "El codigo de Epic no sirve o ya se uso.",
        comment: "Error de autenticacion con Epic"
      )
    case .sesionExpirada:
      String(localized: "La sesion de Epic caduco.", comment: "Error de autenticacion con Epic")
    case .respuestaInesperada(let detalle):
      String(
        localized: "Epic respondio algo inesperado: \(detalle)",
        comment: "Error de autenticacion con Epic"
      )
    case .sinCredenciales:
      String(
        localized: "Todavia no has conectado tu cuenta de Epic.",
        comment: "Error de autenticacion con Epic"
      )
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .codigoInvalido:
      // Los codigos de Epic caducan en segundos: lo mas comun es tardar entre
      // copiarlo y pegarlo, no que este mal escrito.
      String(
        localized: "Los codigos caducan enseguida. Genera uno nuevo y pegalo sin demorarte.",
        comment: "Como recuperarse de un codigo de Epic invalido"
      )
    case .sesionExpirada:
      String(
        localized: "Vuelve a generar el codigo desde el navegador y pegalo aca.",
        comment: "Como recuperarse de una sesion de Epic caducada"
      )
    case .sinCredenciales:
      String(localized: "Conecta tu cuenta desde Ajustes.", comment: "Como conectar PSN")
    case .respuestaInesperada:
      nil
    }
  }

  /// Si la unica salida es que el usuario genere un codigo nuevo.
  var necesitaCodigoNuevo: Bool {
    self == .codigoInvalido || self == .sesionExpirada || self == .sinCredenciales
  }
}
