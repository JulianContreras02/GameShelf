//
//  EpicLibrarySyncer.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Guarda en la base local la biblioteca que llega de Epic.
///
/// Como los otros dos: **idempotente**, y nunca borra.
struct EpicLibrarySyncer {

  /// Que cambio en una sincronizacion.
  struct Result: Equatable {
    var created: Int = 0
    var updated: Int = 0
    /// Juegos que ya estaban por otra tienda y ahora tambien tienen Epic.
    var merged: Int = 0

    var total: Int { created + updated + merged }
  }

  /// Sincroniza los juegos de Epic contra lo que ya hay guardado.
  @discardableResult
  static func sync(
    _ juegos: [EpicGame],
    into context: ModelContext
  ) throws -> Result {
    guard !juegos.isEmpty else { return Result() }

    var matcher = try LibraryMatcher(store: .epic, context: context)
    var result = Result()

    for juego in juegos {
      switch matcher.buscar(storeGameID: juego.namespace, nombre: juego.name) {
      case .mismaTienda(let existente):
        EpicGameMapper.update(existente, from: juego)
        result.updated += 1

      case .otraTienda(let existente):
        EpicGameMapper.update(existente, from: juego)
        result.merged += 1

      case .nuevo:
        let nuevo = EpicGameMapper.makeGame(from: juego)
        context.insert(nuevo)
        matcher.registrar(nuevo)
        result.created += 1
      }
    }

    try context.save()
    return result
  }
}

/// Traduce los juegos de Epic a los modelos de dominio.
enum EpicGameMapper {

  /// Crea un `Game` nuevo con su entrada de Epic.
  static func makeGame(from juego: EpicGame) -> Game {
    let game = Game(
      name: juego.name,
      coverImageURL: juego.coverURL?.absoluteString,
      playtimeHours: juego.playtimeHours
    )
    game.storeEntries = [makeStoreEntry(from: juego)]
    return game
  }

  /// Crea la entrada de tienda correspondiente.
  ///
  /// El `storeGameID` es el namespace y no el appName: un juego tiene varios
  /// appName (el ejecutable, sus DLC) y un solo namespace.
  static func makeStoreEntry(from juego: EpicGame) -> StoreEntry {
    StoreEntry(
      store: .epic,
      storeGameID: juego.namespace,
      playtimeHours: juego.playtimeHours,
      lastSyncedAt: Date()
    )
  }

  /// Actualiza un juego que ya existia.
  ///
  /// **No toca `status` ni `notes`**, como en las otras tiendas.
  static func update(_ game: Game, from juego: EpicGame) {
    // El nombre no se pisa: si el juego ya vino de Steam o PSN, el que tenga
    // suele ser mejor que el de Epic, donde algunos son nombres de sandbox.
    if let caratula = juego.coverURL?.absoluteString, game.coverImageURL == nil {
      game.coverImageURL = caratula
    }

    if let entrada = game.storeEntries.first(where: { $0.store == .epic }) {
      entrada.storeGameID = juego.namespace
      entrada.playtimeHours = juego.playtimeHours
      entrada.lastSyncedAt = Date()
    } else {
      game.storeEntries.append(makeStoreEntry(from: juego))
    }

    SteamGameMapper.recalculatePlaytime(for: game)
  }
}
