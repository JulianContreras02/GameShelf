//
//  GameNotesViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Guarda las notas personales de un juego.
///
/// Las notas son el dato mas irrecuperable de la app: un juego borrado se
/// vuelve a sincronizar, pero lo que escribio el usuario no. Por eso el guardado
/// es automatico y esta cubierto por pruebas.
@Observable
@MainActor
final class GameNotesViewModel {

  /// Limite del texto.
  ///
  /// No es una restriccion del almacenamiento: es para que un pegado accidental
  /// de miles de lineas no vuelva lenta la ficha del juego.
  static let maxLength = 5_000

  /// A partir de cuantos caracteres se muestra el contador.
  static let counterThreshold = 4_500

  init() {}

  /// Guarda las notas si cambiaron.
  ///
  /// Recorta los espacios de los bordes: una nota que solo tiene espacios es
  /// una nota vacia, y guardarla haria que el juego pareciera tener algo
  /// escrito.
  ///
  /// - Returns: `true` si de verdad se guardo algo distinto.
  @discardableResult
  func save(
    _ texto: String,
    for juego: Game,
    in context: ModelContext
  ) throws -> Bool {
    let limpio = Self.clean(texto)

    guard limpio != juego.notes else { return false }

    juego.notes = limpio
    try context.save()
    return true
  }

  /// Borra las notas de un juego.
  func clear(for juego: Game, in context: ModelContext) throws {
    guard !juego.notes.isEmpty else { return }
    juego.notes = ""
    try context.save()
  }

  /// Deja el texto como se va a guardar.
  ///
  /// Recorta los bordes y corta si pasa del limite. Los saltos de linea de en
  /// medio se conservan: son parte de lo que escribio el usuario.
  nonisolated static func clean(_ texto: String) -> String {
    let recortado = texto.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(recortado.prefix(maxLength))
  }

  /// Si el texto se va a recortar al guardar.
  nonisolated static func exceedsLimit(_ texto: String) -> Bool {
    texto.trimmingCharacters(in: .whitespacesAndNewlines).count > maxLength
  }

  /// Si conviene mostrar el contador de caracteres.
  nonisolated static func shouldShowCounter(_ texto: String) -> Bool {
    texto.count >= counterThreshold
  }
}
