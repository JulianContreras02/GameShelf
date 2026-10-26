//
//  PlaySessionTracker.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Empieza y termina sesiones de juego, con las reglas que valen para toda la
/// app.
///
/// Trabaja directo sobre el `ModelContext` y no detras de un ViewModel porque
/// no la va a usar solo la app: el boton "Terminar" de la Live Activity corre
/// en el proceso del widget, y tiene que seguir exactamente las mismas reglas
/// sin pasar por la pantalla.
enum PlaySessionTracker {

  /// La sesion activa, si hay una.
  ///
  /// Se traen todas y se filtra en memoria, igual que en `LibraryMatcher`: son
  /// pocas filas, y asi la regla se puede probar sin depender de un
  /// predicado.
  static func activeSession(in context: ModelContext) throws -> PlaySession? {
    try context.fetch(FetchDescriptor<PlaySession>()).first(where: \.isActive)
  }

  /// Empieza una sesion de `game`.
  ///
  /// - Throws: `PlaySessionError.yaHayUnaActiva` si ya hay una sesion activa,
  ///   de este juego o de cualquier otro. No puede haber dos a la vez en toda
  ///   la app: nadie juega a dos cosas al mismo tiempo, y dos sesiones
  ///   abiertas sumarian el doble de horas.
  @discardableResult
  static func start(_ game: Game, at fecha: Date = Date.now, in context: ModelContext) throws -> PlaySession {
    if let activa = try activeSession(in: context) {
      throw PlaySessionError.yaHayUnaActiva(juego: activa.game?.name)
    }

    let sesion = PlaySession(startDate: fecha)
    context.insert(sesion)
    game.playSessions.append(sesion)

    try context.save()
    return sesion
  }

  /// Termina una sesion y suma su duracion a las horas del juego.
  ///
  /// - Throws: `PlaySessionError.finAntesDelInicio` o `.yaTerminada`. Si
  ///   falla, ni la sesion ni las horas del juego cambian.
  static func end(_ sesion: PlaySession, at fecha: Date = Date.now, in context: ModelContext) throws {
    try sesion.end(at: fecha)

    if let juego = sesion.game {
      SteamGameMapper.recalculatePlaytime(for: juego)
    }

    try context.save()
  }
}
