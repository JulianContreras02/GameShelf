//
//  PSNAuthTransport.swift
//  GameShelf
//

import Foundation

/// Las dos peticiones raras que necesita el inicio de sesion de PSN.
///
/// No se reusa `HTTPClient` porque ninguna de las dos encaja: una necesita
/// **leer una redireccion sin seguirla** (ahi viene el codigo de autorizacion)
/// y la otra manda un formulario, no JSON.
protocol PSNAuthTransporting: Sendable {
  /// Pide `url` con la cookie del NPSSO y devuelve a donde redirige, **sin ir**.
  ///
  /// El codigo de autorizacion viaja en esa redireccion. Si se sigue, se pierde.
  func redirectLocation(for url: URL, npsso: String) async throws -> URL

  /// Manda un formulario y devuelve la respuesta cruda.
  func postForm(_ campos: [String: String], to url: URL, authorization: String) async throws -> Data
}

/// Implementacion real sobre `URLSession`.
struct PSNAuthTransport: PSNAuthTransporting {
  private let session: URLSession

  init(session: URLSession? = nil) {
    // Sin cookies compartidas: el NPSSO se manda a mano en cada peticion y no
    // debe quedar guardado en el almacen de cookies del sistema.
    if let session {
      self.session = session
    } else {
      let config = URLSessionConfiguration.ephemeral
      config.httpCookieAcceptPolicy = .never
      config.httpShouldSetCookies = false
      self.session = URLSession(configuration: config)
    }
  }

  func redirectLocation(for url: URL, npsso: String) async throws -> URL {
    var peticion = URLRequest(url: url)
    peticion.setValue("npsso=\(npsso)", forHTTPHeaderField: "Cookie")

    let (_, respuesta) = try await enviar(peticion, siguiendoRedirecciones: false)

    guard let http = respuesta as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }

    guard (300...399).contains(http.statusCode) else {
      // Sin redireccion no hay codigo que leer. Pasa si Sony cambia el flujo.
      throw PSNAuthError.respuestaInesperada("HTTP \(http.statusCode) sin redireccion")
    }

    guard let destino = http.value(forHTTPHeaderField: "Location"),
          let url = URL(string: destino)
    else {
      throw PSNAuthError.respuestaInesperada("Redireccion sin destino")
    }

    return url
  }

  func postForm(_ campos: [String: String], to url: URL, authorization: String) async throws -> Data {
    var peticion = URLRequest(url: url)
    peticion.httpMethod = "POST"
    peticion.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    peticion.setValue(authorization, forHTTPHeaderField: "Authorization")
    peticion.httpBody = Self.formulario(campos)

    let (datos, _) = try await enviar(peticion, siguiendoRedirecciones: true)
    return datos
  }

  /// Codifica el formulario.
  ///
  /// Se ordenan las claves para que el cuerpo sea el mismo en cada ejecucion y
  /// las pruebas puedan compararlo.
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

  private func enviar(
    _ peticion: URLRequest,
    siguiendoRedirecciones: Bool
  ) async throws -> (Data, URLResponse) {
    do {
      if siguiendoRedirecciones {
        return try await session.data(for: peticion)
      }
      let delegado = SinSeguirRedirecciones()
      return try await session.data(for: peticion, delegate: delegado)
    } catch let error as URLError {
      let sinRed: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed
      ]
      throw sinRed.contains(error.code) ? NetworkError.noConnection : NetworkError.invalidResponse
    }
  }
}

/// Delegado que corta las redirecciones para poder leer la cabecera `Location`.
///
/// `URLSession` las sigue sola, y siguiendo esta se perderia el codigo de
/// autorizacion: el destino es `com.scee.psxandroid.scecompcall://redirect`,
/// un esquema de otra app que ni siquiera se puede abrir.
private final class SinSeguirRedirecciones: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  // Se usa la version con completion handler y no la `async`: esta ultima, con
  // el aislamiento por defecto en MainActor que usa el proyecto, tumbaba al
  // compilador (no daba un error, se caia).
  nonisolated func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
