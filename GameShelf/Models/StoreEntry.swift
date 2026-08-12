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

  /// Cuando el usuario lo puso en la lista de deseos de esta tienda.
  ///
  /// `nil` si no esta en ella. Es un **dato de la tienda**, distinto de
  /// `Game.status == .wishlist`, que es una decision del usuario: puedes tener
  /// un juego en tu lista de deseos de Steam y haberlo marcado como terminado
  /// porque lo jugaste en consola.
  ///
  /// Sirve ademas para saber que dejo de estar en la lista: si sincronizas y ya
  /// no viene, se pone en `nil` sin tocar el estado.
  var wishlistedAt: Date?

  /// Si la tienda dice que el juego todavia no ha salido.
  ///
  /// No basta con mirar `Game.releaseDate`: Steam informa el lanzamiento de una
  /// de dos formas y nunca de las dos a la vez. O manda una fecha aproximada
  /// (el 31 de diciembre quiere decir "en algun momento de este ano"), o manda
  /// solo un texto ("Proximamente") y ninguna fecha. En ese segundo caso, sin
  /// este campo el juego pareceria ya lanzado.
  var comingSoon: Bool = false

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
    wishlistedAt: Date? = nil,
    comingSoon: Bool = false,
    lastSyncedAt: Date? = nil
  ) {
    self.id = UUID()
    self.store = store
    self.storeGameID = storeGameID
    self.storeURL = storeURL
    self.playtimeHours = playtimeHours
    self.recentPlaytimeHours = recentPlaytimeHours
    self.lastPlayedAt = lastPlayedAt
    self.wishlistedAt = wishlistedAt
    self.comingSoon = comingSoon
    self.lastSyncedAt = lastSyncedAt
  }
}
