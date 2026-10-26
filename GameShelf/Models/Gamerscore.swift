//
//  Gamerscore.swift
//  GameShelf
//

import Foundation

/// El Gamerscore de un juego de Xbox: cuantos puntos llevas de cuantos tiene.
///
/// No se reusa `TrophyCounts` porque no se parecen: en Xbox no hay tipos de
/// logro, cada uno vale una cantidad de puntos distinta. Lo que el usuario
/// reconoce es "465 de 1300", no cuantos bronces lleva.
nonisolated struct Gamerscore: Hashable, Sendable {
  /// Puntos conseguidos.
  var earned: Int

  /// Puntos que tiene el juego en total.
  var total: Int

  /// Que parte se consiguio, de 0 a 100.
  ///
  /// Es la misma cuenta que hace Xbox en su `progressPercentage`: 465 de 1300
  /// da 36. Se calcula en vez de guardarse para que no pueda contradecir a los
  /// dos numeros de los que sale.
  var progress: Int {
    guard total > 0 else { return 0 }
    return Int((Double(earned) / Double(total) * 100).rounded())
  }

  /// Si ya se consiguieron todos los puntos.
  var isComplete: Bool {
    total > 0 && earned >= total
  }
}
