//
//  PSNCredentials.swift
//  GameShelf
//

import Foundation

/// Lo que hace falta para hablar con PSN en nombre del usuario.
///
/// Son tres cosas con vidas muy distintas:
///
/// - El **NPSSO** lo copia el usuario del navegador y dura unos dos meses. Es
///   la unica pieza que no se puede renovar sola: cuando caduca hay que pedirle
///   que lo vuelva a copiar.
/// - El **access token** dura una hora y se usa en cada peticion.
/// - El **refresh token** dura unas semanas y sirve para pedir uno de acceso
///   nuevo sin molestar al usuario.
struct PSNCredentials: Sendable, Equatable {
  let accessToken: String
  let refreshToken: String

  /// Cuando deja de servir el token de acceso.
  let expiresAt: Date

  /// Si el token de acceso ya no sirve, o le queda muy poco.
  ///
  /// Se adelanta un minuto al vencimiento real: pedir con un token que expira
  /// mientras la peticion va en camino da un 401 que se puede evitar.
  func isExpired(at fecha: Date = Date(), margen: TimeInterval = 60) -> Bool {
    fecha.addingTimeInterval(margen) >= expiresAt
  }
}

/// Por que fallo la autenticacion con PSN.
///
/// Los codigos vienen de la respuesta de Sony y se comprobaron contra la API
/// real. Se traducen a mensajes que digan que hacer, porque "error 4165" no le
/// sirve a nadie.
enum PSNAuthError: LocalizedError, Equatable {
  /// El NPSSO caduco o esta mal copiado. Es el caso mas comun.
  case npssoInvalido

  /// El refresh token ya no sirve: toca volver a copiar el NPSSO.
  case sesionExpirada

  /// Sony respondio algo que no se esperaba.
  case respuestaInesperada(String)

  /// No hay credenciales guardadas todavia.
  case sinCredenciales

  var errorDescription: String? {
    switch self {
    case .npssoInvalido:
      String(
        localized: "El codigo de PlayStation no sirve o ya caduco.",
        comment: "Error de autenticacion con PSN"
      )
    case .sesionExpirada:
      String(
        localized: "La sesion de PlayStation caduco.",
        comment: "Error de autenticacion con PSN"
      )
    case .respuestaInesperada(let detalle):
      String(
        localized: "PlayStation respondio algo inesperado: \(detalle)",
        comment: "Error de autenticacion con PSN"
      )
    case .sinCredenciales:
      String(
        localized: "Todavia no has conectado tu cuenta de PlayStation.",
        comment: "Error de autenticacion con PSN"
      )
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .npssoInvalido, .sesionExpirada:
      String(
        localized: "Vuelve a copiar el codigo desde el navegador y pegalo aca.",
        comment: "Como recuperarse de un token de PSN caducado"
      )
    case .sinCredenciales:
      String(
        localized: "Conecta tu cuenta desde Ajustes.",
        comment: "Como conectar PSN"
      )
    case .respuestaInesperada:
      nil
    }
  }

  /// Si la unica salida es que el usuario copie un NPSSO nuevo.
  ///
  /// Sirve para que la interfaz decida entre reintentar sola o pedir ayuda.
  var necesitaTokenNuevo: Bool {
    self == .npssoInvalido || self == .sesionExpirada || self == .sinCredenciales
  }
}
