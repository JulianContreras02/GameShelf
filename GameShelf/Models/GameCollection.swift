//
//  GameCollection.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Una carpeta creada por el usuario para agrupar juegos.
///
/// Es lo que ninguna tienda permite: juntar en un mismo grupo juegos de Steam,
/// PSN y Epic. Un juego puede estar en varias colecciones a la vez.
///
/// El tipo se llama `GameCollection` y no `Collection` a proposito: ese nombre
/// sombrea el protocolo `Swift.Collection` y rompe cualquier codigo generico
/// que lo use (`'Element' is not a member type of type 'C'`).
@Model
final class GameCollection {
  var id: UUID = UUID()

  var name: String = ""

  /// Nombre de un simbolo del sistema (SF Symbols), por ejemplo `folder`.
  var symbolName: String = GameCollection.defaultSymbol

  /// Color de la coleccion. Se guarda como texto por lo mismo que los demas
  /// enums del proyecto.
  var color: CollectionColor = CollectionColor.default

  /// Posicion en la lista. El usuario las reordena arrastrando.
  var sortOrder: Int = 0

  var createdAt: Date = Date()

  /// Juegos que contiene.
  ///
  /// La regla de borrado es `nullify`, la que trae SwiftData por defecto en las
  /// relaciones a varios: borrar una coleccion **no borra los juegos**, solo
  /// deshace la agrupacion.
  @Relationship(inverse: \Game.collections)
  var games: [Game] = []

  static let defaultSymbol = "folder"

  init(
    name: String,
    symbolName: String = GameCollection.defaultSymbol,
    color: CollectionColor = .default,
    sortOrder: Int = 0
  ) {
    self.id = UUID()
    self.name = name
    self.symbolName = symbolName
    self.color = color
    self.sortOrder = sortOrder
    self.createdAt = Date()
    self.games = []
  }

  /// Cuantos juegos tiene.
  var gameCount: Int { games.count }

  /// Si no tiene ningun juego.
  var isEmpty: Bool { games.isEmpty }

  /// Horas jugadas sumando todos sus juegos.
  var totalPlaytimeHours: Double {
    games.reduce(0) { $0 + $1.playtimeHours }
  }

  /// Agrega un juego, sin duplicarlo si ya estaba.
  func add(_ game: Game) {
    guard !contains(game) else { return }
    games.append(game)
  }

  /// Quita un juego de la coleccion. El juego no se borra.
  func remove(_ game: Game) {
    games.removeAll { $0.id == game.id }
  }

  /// Si el juego ya esta en la coleccion.
  func contains(_ game: Game) -> Bool {
    games.contains { $0.id == game.id }
  }
}
