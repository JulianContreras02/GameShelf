//
//  String+Search.swift
//  GameShelf
//

import Foundation

extension String {
  /// Forma del texto para comparar y buscar: sin espacios sobrantes, sin
  /// mayusculas y sin tildes.
  ///
  /// Es lo que hace que "accion" encuentre "Acción" y que "RPG" y "rpg" sean lo
  /// mismo. Vive aca y no en cada tipo para que la busqueda y las etiquetas
  /// usen exactamente la misma regla.
  var normalizedForSearch: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }

  /// Si el texto contiene lo buscado, ignorando mayusculas y tildes.
  func containsNormalized(_ buscado: String) -> Bool {
    let normalizado = buscado.normalizedForSearch
    guard !normalizado.isEmpty else { return true }
    return normalizedForSearch.contains(normalizado)
  }

  /// Si el texto empieza por lo buscado, ignorando mayusculas y tildes.
  func hasPrefixNormalized(_ buscado: String) -> Bool {
    let normalizado = buscado.normalizedForSearch
    guard !normalizado.isEmpty else { return true }
    return normalizedForSearch.hasPrefix(normalizado)
  }
}
