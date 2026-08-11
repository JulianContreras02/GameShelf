//
//  GameTag.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Etiqueta libre que el usuario le pone a sus juegos.
///
/// Se diferencia de `GameCollection` en como se usa, no en la forma: una
/// coleccion se crea con un formulario (nombre, icono, color) y sirve para
/// agrupar a proposito; una etiqueta se escribe al vuelo mientras miras un
/// juego, y sirve para marcar cosas sueltas ("coop", "para el Deck",
/// "pendiente de DLC").
@Model
final class GameTag {
  var id: UUID = UUID()

  /// Nombre tal como lo escribio el usuario la primera vez.
  ///
  /// Para comparar se usa `normalized`, que ignora mayusculas y tildes: no
  /// tiene sentido que "RPG" y "rpg" sean etiquetas distintas.
  var name: String = ""

  var createdAt: Date = Date()

  /// Juegos que llevan esta etiqueta.
  ///
  /// Regla de borrado por defecto (`nullify`): borrar la etiqueta la quita de
  /// los juegos, pero no borra los juegos.
  @Relationship(inverse: \Game.tags)
  var games: [Game] = []

  /// Limite del nombre. Una etiqueta larga deja de servir como etiqueta.
  static let maxNameLength = 30

  init(name: String) {
    self.id = UUID()
    self.name = GameTag.clean(name)
    self.createdAt = Date()
    self.games = []
  }

  /// Cuantos juegos la usan.
  var gameCount: Int { games.count }

  /// Si no la usa ningun juego.
  var isOrphan: Bool { games.isEmpty }

  /// Forma con la que se compara: sin espacios sobrantes, en minusculas y sin
  /// tildes.
  var normalized: String { GameTag.normalize(name) }

  /// Quita los espacios sobrantes y colapsa los internos.
  ///
  /// "  juego   coop " queda como "juego coop".
  static func clean(_ nombre: String) -> String {
    nombre
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  /// Forma para comparar dos nombres: sin mayusculas ni tildes.
  static func normalize(_ nombre: String) -> String {
    clean(nombre).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }

  /// Si dos nombres son la misma etiqueta.
  static func areEquivalent(_ uno: String, _ otro: String) -> Bool {
    normalize(uno) == normalize(otro)
  }
}
