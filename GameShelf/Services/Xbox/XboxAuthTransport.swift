//
//  XboxAuthTransport.swift
//  GameShelf
//

import Foundation

/// Lo que hace falta para hablar con los tres servicios del inicio de sesion
/// de Xbox: login.live.com (formulario) y user.auth/xsts.auth.xboxlive.com
/// (JSON con cabecera propia).
///
/// No se reusa `FormPostTransporting` de PSN/Epic porque ese manda las
/// credenciales en la cabecera `Authorization: Basic`, y aca van dentro del
/// propio formulario. Tampoco `HTTPClient`, que no permite cabeceras propias
/// en un POST.
protocol XboxAuthTransporting: Sendable {
  /// Manda un formulario `application/x-www-form-urlencoded` y devuelve la
  /// respuesta cruda.
  func postForm(_ campos: [String: String], to url: URL) async throws -> Data

  /// Manda `body` como JSON, con la cabecera que pide Xbox Live, y devuelve la
  /// respuesta cruda.
  func postXboxJSON(_ body: Data, to url: URL) async throws -> Data
}

/// Implementacion real sobre `URLSession`.
struct XboxAuthTransport: XboxAuthTransporting {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func postForm(_ campos: [String: String], to url: URL) async throws -> Data {
    var peticion = URLRequest(url: url)
    peticion.httpMethod = "POST"
    peticion.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    peticion.httpBody = Self.formulario(campos)

    return try await enviar(peticion)
  }

  func postXboxJSON(_ body: Data, to url: URL) async throws -> Data {
    var peticion = URLRequest(url: url)
    peticion.httpMethod = "POST"
    peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
    peticion.setValue("1", forHTTPHeaderField: "x-xbl-contract-version")
    peticion.httpBody = body

    return try await enviar(peticion)
  }

  /// Codifica el formulario. Igual que en `PSNAuthTransport`: claves
  /// ordenadas para que las pruebas puedan comparar el cuerpo.
  static func formulario(_ campos: [String: String]) -> Data {
    let permitidos = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz"
      + "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    let texto = campos.keys.sorted().map { clave in
      let valor = campos[clave] ?? ""
      let escapado = valor.addingPercentEncoding(withAllowedCharacters: permitidos) ?? valor
      return "\(clave)=\(escapado)"
    }.joined(separator: "&")

    return Data(texto.utf8)
  }

  private func enviar(_ peticion: URLRequest) async throws -> Data {
    do {
      let (datos, _) = try await session.data(for: peticion)
      return datos
    } catch let error as URLError {
      let sinRed: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed
      ]
      throw sinRed.contains(error.code) ? NetworkError.noConnection : NetworkError.invalidResponse
    }
  }
}
