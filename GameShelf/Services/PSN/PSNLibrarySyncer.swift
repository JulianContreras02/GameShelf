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

    var matcher = try LibraryMatcher(store: .psn, context: context)
    var result = Result()

    for juego in juegos {
      switch matcher.buscar(storeGameID: juego.titleId, nombre: juego.name) {
      case .mismaTienda(let existente):
        PSNGameMapper.update(existente, from: juego)
        result.updated += 1

      case .otraTienda(let existente):
        // El mismo juego, ya guardado desde otra tienda. Por aca entra tambien
        // la version de PC de un juego de consola: mismo nombre, distinto
        // titleId, y `update` le agrega su propia entrada.
        PSNGameMapper.update(existente, from: juego)
        result.merged += 1

      case .nuevo:
        let nuevo = PSNGameMapper.makeGame(from: juego)
        context.insert(nuevo)
        matcher.registrar(nuevo)
        result.created += 1
      }
    }

    try context.save()
    return result
  }
}
