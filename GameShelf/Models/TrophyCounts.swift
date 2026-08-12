//
//  TrophyCounts.swift
//  GameShelf
//

import Foundation

/// Cuantos trofeos hay de cada tipo.
///
/// Se guarda como un valor y no como cuatro campos sueltos en `StoreEntry`
/// porque los cuatro van siempre juntos: sumarlos, compararlos o mostrarlos
/// por separado no tiene sentido.
struct TrophyCounts: Codable, Hashable, Sendable {
  var bronze: Int = 0
  var silver: Int = 0
  var gold: Int = 0
  var platinum: Int = 0

  var total: Int { bronze + silver + gold + platinum }

  var isEmpty: Bool { total == 0 }

  /// Cuantos hay de un tipo concreto.
  func count(of tipo: TrophyKind) -> Int {
    switch tipo {
    case .bronze: bronze
    case .silver: silver
    case .gold: gold
    case .platinum: platinum
    }
  }
}

/// El desglose de trofeos de un juego: cuantos tiene, cuantos llevas y que
/// porcentaje representa eso.
///
/// Los tres van juntos porque salen de la **misma** lista de trofeos. Un juego
/// puede tener dos (la de PS4 y la de PS5), y mezclar el porcentaje de una con
/// los conteos de la otra ensenaria dos numeros que se contradicen.
struct TrophyBreakdown: Hashable, Sendable {
  /// Cuantos se consiguieron.
  var earned: TrophyCounts

  /// Cuantos tiene el juego en total.
  var defined: TrophyCounts

  /// Porcentaje conseguido, tal como lo reporta la tienda. `nil` si no lo dice.
  var progress: Int?
}

/// Los tipos de trofeo de PlayStation.
///
/// El orden es el de la propia consola: de mas comun a mas dificil, con el
/// platino al final porque solo se consigue al tener todos los demas.
enum TrophyKind: String, CaseIterable, Sendable {
  case bronze
  case silver
  case gold
  case platinum

  var displayName: String {
    switch self {
    case .bronze: String(localized: "Bronce", comment: "Tipo de trofeo")
    case .silver: String(localized: "Plata", comment: "Tipo de trofeo")
    case .gold: String(localized: "Oro", comment: "Tipo de trofeo")
    case .platinum: String(localized: "Platino", comment: "Tipo de trofeo")
    }
  }

  /// Que hay que hacer para conseguirlo, cuando no es obvio.
  ///
  /// Solo el platino la lleva: los otros tres se entienden solos.
  var explanation: String? {
    switch self {
    case .platinum:
      String(
        localized: "El platino se consigue al completar todos los demas trofeos del juego.",
        comment: "Que es el trofeo de platino"
      )
    case .bronze, .silver, .gold:
      nil
    }
  }
}
