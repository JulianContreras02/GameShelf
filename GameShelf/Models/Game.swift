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

  /// Colecciones del usuario a las que pertenece.
  ///
  /// Relacion de muchos a muchos: un juego puede estar en varias colecciones y
  /// una coleccion tiene varios juegos. Borrar un juego no borra las
  /// colecciones, y borrar una coleccion no borra los juegos.
  var collections: [GameCollection] = []

  /// Etiquetas libres del usuario.
  ///
  /// Tambien muchos a muchos. A diferencia de las colecciones, se escriben al
  /// vuelo desde la ficha del juego.
  var tags: [GameTag] = []

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

  /// La ultima vez que se jugo, mirando todas las tiendas.
  ///
  /// `nil` si no se ha jugado en ninguna.
  var lastPlayedAt: Date? {
    storeEntries.compactMap(\.lastPlayedAt).max()
  }

  /// Si el juego nunca se ha jugado, segun las horas que reportan las tiendas.
  ///
  /// Es distinto de `status`: esto es un dato de la tienda, y `status` es una
  /// decision del usuario. Pueden no coincidir, por ejemplo si lo jugaste en
  /// consola y lo marcaste como terminado.
  var isUnplayed: Bool {
    playtimeHours <= 0
  }

  /// Enlace a la ficha del juego en una tienda.
  ///
  /// Si esta en varias, prefiere la que se indique; si no, la primera que
  /// tenga enlace.
  func storeLink(preferring store: Store? = nil) -> URL? {
    let candidatas = storeEntries.filter { $0.storeURL?.isEmpty == false }

    let elegida = store.flatMap { preferida in
      candidatas.first { $0.store == preferida }
    } ?? candidatas.first

    return elegida?.storeURL.flatMap(URL.init(string:))
  }
}
