//
//  StoreEntry.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Un juego tal como existe en una tienda concreta.
///
/// El mismo `Game` puede tener varias entradas: una por cada tienda donde el
/// usuario lo tenga. Aca vive todo lo que depende de la tienda (el id de esa
/// tienda, la URL de su ficha, cuanto se jugo ahi), y en `Game` lo que es comun
/// al juego sin importar donde se compro.
@Model
final class StoreEntry {
  var id: UUID = UUID()

  var store: Store = Store.steam

  /// Identificador del juego dentro de esa tienda. En Steam es el appid.
  var storeGameID: String = ""

  /// Ficha del juego en la tienda. Texto y no `URL` por la misma razon que en
  /// `Game.coverImageURL`.
  var storeURL: String?

  /// Horas jugadas registradas por esta tienda en particular.
  var playtimeHours: Double = 0

  /// Horas jugadas en las ultimas dos semanas, segun la tienda.
  ///
  /// `0` si no hubo actividad. Viene de `playtime_2weeks` en Steam, que solo
  /// manda el campo cuando el juego se toco hace poco.
  var recentPlaytimeHours: Double = 0

  /// Ultima vez que el usuario jugo, segun la tienda.
  ///
  /// `nil` si nunca lo jugo ahi. Viene de `rtime_last_played` en Steam.
  var lastPlayedAt: Date?

  /// Ultima vez que se sincronizo con la tienda.
  var lastSyncedAt: Date?

  /// Juego al que pertenece. La relacion inversa esta en `Game.storeEntries`.
  var game: Game?

  init(
    store: Store,
    storeGameID: String,
    storeURL: String? = nil,
    playtimeHours: Double = 0,
    recentPlaytimeHours: Double = 0,
    lastPlayedAt: Date? = nil,
    lastSyncedAt: Date? = nil
  ) {
    self.id = UUID()
    self.store = store
    self.storeGameID = storeGameID
    self.storeURL = storeURL
    self.playtimeHours = playtimeHours
    self.recentPlaytimeHours = recentPlaytimeHours
    self.lastPlayedAt = lastPlayedAt
    self.lastSyncedAt = lastSyncedAt
  }
}
