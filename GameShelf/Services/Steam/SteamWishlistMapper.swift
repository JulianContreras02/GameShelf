//
//  SteamWishlistMapper.swift
//  GameShelf
//

import Foundation

/// Traduce los juegos de la lista de deseos a los modelos de dominio.
///
/// Va aparte del sincronizador por la misma razon que `SteamGameMapper`: es una
/// funcion pura, sin base de datos, y asi se prueba sola.
enum SteamWishlistMapper {

  /// Crea un `Game` nuevo a partir de un juego de la lista de deseos.
  ///
  /// Nace con `status = .wishlist`, que es lo que el usuario espera ver.
  /// `playtimeHours` queda en 0: no lo tiene, no lo ha jugado.
  static func makeGame(from juego: SteamWishlistGame) -> Game {
    let game = Game(
      name: juego.name,
      coverImageURL: juego.coverURL?.absoluteString,
      releaseDate: juego.releaseDate,
      status: .wishlist
    )
    game.storeEntries = [makeStoreEntry(from: juego)]
    return game
  }

  /// Crea la entrada de tienda correspondiente.
  static func makeStoreEntry(from juego: SteamWishlistGame) -> StoreEntry {
    StoreEntry(
      store: .steam,
      storeGameID: String(juego.appID),
      storeURL: juego.storeURL?.absoluteString,
      wishlistedAt: juego.addedAt ?? Date(),
      comingSoon: juego.isComingSoon,
      lastSyncedAt: Date()
    )
  }

  /// Actualiza un juego que ya existia.
  ///
  /// **No toca `status`.** Es la misma regla que en la biblioteca: si marcaste
  /// como terminado un juego que sigue en tu lista de deseos de Steam porque lo
  /// jugaste en consola, la sincronizacion no te lo cambia. Lo unico que se
  /// escribe es el hecho de la tienda: que esta en la lista, y desde cuando.
  ///
  /// Tampoco pisa las horas jugadas: un juego puede estar en la lista de deseos
  /// y a la vez ser uno que ya tienes (pasa con los DLC y las ediciones
  /// completas), y ahi las horas las manda la biblioteca, no la wishlist.
  static func update(_ game: Game, from juego: SteamWishlistGame) {
    game.name = juego.name

    // La caratula solo se pone si falta: la que ya tenga viene de la
    // biblioteca, que es igual de buena y evita que la fila parpadee.
    if game.coverImageURL == nil {
      game.coverImageURL = juego.coverURL?.absoluteString
    }
    if game.releaseDate == nil {
      game.releaseDate = juego.releaseDate
    }

    if let entrada = game.storeEntries.first(where: { $0.store == .steam }) {
      entrada.storeGameID = String(juego.appID)
      if entrada.storeURL == nil {
        entrada.storeURL = juego.storeURL?.absoluteString
      }
      // Se conserva la fecha que ya estuviera: es cuando lo deseaste por
      // primera vez, y Steam a veces la reporta distinta.
      entrada.wishlistedAt = entrada.wishlistedAt ?? juego.addedAt ?? Date()
      // Esto si se refresca cada vez: un juego que sale deja de ser futuro.
      entrada.comingSoon = juego.isComingSoon
      entrada.lastSyncedAt = Date()
    } else {
      game.storeEntries.append(makeStoreEntry(from: juego))
    }

    // game.status, game.notes, game.playtimeHours y las colecciones NO se
    // tocan: o son del usuario, o los manda la sincronizacion de la biblioteca.
  }
}
