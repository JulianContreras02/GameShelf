//
//  PSNLibrarySyncer.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Guarda en la base local la biblioteca que llega de PlayStation.
///
/// Igual que el de Steam: **idempotente**, y nunca borra. Un juego guardado que
/// deje de venir puede faltar porque la peticion fallo a medias, no porque el
/// usuario lo haya perdido.
struct PSNLibrarySyncer {

  /// Que cambio en una sincronizacion.
  struct Result: Equatable {
    var created: Int = 0
    var updated: Int = 0

    /// Juegos que ya estaban por otra tienda y ahora tambien tienen PSN.
    var merged: Int = 0

    var total: Int { created + updated }
  }

  /// Sincroniza los juegos de PSN contra lo que ya hay guardado.
  ///
  /// Un juego se reconoce por su `StoreEntry` de PSN. Si no lo tiene, se busca
  /// por nombre: asi un juego que ya vino de Steam **no se duplica**, sino que
  /// suma su entrada de PlayStation. Esa union es justo lo que hace util tener
  /// las dos tiendas en la misma app.
  @discardableResult
  static func sync(
    _ juegos: [PSNGame],
    into context: ModelContext
  ) throws -> Result {
    guard !juegos.isEmpty else { return Result() }

    let porPSN = try indexarEntradasDePSN(in: context)
    let todos = try context.fetch(FetchDescriptor<Game>())
    var porNombre = Dictionary(
      todos.map { ($0.name.normalizedForSearch, $0) },
      uniquingKeysWith: { primero, _ in primero }
    )

    var result = Result()

    for juego in juegos {
      if let entrada = porPSN[juego.titleId], let game = entrada.game {
        PSNGameMapper.update(game, from: juego)
        result.updated += 1
        continue
      }

      if let existente = porNombre[juego.name.normalizedForSearch] {
        // El mismo juego, ya guardado desde otra tienda.
        PSNGameMapper.update(existente, from: juego)
        result.merged += 1
        continue
      }

      let nuevo = PSNGameMapper.makeGame(from: juego)
      context.insert(nuevo)
      porNombre[juego.name.normalizedForSearch] = nuevo
      result.created += 1
    }

    try context.save()
    return result
  }

  /// Indexa las entradas de PSN ya guardadas por su id de tienda.
  private static func indexarEntradasDePSN(
    in context: ModelContext
  ) throws -> [String: StoreEntry] {
    let todas = try context.fetch(FetchDescriptor<StoreEntry>())

    return todas
      .filter { $0.store == .psn }
      .reduce(into: [String: StoreEntry]()) { indice, entrada in
        if indice[entrada.storeGameID] == nil {
          indice[entrada.storeGameID] = entrada
        }
      }
  }
}
