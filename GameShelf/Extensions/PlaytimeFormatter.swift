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
  static func short(hours: Double, locale: Locale = .current, bundle: Bundle = .main) -> String {
    let sinJugar = String(localized: "Sin jugar", bundle: bundle, comment: "Un juego con 0 horas")
    guard hours > 0 else { return sinJugar }

    let minutos = hours * 60
    if minutos < 1 {
      return sinJugar
    }

    if hours < 1 {
      return String(
        localized: "\(Int(minutos.rounded())) min",
        bundle: bundle,
        comment: "Tiempo jugado, abreviado en minutos"
      )
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
    return String(localized: "\(numero) h", bundle: bundle, comment: "Tiempo jugado, abreviado en horas")
  }

  /// Texto para leer en voz alta con VoiceOver.
  ///
  /// Lo que se lee mal de "1.404 h" es la abreviatura, no el numero: VoiceOver
  /// dice "hache". Esto dice "1.404 horas jugadas", que se lee entero.
  ///
  /// El separador de miles se deja: quitarlo obligaria a pasar el numero como
  /// texto, y entonces el catalogo ya no podria elegir singular o plural.
  static func accessible(hours: Double, bundle: Bundle = .main) -> String {
    guard hours > 0 else {
      return String(localized: "Sin jugar", bundle: bundle, comment: "Un juego con 0 horas")
    }

    let minutos = Int((hours * 60).rounded())
    if minutos < 60 {
      return String(
        localized: "\(minutos) minutos jugados",
        bundle: bundle,
        comment: "Tiempo jugado, para VoiceOver"
      )
    }

    let horasEnteras = Int(hours.rounded())
    return String(
      localized: "\(horasEnteras) horas jugadas",
      bundle: bundle,
      comment: "Tiempo jugado, para VoiceOver"
    )
  }
}
