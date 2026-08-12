//
//  SteamWishlistSyncer.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Guarda en la base local la lista de deseos que llega de Steam.
///
/// Como el de la biblioteca, es **idempotente**: correrlo dos veces con los
/// mismos datos deja la base igual.
///
/// La diferencia con `SteamLibrarySyncer` es que aca si hay que reflejar las
/// bajas. Si compras un juego, Steam lo saca de tu lista y la app tiene que
/// enterarse. Pero "sacarlo de la lista" **nunca** significa borrar el juego ni
/// cambiarte el estado que le pusiste: solo se limpia `wishlistedAt`, que es el
/// dato de la tienda.
struct SteamWishlistSyncer {

  /// Que cambio en una sincronizacion.
  struct Result: Equatable {
    /// Juegos que no existian y se crearon.
    var created: Int = 0
    /// Juegos que ya existian y se refrescaron.
    var updated: Int = 0
    /// Juegos que ya no estan en la lista de Steam.
    var removed: Int = 0

    var total: Int { created + updated }
  }

  /// Sincroniza la lista de deseos contra lo que ya hay guardado.
  ///
  /// - Parameters:
  ///   - juegos: Lo que devolvio Steam.
  ///   - context: Donde guardar.
  ///   - allowRemovals: Si se pueden quitar los que ya no vienen. Se pone en
  ///     `false` cuando la respuesta llego vacia y no se sabe si es porque la
  ///     lista esta vacia de verdad o porque es privada: en la duda, no se
  ///     toca nada.
  @discardableResult
  static func sync(
    _ juegos: [SteamWishlistGame],
    into context: ModelContext,
    allowRemovals: Bool = true
  ) throws -> Result {
    let existentes = try indexarEntradasDeSteam(in: context)
    var result = Result()

    for juego in juegos {
      let clave = String(juego.appID)

      if let entrada = existentes[clave], let game = entrada.game {
        SteamWishlistMapper.update(game, from: juego)
        result.updated += 1
      } else {
        context.insert(SteamWishlistMapper.makeGame(from: juego))
        result.created += 1
      }
    }

    if allowRemovals {
      result.removed = quitarLosQueYaNoEstan(juegos, de: existentes)
    }

    try context.save()
    return result
  }

  /// Limpia la marca de wishlist en los juegos que Steam ya no reporta.
  ///
  /// No borra nada ni cambia el estado: solo deja de decir "esto esta en tu
  /// lista de deseos de Steam", que es justo lo que dejo de ser cierto.
  private static func quitarLosQueYaNoEstan(
    _ juegos: [SteamWishlistGame],
    de existentes: [String: StoreEntry]
  ) -> Int {
    let vigentes = Set(juegos.map { String($0.appID) })
    var quitados = 0

    for (clave, entrada) in existentes
    where entrada.wishlistedAt != nil && !vigentes.contains(clave) {
      entrada.wishlistedAt = nil
      quitados += 1
    }

    return quitados
  }

  /// Indexa las entradas de Steam ya guardadas por su `storeGameID`.
  private static func indexarEntradasDeSteam(
    in context: ModelContext
  ) throws -> [String: StoreEntry] {
    let todas = try context.fetch(FetchDescriptor<StoreEntry>())

    return todas
      .filter { $0.store == .steam }
      .reduce(into: [String: StoreEntry]()) { indice, entrada in
        if indice[entrada.storeGameID] == nil {
          indice[entrada.storeGameID] = entrada
        }
      }
  }
}
