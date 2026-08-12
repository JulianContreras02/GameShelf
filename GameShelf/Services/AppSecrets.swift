//
//  AppSecrets.swift
//  GameShelf
//

import Foundation

/// Acceso a las claves de API que la app necesita.
///
/// Los valores no viven en el codigo: entran por `Config/Secrets.xcconfig`
/// (ignorado por git), pasan al Info.plist como variables de build y se leen
/// aca en tiempo de ejecucion.
///
/// Ver `docs/decisiones/002-gestion-de-secretos.md` para el porque.
enum AppSecrets {

  /// Claves disponibles, con el nombre exacto que tienen en el Info.plist.
  enum Key: String, CaseIterable {
    case steamAPIKey = "SteamAPIKey"
    case steamID = "SteamID"
    case itadAPIKey = "ITADAPIKey"

    /// Nombre de la variable en el archivo `.xcconfig`, para poder decirle al
    /// usuario exactamente que linea le falta.
    var xcconfigName: String {
      switch self {
      case .steamAPIKey: "STEAM_API_KEY"
      case .steamID: "STEAM_ID"
      case .itadAPIKey: "ITAD_API_KEY"
      }
    }
  }

  /// Error con un mensaje accionable, para mostrarlo en pantalla en vez de
  /// dejar que la app se caiga.
  struct MissingSecretError: LocalizedError, Equatable {
    let key: Key

    var errorDescription: String? {
      String(localized: "Falta la clave \(key.xcconfigName).", comment: "Falta un secreto de configuracion")
    }

    var recoverySuggestion: String? {
      String(
        localized: """
          Copia Config/Secrets.example.xcconfig a Config/Secrets.xcconfig y \
          escribe el valor de \(key.xcconfigName). Las instrucciones estan en el \
          README.
          """,
        comment: "Como configurar un secreto que falta"
      )
    }
  }

  /// Devuelve el valor de una clave, o lanza `MissingSecretError` si no esta.
  ///
  /// - Parameters:
  ///   - key: La clave a leer.
  ///   - bundle: Bundle de donde leer. Se puede inyectar otro en las pruebas.
  static func value(for key: Key, in bundle: Bundle = .main) throws -> String {
    guard let raw = bundle.object(forInfoDictionaryKey: key.rawValue) as? String else {
      throw MissingSecretError(key: key)
    }

    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw MissingSecretError(key: key)
    }

    return trimmed
  }

  /// Claves que faltan o estan vacias. Sirve para avisar al arrancar, antes de
  /// que el usuario se tope con un error a mitad de una pantalla.
  static func missingKeys(in bundle: Bundle = .main) -> [Key] {
    Key.allCases.filter { key in
      (try? value(for: key, in: bundle)) == nil
    }
  }
}
