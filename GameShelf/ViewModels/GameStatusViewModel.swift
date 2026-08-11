//
//  GameStatusViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Cambia el estado de progreso de los juegos y cuenta cuantos hay en cada uno.
///
/// El estado es un dato **del usuario**: no viene de Steam y ninguna
/// sincronizacion lo puede sobrescribir.
@Observable
@MainActor
final class GameStatusViewModel {

  init() {}

  // MARK: - Cambiar el estado

  /// Pone un estado nuevo a un juego.
  ///
  /// Si ya lo tenia, no guarda: evita escrituras y notificaciones inutiles a
  /// las vistas.
  ///
  /// - Returns: `true` si de verdad cambio.
  @discardableResult
  func setStatus(
    _ estado: PlayStatus,
    for juego: Game,
    in context: ModelContext
  ) throws -> Bool {
    guard juego.status != estado else { return false }

    juego.status = estado
    try context.save()
    return true
  }

  /// Pone el mismo estado a varios juegos de una vez.
  ///
  /// - Returns: Cuantos cambiaron de verdad.
  @discardableResult
  func setStatus(
    _ estado: PlayStatus,
    for juegos: [Game],
    in context: ModelContext
  ) throws -> Int {
    let porCambiar = juegos.filter { $0.status != estado }
    guard !porCambiar.isEmpty else { return 0 }

    for juego in porCambiar {
      juego.status = estado
    }
    try context.save()
    return porCambiar.count
  }

  // MARK: - Contar

  /// Cuantos juegos hay en cada estado.
  ///
  /// Devuelve **todos** los estados, incluso los que estan en cero: asi la
  /// pantalla no cambia de tamaño segun lo que haya.
  func counts(in context: ModelContext) throws -> [PlayStatus: Int] {
    let juegos = try context.fetch(FetchDescriptor<Game>())
    return Self.counts(for: juegos)
  }

  /// Version pura, para poder probar el conteo sin base de datos.
  ///
  /// `nonisolated` porque no toca nada del actor: solo transforma la lista que
  /// recibe. Asi se puede llamar desde cualquier contexto.
  nonisolated static func counts(for juegos: [Game]) -> [PlayStatus: Int] {
    var resultado = Dictionary(
      uniqueKeysWithValues: PlayStatus.allCases.map { ($0, 0) }
    )
    for juego in juegos {
      resultado[juego.status, default: 0] += 1
    }
    return resultado
  }

  /// Juegos de un estado, ordenados por nombre.
  ///
  /// `nonisolated` por lo mismo que `counts(for:)`: es una funcion pura.
  nonisolated static func games(_ juegos: [Game], with estado: PlayStatus) -> [Game] {
    juegos
      .filter { $0.status == estado }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
}
