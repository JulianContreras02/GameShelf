//
//  Game.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Un juego de la biblioteca, independiente de la tienda de donde venga.
///
/// Un mismo `Game` puede estar en varias tiendas a la vez: esa relacion vive en
/// `storeEntries`. Esa separacion es la que despues permite detectar que un
/// juego lo tienes en Steam y en Epic sin duplicarlo en la biblioteca.
///
/// Los campos personales (`status`, `notes`) no se sobrescriben al
/// re-sincronizar con una tienda.
@Model
final class Game {
  /// Identificador propio de la app, estable aunque cambien los ids de tienda.
  var id: UUID = UUID()

  var name: String = ""

  /// URL de la caratula. Se guarda como texto porque SwiftData no persiste
  /// `URL` de forma directa y confiable.
  var coverImageURL: String?

  var releaseDate: Date?

  /// Horas jugadas acumuladas, sumando todas las tiendas.
  var playtimeHours: Double = 0

  /// Notas personales del usuario.
  var notes: String = ""

  var status: PlayStatus = PlayStatus.backlog

  /// Cuando se creo el registro en la app.
  var addedAt: Date = Date()

  /// En que tiendas esta este juego.
  ///
  /// Si se borra el juego, sus entradas de tienda se borran con el: no tienen
  /// sentido por separado.
  @Relationship(deleteRule: .cascade, inverse: \StoreEntry.game)
  var storeEntries: [StoreEntry] = []

  init(
    name: String,
    coverImageURL: String? = nil,
    releaseDate: Date? = nil,
    playtimeHours: Double = 0,
    notes: String = "",
    status: PlayStatus = .backlog
  ) {
    self.id = UUID()
    self.name = name
    self.coverImageURL = coverImageURL
    self.releaseDate = releaseDate
    self.playtimeHours = playtimeHours
    self.notes = notes
    self.status = status
    self.addedAt = Date()
    self.storeEntries = []
  }

  /// Tiendas en las que esta el juego, sin repetir.
  var stores: [Store] {
    Array(Set(storeEntries.map(\.store))).sorted { $0.rawValue < $1.rawValue }
  }

  /// Si el juego esta disponible en una tienda concreta.
  func isAvailable(on store: Store) -> Bool {
    storeEntries.contains { $0.store == store }
  }
}
