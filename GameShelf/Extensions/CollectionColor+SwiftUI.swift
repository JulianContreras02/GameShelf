//
//  CollectionColor+SwiftUI.swift
//  GameShelf
//

import SwiftUI

/// Traduccion del color de dominio al color de SwiftUI.
///
/// Vive aparte del modelo para que `CollectionColor` no dependa de SwiftUI:
/// asi se puede probar sin levantar interfaz.
extension CollectionColor {
  /// Color del sistema correspondiente.
  ///
  /// Se usan los colores estandar de Apple porque ya se adaptan a modo claro y
  /// oscuro y respetan los ajustes de contraste.
  var swiftUIColor: Color {
    switch self {
    case .blue: .blue
    case .green: .green
    case .orange: .orange
    case .pink: .pink
    case .purple: .purple
    case .red: .red
    case .teal: .teal
    case .yellow: .yellow
    case .gray: .gray
    }
  }
}
