//
//  XboxCredentials.swift
//  GameShelf
//

import Foundation

/// Lo que hace falta para hablar con la API de Xbox Live en nombre del usuario.
///
/// A diferencia de PSN y Epic, aca hay dos identidades a la vez:
/// - La **app de Azure** (`clientID`/`clientSecret`) que el propio usuario
///   registro, porque Microsoft no ofrece un client publico para apps de
///   terceros como si hacen PSN y Epic con los suyos. Vive tanto tiempo como
///   la app siga registrada, y hace falta para poder renovar sin volver a
///   pedirsela.
/// - La **cadena de tokens** de Xbox Live: el refresh token de Microsoft
///   sirve para renovar toda la cadena (token de usuario y despues XSTS), sin
///   guardar el access token de Microsoft porque se consume enseguida.
struct XboxCredentials: Sendable, Equatable {
  let clientID: String
  let clientSecret: String

  /// El de Microsoft. Sirve para rehacer toda la cadena cuando el XSTS caduque.
  let microsoftRefreshToken: String

  /// El token que de verdad se manda en cada peticion a la API de Xbox Live.
  let xstsToken: String

  /// El "user hash" que acompaña al XSTS en la cabecera `Authorization`.
  let userHash: String

  /// Cuando deja de servir el XSTS. Microsoft da unas 16 horas.
  let expiresAt: Date

  let xuid: String?
  let gamertag: String?

  /// La cabecera `Authorization` tal como la pide Xbox Live: `XBL3.0 x=<uhs>;<token>`.
  var authorizationHeader: String {
    "XBL3.0 x=\(userHash);\(xstsToken)"
  }

  /// Si el XSTS ya no sirve, o le queda muy poco.
  ///
  /// Se adelanta un minuto, igual que en PSN y Epic: pedir con un token que
  /// expira mientras la peticion va en camino da un 401 evitable.
  func isExpired(at fecha: Date = Date(), margen: TimeInterval = 60) -> Bool {
    fecha.addingTimeInterval(margen) >= expiresAt
  }
}

/// Por que fallo la autenticacion con Xbox.
enum XboxAuthError: LocalizedError, Equatable {
  /// El codigo de autorizacion no sirve, ya se uso, o caduco.
  case codigoInvalido

  /// El refresh token de Microsoft ya no sirve: toca volver a copiar un codigo.
  case sesionExpirada

  /// El client id o el client secret de la app de Azure no sirven.
  case credencialesDeAppInvalidas

  /// Microsoft o Xbox Live respondieron algo que no se esperaba.
  case respuestaInesperada(String)

  /// No hay credenciales guardadas todavia.
  case sinCredenciales

  /// No hay client id ni client secret guardados: hace falta antes de conectar.
  case sinCredencialesDeApp

  var errorDescription: String? {
    switch self {
    case .codigoInvalido:
      String(localized: "El codigo de Xbox no sirve o ya caduco.", comment: "Error de autenticacion con Xbox")
    case .sesionExpirada:
      String(localized: "La sesion de Xbox caduco.", comment: "Error de autenticacion con Xbox")
    case .credencialesDeAppInvalidas:
      String(
        localized: "El client ID o el client secret de tu app de Azure no sirven.",
        comment: "Error de autenticacion con Xbox"
      )
    case .respuestaInesperada(let detalle):
      String(localized: "Xbox respondio algo inesperado: \(detalle)", comment: "Error de autenticacion con Xbox")
    case .sinCredenciales:
      String(localized: "Todavia no has conectado tu cuenta de Xbox.", comment: "Error de autenticacion con Xbox")
    case .sinCredencialesDeApp:
      String(
        localized: "Falta configurar tu app de Azure.",
        comment: "Error de autenticacion con Xbox: falta la app de Azure"
      )
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .codigoInvalido, .sesionExpirada:
      String(
        localized: "Vuelve a copiar el codigo desde el navegador y pegalo aca.",
        comment: "Como recuperarse de un codigo de Xbox caducado"
      )
    case .credencialesDeAppInvalidas:
      String(
        localized: "Revisa el client ID y el client secret en portal.azure.com y pegalos de nuevo.",
        comment: "Como resolver credenciales de app de Xbox invalidas"
      )
    case .sinCredenciales, .sinCredencialesDeApp:
      String(localized: "Conecta tu cuenta desde Ajustes.", comment: "Como conectar Xbox")
    case .respuestaInesperada:
      nil
    }
  }

  /// Si la unica salida es que el usuario copie un codigo nuevo.
  var necesitaCodigoNuevo: Bool {
    self == .codigoInvalido || self == .sesionExpirada || self == .sinCredenciales
  }
}
