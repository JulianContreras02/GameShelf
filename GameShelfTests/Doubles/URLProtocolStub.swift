//
//  URLProtocolStub.swift
//  GameShelfTests
//

import Foundation

/// Intercepta las peticiones de `URLSession` para probar el cliente **real**.
///
/// Ojo: guarda lo recibido en propiedades estaticas, porque `URLSession` crea
/// las instancias por su cuenta y no hay donde inyectar nada. Por eso la suite
/// que lo usa tiene que ir marcada `.serialized`: en paralelo, una prueba
/// pisaria la respuesta preparada por otra.
///
/// El resto de las pruebas usan `StubHTTPClient`, que reemplaza el cliente
/// entero. Eso sirve para los servicios, pero deja sin probar lo que hace
/// `URLSessionHTTPClient`: poner el metodo, la cabecera y el cuerpo. Justo lo
/// que puede estar mal sin que nadie se entere hasta hablar con la API de
/// verdad.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {

  /// Que responder y que se recibio. Es estatico porque `URLSession` crea las
  /// instancias por su cuenta y no hay donde inyectar nada.
  nonisolated(unsafe) private static var respuesta: (Data, Int) = (Data(), 200)
  nonisolated(unsafe) private(set) static var peticiones: [URLRequest] = []

  /// Prepara una sesion que responde siempre lo mismo.
  static func session(devolviendo json: String, codigo: Int = 200) -> URLSession {
    respuesta = (Data(json.utf8), codigo)
    peticiones = []

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: config)
  }

  /// El cuerpo de la ultima peticion, como texto.
  ///
  /// `URLProtocol` vacia `httpBody` y deja el contenido en `httpBodyStream`,
  /// asi que hay que leerlo del stream.
  static func ultimoCuerpo() -> String? {
    guard let peticion = peticiones.last else { return nil }

    if let body = peticion.httpBody {
      return String(data: body, encoding: .utf8)
    }

    guard let stream = peticion.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }

    var datos = Data()
    let tamano = 1024
    var buffer = [UInt8](repeating: 0, count: tamano)
    while stream.hasBytesAvailable {
      let leidos = stream.read(&buffer, maxLength: tamano)
      if leidos <= 0 { break }
      datos.append(buffer, count: leidos)
    }
    return String(data: datos, encoding: .utf8)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.peticiones.append(request)

    let (datos, codigo) = Self.respuesta
    if let url = request.url,
       let response = HTTPURLResponse(url: url, statusCode: codigo, httpVersion: nil, headerFields: nil) {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
    client?.urlProtocol(self, didLoad: datos)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
