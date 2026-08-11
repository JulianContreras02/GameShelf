//
//  GameSortOrder.swift
//  GameShelf
//

import Foundation

/// Como se ordena la biblioteca.
///
/// Se guarda por su `rawValue` de texto para que agregar o reordenar casos no
/// invalide la preferencia que ya tiene guardada el usuario.
enum GameSortOrder: String, CaseIterable, Codable, Sendable {
  case nameAscending
  case playtimeDescending
  case playtimeAscending
  case lastPlayedDescending
  case releaseDateDescending
  case recentlyAdded

  static let `default` = GameSortOrder.nameAscending

  var displayName: String {
    switch self {
    case .nameAscending: "Nombre (A-Z)"
    case .playtimeDescending: "Mas jugados"
    case .playtimeAscending: "Menos jugados"
    case .lastPlayedDescending: "Jugados hace poco"
    case .releaseDateDescending: "Mas recientes"
    case .recentlyAdded: "Agregados hace poco"
    }
  }

  var symbolName: String {
    switch self {
    case .nameAscending: "textformat.abc"
    case .playtimeDescending: "clock.arrow.trianglehead.counterclockwise.rotate.90"
    case .playtimeAscending: "clock"
    case .lastPlayedDescending: "calendar.badge.clock"
    case .releaseDateDescending: "sparkles"
    case .recentlyAdded: "tray.and.arrow.down"
    }
  }

  /// Aviso cuando el orden no puede funcionar con los datos que hay.
  ///
  /// Hoy solo aplica a la fecha de lanzamiento: `GetOwnedGames` de Steam no la
  /// devuelve, asi que esta vacia en todos los juegos. Se deja el orden porque
  /// el dato puede llegar de otra API mas adelante, pero se avisa en vez de
  /// dejar al usuario preguntandose por que no pasa nada.
  var unavailableNote: String? {
    switch self {
    case .releaseDateDescending:
      "Steam no manda la fecha de lanzamiento, asi que este orden todavia no cambia nada."
    default:
      nil
    }
  }

  /// Ordena la lista.
  ///
  /// Los juegos sin el dato correspondiente van siempre al final, sin importar
  /// el orden: un juego sin fecha no es "el mas antiguo", es uno del que no se
  /// sabe.
  func sort(_ juegos: [Game]) -> [Game] {
    switch self {
    case .nameAscending:
      juegos.sorted { porNombre($0, $1) }

    case .playtimeDescending:
      juegos.sorted {
        $0.playtimeHours != $1.playtimeHours
          ? $0.playtimeHours > $1.playtimeHours
          : porNombre($0, $1)
      }

    case .playtimeAscending:
      juegos.sorted {
        $0.playtimeHours != $1.playtimeHours
          ? $0.playtimeHours < $1.playtimeHours
          : porNombre($0, $1)
      }

    case .lastPlayedDescending:
      ordenarPorFecha(juegos) { $0.lastPlayedAt }

    case .releaseDateDescending:
      ordenarPorFecha(juegos) { $0.releaseDate }

    case .recentlyAdded:
      juegos.sorted {
        $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : porNombre($0, $1)
      }
    }
  }

  /// Ordena de mas reciente a mas antiguo, dejando los que no tienen fecha al
  /// final y ordenados por nombre entre ellos.
  private func ordenarPorFecha(
    _ juegos: [Game],
    fecha: (Game) -> Date?
  ) -> [Game] {
    let conFecha = juegos.filter { fecha($0) != nil }
    let sinFecha = juegos.filter { fecha($0) == nil }

    let ordenados = conFecha.sorted {
      guard let primera = fecha($0), let segunda = fecha($1) else { return false }
      return primera != segunda ? primera > segunda : porNombre($0, $1)
    }

    return ordenados + sinFecha.sorted { porNombre($0, $1) }
  }

  private func porNombre(_ uno: Game, _ otro: Game) -> Bool {
    uno.name.localizedStandardCompare(otro.name) == .orderedAscending
  }
}
