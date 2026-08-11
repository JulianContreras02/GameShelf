//
//  Fixture.swift
//  GameShelfTests
//

import Foundation

/// Clase vacia que solo sirve para ubicar el bundle de pruebas.
///
/// `Bundle(for:)` necesita una clase, y las suites de Swift Testing son
/// structs, asi que hace falta este puente.
private final class BundleToken {}

/// Carga archivos de apoyo desde `GameShelfTests/Fixtures/`.
enum Fixture {

  enum FixtureError: Error, CustomStringConvertible {
    case notFound(String)

    var description: String {
      switch self {
      case .notFound(let name):
        "No se encontro el archivo de apoyo '\(name)'. Revisa que este en GameShelfTests/Fixtures/."
      }
    }
  }

  /// Devuelve el contenido crudo de un archivo de apoyo.
  static func data(_ name: String, extension ext: String = "json") throws -> Data {
    let bundle = Bundle(for: BundleToken.self)
    guard let url = bundle.url(forResource: name, withExtension: ext) else {
      throw FixtureError.notFound("\(name).\(ext)")
    }
    return try Data(contentsOf: url)
  }

  /// Carga un archivo de apoyo y lo decodifica.
  static func decode<T: Decodable>(
    _ type: T.Type,
    from name: String,
    extension ext: String = "json"
  ) throws -> T {
    try JSONDecoder().decode(type, from: data(name, extension: ext))
  }
}
