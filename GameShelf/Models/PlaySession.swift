//
//  PlaySession.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Un rato jugando a un juego, registrado desde la app.
///
/// Mientras esta activa no tiene `endDate`. Las reglas que la cruzan con el
/// resto de la app (que no haya dos activas a la vez, que al cerrarla sume sus
/// horas al juego) viven en `PlaySessionTracker`; aca solo esta lo que depende
/// de la propia sesion.
@Model
final class PlaySession {
  var id: UUID = UUID()

  /// Cuando empezo.
  private(set) var startDate: Date = Date()

  /// Cuando termino. `nil` mientras sigue activa.
  ///
  /// Solo se escribe desde `end(at:)`, que comprueba que no quede antes del
  /// inicio: un `endDate` suelto podria romper esa regla sin que nadie lo
  /// notara.
  private(set) var endDate: Date?

  /// Juego al que pertenece. La relacion inversa esta en `Game.playSessions`.
  var game: Game?

  init(startDate: Date = Date()) {
    self.id = UUID()
    self.startDate = startDate
    self.endDate = nil
  }

  /// Si todavia no termino.
  var isActive: Bool { endDate == nil }

  /// Cuanto dura, o cuanto lleva si sigue activa.
  var duration: TimeInterval { duration(at: Date.now) }

  /// Cuanto dura, contando hasta `ahora` si sigue activa.
  ///
  /// Nunca es negativa. Si el reloj del telefono se atraso mientras la sesion
  /// estaba activa, `ahora` puede quedar antes del inicio: se cuenta como cero
  /// en vez de restarle tiempo al juego.
  func duration(at ahora: Date) -> TimeInterval {
    max(0, (endDate ?? ahora).timeIntervalSince(startDate))
  }

  /// Cierra la sesion.
  ///
  /// - Throws: `PlaySessionError.yaTerminada` si ya estaba cerrada,
  ///   `.finAntesDelInicio` si `fecha` es anterior al inicio. En los dos casos
  ///   la sesion queda como estaba.
  func end(at fecha: Date) throws {
    guard isActive else { throw PlaySessionError.yaTerminada }
    guard fecha >= startDate else { throw PlaySessionError.finAntesDelInicio }
    endDate = fecha
  }
}

/// Por que no se pudo empezar o terminar una sesion.
enum PlaySessionError: LocalizedError, Equatable {
  /// Ya hay otra sesion activa, de este juego o de otro.
  case yaHayUnaActiva(juego: String?)

  /// La fecha de fin es anterior a la de inicio.
  case finAntesDelInicio

  /// La sesion ya estaba cerrada.
  case yaTerminada

  var errorDescription: String? {
    switch self {
    case .yaHayUnaActiva(let juego?):
      String(
        localized: "Ya estas jugando a \(juego). Termina esa sesion antes de empezar otra.",
        comment: "Error al empezar una sesion con otra activa"
      )
    case .yaHayUnaActiva(nil):
      String(
        localized: "Ya hay una sesion activa. Terminala antes de empezar otra.",
        comment: "Error al empezar una sesion con otra activa, sin saber de que juego"
      )
    case .finAntesDelInicio:
      String(
        localized: "La sesion no puede terminar antes de empezar.",
        comment: "Error al cerrar una sesion con una fecha invalida"
      )
    case .yaTerminada:
      String(localized: "Esa sesion ya estaba terminada.", comment: "Error al cerrar una sesion dos veces")
    }
  }
}
