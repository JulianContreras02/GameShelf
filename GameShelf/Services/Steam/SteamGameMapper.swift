//
//  SteamGameMapper.swift
//  GameShelf
//

import Foundation

/// Traduce los DTOs de Steam a los modelos de dominio.
///
/// Vive aparte del sincronizador a proposito: la traduccion es una funcion pura
/// sin base de datos de por medio, y eso la hace facil de probar.
enum SteamGameMapper {

  /// Nombre a usar cuando Steam no manda uno.
  ///
  /// Pasa cuando se consulta sin `include_appinfo=1`. Es preferible mostrar el
  /// appID a dejar la fila en blanco.
  static func fallbackName(for appID: Int) -> String {
    "Juego de Steam \(appID)"
  }

  /// Crea un `Game` nuevo con su `StoreEntry` de Steam.
  ///
  /// El `status` queda en `.backlog` y las notas vacias: son datos del usuario,
  /// no de Steam.
  static func makeGame(from dto: SteamGameDTO) -> Game {
    let game = Game(
      name: dto.name ?? fallbackName(for: dto.appID),
      coverImageURL: dto.coverURL?.absoluteString,
      playtimeHours: dto.playtimeHours
    )
    game.storeEntries = [makeStoreEntry(from: dto)]
    return game
  }

  /// Crea la entrada de tienda correspondiente al DTO.
  static func makeStoreEntry(from dto: SteamGameDTO) -> StoreEntry {
    StoreEntry(
      store: .steam,
      storeGameID: String(dto.appID),
      storeURL: dto.storeURL?.absoluteString,
      playtimeHours: dto.playtimeHours,
      recentPlaytimeHours: dto.playtimeLast2WeeksHours,
      lastPlayedAt: dto.lastPlayed,
      lastSyncedAt: Date()
    )
  }

  /// Actualiza un juego existente con datos frescos de Steam.
  ///
  /// **Solo toca lo que es de Steam.** Las notas, el estado y las colecciones
  /// son del usuario y no se sobrescriben nunca: esa es la regla mas
  /// importante de la sincronizacion.
  ///
  /// - Parameters:
  ///   - game: El juego guardado, que puede tener datos personales.
  ///   - dto: Lo que acaba de llegar de Steam.
  static func update(_ game: Game, from dto: SteamGameDTO) {
    // Datos de Steam: se refrescan
    if let nombre = dto.name {
      game.name = nombre
    }
    if let caratula = dto.coverURL?.absoluteString {
      game.coverImageURL = caratula
    }

    // La entrada de Steam se actualiza, o se crea si el juego ya existia por
    // otra tienda
    if let entrada = game.storeEntries.first(where: { $0.store == .steam }) {
      entrada.storeGameID = String(dto.appID)
      entrada.storeURL = dto.storeURL?.absoluteString
      entrada.playtimeHours = dto.playtimeHours
      entrada.recentPlaytimeHours = dto.playtimeLast2WeeksHours
      entrada.lastPlayedAt = dto.lastPlayed
      entrada.lastSyncedAt = Date()
    } else {
      game.storeEntries.append(makeStoreEntry(from: dto))
    }

    recalculatePlaytime(for: game)

    // game.notes, game.status y game.addedAt NO se tocan: son del usuario.
  }

  /// Recalcula las horas totales sumando todas las tiendas.
  ///
  /// Hace falta porque `Game.playtimeHours` es el total y cada `StoreEntry`
  /// lleva lo suyo: si solo se actualizara la entrada, el total quedaria viejo.
  static func recalculatePlaytime(for game: Game) {
    game.playtimeHours = game.storeEntries.reduce(0) { $0 + $1.playtimeHours }
  }
}
