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
  nonisolated struct Result: Equatable {
    /// Juegos que no existian y se crearon.
    var created: Int = 0
    /// Juegos que ya existian y se refrescaron.
    var updated: Int = 0
    /// Juegos que ya estaban por otra tienda y ahora tambien tienen Steam.
    var merged: Int = 0

    var total: Int { created + updated + merged }
  }

  /// Sincroniza la lista de Steam contra lo que ya hay guardado.
  ///
  /// Un juego se reconoce por su `StoreEntry` de Steam, con el mismo `appID`.
  /// Si no lo tiene, se busca por nombre: asi un juego que ya vino de
  /// PlayStation o de Epic **no se duplica**, sino que suma su entrada de Steam.
  ///
  /// Los juegos guardados que ya no vienen en la respuesta **no se borran**:
  /// pueden faltar porque la peticion fallo a medias o porque Steam los omitio,
  /// y borrar la biblioteca del usuario por eso seria mucho peor que dejar un
  /// juego de mas.
  ///
  /// - Returns: Cuantos se crearon, cuantos se actualizaron y cuantos se
  ///   unieron a un juego de otra tienda.
  @discardableResult
  static func sync(
    _ dtos: [SteamGameDTO],
    into context: ModelContext
  ) throws -> Result {
    guard !dtos.isEmpty else { return Result() }

    var matcher = try LibraryMatcher(store: .steam, context: context)
    var result = Result()

    for dto in dtos {
      let nombre = dto.name ?? SteamGameMapper.fallbackName(for: dto.appID)

      switch matcher.buscar(storeGameID: String(dto.appID), nombre: nombre) {
      case .mismaTienda(let existente):
        SteamGameMapper.update(existente, from: dto)
        result.updated += 1

      case .otraTienda(let existente) where !existente.isAvailable(on: .steam):
        SteamGameMapper.update(existente, from: dto)
        result.merged += 1

      case .otraTienda, .nuevo:
        // Un juego con el mismo nombre que ya tiene Steam es otro producto de
        // Steam: Resident Evil 4 de 2005 y su remake de 2023 se llaman igual y
        // tienen appID distinto. A diferencia de PSN, que lista la version de
        // consola y la de PC del mismo juego, en Steam cada appID es un juego
        // aparte, asi que se guarda aparte en vez de pisar la entrada del otro.
        let nuevo = SteamGameMapper.makeGame(from: dto)
        context.insert(nuevo)
        matcher.registrar(nuevo)
        result.created += 1
      }
    }

    try context.save()
    return result
  }
}
