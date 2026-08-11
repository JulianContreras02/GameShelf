//
//  PlaytimeFormatter.swift
//  GameShelf
//

import Foundation

/// Convierte horas jugadas en texto para mostrar.
///
/// Es logica y no presentacion, por eso vive aparte de las vistas y tiene
/// pruebas: "0.0 h" para un juego sin tocar, o "1404.5 h" sin separador de
/// miles, se leen mal.
enum PlaytimeFormatter {

  /// Texto corto para una lista.
  ///
  /// - Menos de 1 minuto: "Sin jugar"
  /// - Menos de 1 hora: "45 min"
  /// - Menos de 10 horas: "1,5 h"
  /// - Mas: "1.404 h", redondeado y con separador de miles
  static func short(hours: Double, locale: Locale = .current) -> String {
    guard hours > 0 else { return "Sin jugar" }

    let minutos = hours * 60
    if minutos < 1 {
      return "Sin jugar"
    }

    if hours < 1 {
      return "\(Int(minutos.rounded())) min"
    }

    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    // Por defecto NumberFormatter usa redondeo bancario (1404.5 -> 1404, al
    // par mas cercano). Se fija el redondeo normal para que el resultado sea
    // predecible y no dependa del valor que toque.
    formatter.roundingMode = .halfUp

    if hours < 10 {
      formatter.minimumFractionDigits = 1
      formatter.maximumFractionDigits = 1
    } else {
      formatter.maximumFractionDigits = 0
    }

    let numero = formatter.string(from: NSNumber(value: hours)) ?? "\(Int(hours))"
    return "\(numero) h"
  }

  /// Texto para leer en voz alta con VoiceOver.
  ///
  /// "1.404 h" se lee mal; esto dice "1404 horas jugadas".
  static func accessible(hours: Double) -> String {
    guard hours > 0 else { return "Sin jugar" }

    let minutos = Int((hours * 60).rounded())
    if minutos < 60 {
      return "\(minutos) \(minutos == 1 ? "minuto" : "minutos") jugados"
    }

    let horasEnteras = Int(hours.rounded())
    return "\(horasEnteras) \(horasEnteras == 1 ? "hora" : "horas") jugadas"
  }
}
