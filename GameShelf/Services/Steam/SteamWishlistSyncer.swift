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
/// Tambien reconoce los juegos como el de la biblioteca, con `LibraryMatcher`:
/// por appID y, si no, por nombre. Asi un juego que ya vino de PlayStation o de
/// Epic, o que agregaste a mano, **no se duplica** al aparecer en tu lista de
/// deseos de Steam: suma su entrada de Steam, con `wishlistedAt`. Sin esto el
/// resultado dependia del orden: si la wishlist llegaba primero, PSN ya se unia
/// a ese juego, y si llegaba despues salian dos.
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
    /// Juegos que ya estaban por otra tienda, o a mano, y ahora tambien estan
    /// en la lista de deseos de Steam.
    var merged: Int = 0
    /// Juegos que ya no estan en la lista de Steam.
    var removed: Int = 0

    var total: Int { created + updated + merged }
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
    var matcher = try LibraryMatcher(store: .steam, context: context)
    var result = Result()

    for juego in juegos {
      switch matcher.buscar(storeGameID: String(juego.appID), nombre: juego.name) {
      case .mismaTienda(let existente):
        SteamWishlistMapper.update(existente, from: juego)
        result.updated += 1

      case .otraTienda(let existente) where !existente.isAvailable(on: .steam):
        // Lo tienes en otra tienda y lo deseas en Steam: es el mismo juego. Se
        // le suma la entrada sin tocar su estado, asi que si ya lo tienes no
        // pasa a la lista de deseos, que se guia por `status`.
        SteamWishlistMapper.update(existente, from: juego)
        result.merged += 1

      case .otraTienda, .nuevo:
        // Mismo criterio que la biblioteca: un juego con el mismo nombre que
        // ya tiene Steam es otro producto de Steam, con otro appID (Resident
        // Evil 4 y su remake), y unirlos pisaria la entrada del otro.
        let nuevo = SteamWishlistMapper.makeGame(from: juego)
        context.insert(nuevo)
        matcher.registrar(nuevo)
        result.created += 1
      }
    }

    if allowRemovals {
      result.removed = try quitarLosQueYaNoEstan(juegos, in: context)
    }

    try context.save()
    return result
  }

  /// Limpia la marca de wishlist en los juegos que Steam ya no reporta.
  ///
  /// No borra nada ni cambia el estado: solo deja de decir "esto esta en tu
  /// lista de deseos de Steam", que es justo lo que dejo de ser cierto. Una
  /// entrada que se sumo a un juego de otra tienda se limpia igual, y el juego
  /// queda con sus otras tiendas como estaba.
  private static func quitarLosQueYaNoEstan(
    _ juegos: [SteamWishlistGame],
    in context: ModelContext
  ) throws -> Int {
    let vigentes = Set(juegos.map { String($0.appID) })
    let quitadas = try context.fetch(FetchDescriptor<StoreEntry>()).filter { entrada in
      entrada.store == .steam && entrada.wishlistedAt != nil && !vigentes.contains(entrada.storeGameID)
    }

    for entrada in quitadas {
      entrada.wishlistedAt = nil
    }

    return quitadas.count
  }
}
