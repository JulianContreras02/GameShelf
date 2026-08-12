//
//  LastPlayedFormatter.swift
//  GameShelf
//

import Foundation

/// Convierte la fecha de la ultima partida en texto para mostrar.
///
/// Va aparte de las vistas porque decide cosas: cuando decir "hoy", cuando
/// pasar a "hace 3 dias" y cuando mostrar la fecha completa. Eso es logica y
/// lleva pruebas.
enum LastPlayedFormatter {

  /// Texto para la ficha de un juego.
  ///
  /// - `nil` da "Nunca"
  /// - Hoy o ayer se dicen con palabras
  /// - Hasta 30 dias, en dias
  /// - Mas atras, la fecha
  static func text(
    for date: Date?,
    relativeTo referencia: Date = Date(),
    calendar: Calendar = .current,
    locale: Locale = .current,
    bundle: Bundle = .main
  ) -> String {
    guard let date else {
      return String(localized: "Nunca", bundle: bundle, comment: "Nunca se ha jugado")
    }

    // Se comparan dias de calendario contra `referencia`, no contra la fecha
    // del sistema: asi la funcion es predecible y se puede probar. Usar
    // isDateInToday aqui haria que el parametro `referencia` se ignorara.
    let dias = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: date),
      to: calendar.startOfDay(for: referencia)
    ).day ?? 0

    // Fechas futuras: puede pasar si el reloj del equipo esta desajustado.
    // Mejor decir "Hoy" que "hace -2 dias".
    if dias <= 0 { return String(localized: "Hoy", bundle: bundle, comment: "Ultima vez que se jugo") }
    if dias == 1 { return String(localized: "Ayer", bundle: bundle, comment: "Ultima vez que se jugo") }

    if dias <= 30 {
      return String(localized: "Hace \(dias) dias", bundle: bundle, comment: "Ultima vez que se jugo")
    }

    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
