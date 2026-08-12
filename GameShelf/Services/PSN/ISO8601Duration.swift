//
//  ISO8601Duration.swift
//  GameShelf
//

import Foundation

/// Lee duraciones en formato ISO 8601, como las que manda PSN.
///
/// PSN no da el tiempo jugado en minutos sino asi: `PT29H47M44S`. Se parsea a
/// mano y no con `DateComponentsFormatter` porque ese tipo sirve para dar
/// formato, no para leer, y su contraparte
/// (`ISO8601DateComponentsFormatter`) no existe en iOS.
enum ISO8601Duration {

  /// Convierte una duracion ISO 8601 en segundos.
  ///
  /// Acepta la forma completa `PnDTnHnMnS` y cualquier subconjunto:
  /// `PT0S`, `PT15S`, `PT6M15S`, `PT29H47M44S`, `P2DT3H`.
  ///
  /// - Returns: `nil` si el texto no es una duracion valida. Devolver 0 seria
  ///   peor: se confundiria "no se pudo leer" con "no lo has jugado".
  static func seconds(from texto: String?) -> Int? {
    guard let texto, texto.hasPrefix("P") else { return nil }

    // Se parte en la fecha (dias) y la hora (horas, minutos, segundos), que es
    // lo que separa la "T". Sin ella, "M" significaria meses y no minutos.
    let cuerpo = texto.dropFirst()
    let partes = cuerpo.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)

    guard let fecha = partes.first else { return nil }
    let hora = partes.count > 1 ? partes[1] : ""

    guard let dias = valor(en: fecha, unidad: "D"),
          let horas = valor(en: hora, unidad: "H"),
          let minutos = valor(en: hora, unidad: "M"),
          let segundos = valor(en: hora, unidad: "S")
    else { return nil }

    // "P" o "PT" a secas no son duraciones utiles: no dicen nada.
    guard !fecha.isEmpty || !hora.isEmpty else { return nil }

    return dias * 86_400 + horas * 3_600 + minutos * 60 + segundos
  }

  /// La misma duracion, en horas.
  static func hours(from texto: String?) -> Double? {
    guard let segundos = seconds(from: texto) else { return nil }
    return Double(segundos) / 3_600
  }

  /// Saca el numero que precede a una unidad. `0` si esa unidad no aparece.
  ///
  /// - Returns: `nil` si lo que precede a la unidad no es un numero, para que
  ///   un texto mal formado no se lea como cero.
  private static func valor(en texto: Substring, unidad: Character) -> Int? {
    guard let posicion = texto.firstIndex(of: unidad) else { return 0 }

    // Los digitos van justo antes de la unidad, despues de la anterior.
    let anteriores = texto[texto.startIndex..<posicion]
    let digitos = anteriores.suffix(while: \.isNumber)

    guard !digitos.isEmpty, let numero = Int(digitos) else { return nil }
    return numero
  }
}

private extension Substring {
  /// Los ultimos caracteres que cumplen la condicion.
  func suffix(while condicion: (Character) -> Bool) -> Substring {
    var inicio = endIndex
    while inicio > startIndex {
      let anterior = index(before: inicio)
      guard condicion(self[anterior]) else { break }
      inicio = anterior
    }
    return self[inicio..<endIndex]
  }
}
