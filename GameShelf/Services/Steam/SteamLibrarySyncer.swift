//
//  SteamLibrarySyncer.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Guarda en la base local la biblioteca que llega de Steam.
///
/// La operacion es **idempotente**: correrla dos veces con los mismos datos
/// deja la base igual, sin duplicados.
struct SteamLibrarySyncer {

  /// Que cambio en una sincronizacion.
  struct Result: Equatable {
    /// Juegos que no existian y se crearon.
    var created: Int = 0
    /// Juegos que ya existian y se refrescaron.
    var updated: Int = 0

    var total: Int { created + updated }
  }

  /// Sincroniza la lista de Steam contra lo que ya hay guardado.
  ///
  /// Un juego se considera "el mismo" si existe un `StoreEntry` de Steam con su
  /// mismo `appID`. Los juegos guardados que ya no vienen en la respuesta **no
  /// se borran**: pueden faltar porque la peticion fallo a medias o porque
  /// Steam los omitio, y borrar la biblioteca del usuario por eso seria mucho
  /// peor que dejar un juego de mas.
  ///
  /// - Returns: Cuantos se crearon y cuantos se actualizaron.
  @discardableResult
  static func sync(
    _ dtos: [SteamGameDTO],
    into context: ModelContext
  ) throws -> Result {
    guard !dtos.isEmpty else { return Result() }

    // Se traen todas las entradas de Steam de una vez y se indexan en memoria.
    // Es mas rapido que una consulta por juego, y evita pelear con los
    // predicados de SwiftData sobre enums.
    let existentes = try indexarEntradasDeSteam(in: context)

    var result = Result()

    for dto in dtos {
      let clave = String(dto.appID)

      if let entrada = existentes[clave], let game = entrada.game {
        SteamGameMapper.update(game, from: dto)
        result.updated += 1
      } else {
        context.insert(SteamGameMapper.makeGame(from: dto))
        result.created += 1
      }
    }

    try context.save()
    return result
  }

  /// Indexa las entradas de Steam ya guardadas por su `storeGameID`.
  private static func indexarEntradasDeSteam(
    in context: ModelContext
  ) throws -> [String: StoreEntry] {
    let todas = try context.fetch(FetchDescriptor<StoreEntry>())

    return todas
      .filter { $0.store == .steam }
      .reduce(into: [String: StoreEntry]()) { indice, entrada in
        // Si hubiera duplicados por un fallo previo, gana el primero: asi la
        // sincronizacion no crea todavia mas copias.
        if indice[entrada.storeGameID] == nil {
          indice[entrada.storeGameID] = entrada
        }
      }
  }
}
