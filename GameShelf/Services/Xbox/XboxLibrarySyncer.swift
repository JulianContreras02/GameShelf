//
//  XboxLibrarySyncer.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Guarda en la base local la biblioteca que llega de Xbox.
///
/// Como los otros tres: **idempotente**, y nunca borra.
struct XboxLibrarySyncer {

  /// Que cambio en una sincronizacion.
  struct Result: Equatable {
    var created: Int = 0
    var updated: Int = 0
    /// Juegos que ya estaban por otra tienda y ahora tambien tienen Xbox.
    var merged: Int = 0

    var total: Int { created + updated + merged }
  }

  /// Sincroniza los juegos de Xbox contra lo que ya hay guardado.
  ///
  /// Usa el mismo `LibraryMatcher` que PSN y Epic: un juego que ya vino de
  /// otra tienda suma su entrada de Xbox en vez de duplicarse.
  @discardableResult
  static func sync(
    _ juegos: [XboxGame],
    into context: ModelContext
  ) throws -> Result {
    guard !juegos.isEmpty else { return Result() }

    var matcher = try LibraryMatcher(store: .xbox, context: context)
    var result = Result()

    for juego in juegos {
      switch matcher.buscar(storeGameID: juego.titleId, nombre: juego.name) {
      case .mismaTienda(let existente):
        XboxGameMapper.update(existente, from: juego)
        result.updated += 1

      case .otraTienda(let existente):
        // Por aca entra tambien la version de Xbox 360 de un juego que ya
        // vino en la de Xbox One: mismo nombre, otro titleId, y `update` le
        // agrega su propia entrada.
        XboxGameMapper.update(existente, from: juego)
        result.merged += 1

      case .nuevo:
        let nuevo = XboxGameMapper.makeGame(from: juego)
        context.insert(nuevo)
        matcher.registrar(nuevo)
        result.created += 1
      }
    }

    try context.save()
    return result
  }
}

/// Traduce los juegos de Xbox a los modelos de dominio.
enum XboxGameMapper {

  /// Crea un `Game` nuevo con su entrada de Xbox.
  ///
  /// Nace en `.backlog`, como en las otras tiendas: el estado lo pone el
  /// usuario.
  static func makeGame(from juego: XboxGame) -> Game {
    let game = Game(
      name: juego.name,
      coverImageURL: juego.coverURL?.absoluteString,
      playtimeHours: juego.playtimeHours ?? 0
    )
    game.storeEntries = [makeStoreEntry(from: juego)]
    return game
  }

  /// Crea la entrada de tienda correspondiente.
  static func makeStoreEntry(from juego: XboxGame) -> StoreEntry {
    StoreEntry(
      store: .xbox,
      storeGameID: juego.titleId,
      playtimeHours: juego.playtimeHours ?? 0,
      lastPlayedAt: juego.lastPlayedAt,
      earnedGamerscore: juego.gamerscore?.earned,
      totalGamerscore: juego.gamerscore?.total,
      lastSyncedAt: Date()
    )
  }

  /// Actualiza un juego que ya existia.
  ///
  /// **No toca `status` ni `notes`**, como en las otras tiendas.
  static func update(_ game: Game, from juego: XboxGame) {
    // El nombre no se pisa, igual que en Epic: Xbox le pone ® y ™ a muchos
    // ("Assassin's Creed® Syndicate"), y si el juego ya vino de otra tienda
    // su nombre suele estar mas limpio.
    if let caratula = juego.coverURL?.absoluteString, game.coverImageURL == nil {
      game.coverImageURL = caratula
    }

    // Por id y no solo por tienda, igual que en PSN: la version de Xbox 360 y
    // la de Xbox One del mismo juego tienen titleId distinto y logros
    // distintos. Buscando solo por tienda, una pisaria a la otra.
    if let entrada = game.storeEntries.first(where: { $0.store == .xbox && $0.storeGameID == juego.titleId }) {
      actualizar(entrada, con: juego)
    } else {
      game.storeEntries.append(makeStoreEntry(from: juego))
    }

    SteamGameMapper.recalculatePlaytime(for: game)
  }

  private static func actualizar(_ entrada: StoreEntry, con juego: XboxGame) {
    // Solo se pisa lo que llego. Las horas salen de una consulta aparte que
    // puede fallar sin tumbar la sincronizacion, y en ese caso las que ya
    // estaban guardadas son mejores que un cero.
    if let horas = juego.playtimeHours {
      entrada.playtimeHours = horas
    }
    if let ultima = juego.lastPlayedAt {
      entrada.lastPlayedAt = ultima
    }
    if let puntos = juego.gamerscore {
      entrada.earnedGamerscore = puntos.earned
      entrada.totalGamerscore = puntos.total
    }

    entrada.lastSyncedAt = Date()
  }
}
