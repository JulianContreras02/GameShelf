//
//  PSNGameMapper.swift
//  GameShelf
//

import Foundation

/// Traduce los juegos de PSN a los modelos de dominio.
///
/// Igual que su equivalente de Steam: funcion pura, sin base de datos, para
/// poder probarla sola.
enum PSNGameMapper {

  /// Crea un `Game` nuevo con su entrada de PlayStation.
  ///
  /// Nace en `.backlog`: el estado lo pone el usuario, no la tienda.
  static func makeGame(from juego: PSNGame) -> Game {
    let game = Game(
      name: juego.name,
      coverImageURL: juego.coverURL?.absoluteString,
      playtimeHours: juego.playtimeHours ?? 0
    )
    game.storeEntries = [makeStoreEntry(from: juego)]
    return game
  }

  /// Crea la entrada de tienda correspondiente.
  static func makeStoreEntry(from juego: PSNGame) -> StoreEntry {
    StoreEntry(
      store: .psn,
      storeGameID: juego.titleId,
      playtimeHours: juego.playtimeHours ?? 0,
      lastPlayedAt: juego.lastPlayedAt,
      trophyProgress: juego.trophyProgress,
      launchCount: juego.playCount,
      lastSyncedAt: Date()
    )
  }

  /// Actualiza un juego que ya existia.
  ///
  /// **No toca `status` ni `notes`.** Misma regla que en Steam: son del
  /// usuario y ninguna sincronizacion los cambia.
  static func update(_ game: Game, from juego: PSNGame) {
    game.name = juego.name

    if let caratula = juego.coverURL?.absoluteString {
      game.coverImageURL = caratula
    }

    // Se busca por id de juego y no solo por tienda: PSN lista el mismo juego
    // dos veces cuando existe en consola y en PC (`ps5_native_game` y
    // `pspc_game`), con titleId y horas distintas. Buscando solo por tienda, la
    // segunda version pisaria a la primera y se perderian sus horas. Asi cada
    // version tiene su entrada y el total las suma.
    if let entrada = game.storeEntries.first(where: { $0.store == .psn && $0.storeGameID == juego.titleId }) {
      actualizar(entrada, con: juego)
    } else {
      game.storeEntries.append(makeStoreEntry(from: juego))
    }

    SteamGameMapper.recalculatePlaytime(for: game)
  }

  private static func actualizar(_ entrada: StoreEntry, con juego: PSNGame) {
    // Solo se pisa lo que llego bien. Si PSN mando una duracion ilegible, la
    // que ya estaba guardada es mejor que un cero.
    if let horas = juego.playtimeHours {
      entrada.playtimeHours = horas
    }
    if let ultima = juego.lastPlayedAt {
      entrada.lastPlayedAt = ultima
    }
    if let progreso = juego.trophyProgress {
      entrada.trophyProgress = progreso
    }
    if let veces = juego.playCount {
      entrada.launchCount = veces
    }

    entrada.lastSyncedAt = Date()
  }
}
