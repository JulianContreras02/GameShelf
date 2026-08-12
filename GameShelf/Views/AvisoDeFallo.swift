//
//  AvisoDeFallo.swift
//  GameShelf
//

import SwiftUI

/// Aviso de que la ultima sincronizacion fallo, para poner dentro de una lista.
///
/// Va como una fila mas y no como pantalla completa a proposito: si la red
/// falla pero hay datos guardados, esos datos siguen sirviendo y taparlos con
/// un error seria peor. Se avisa y se deja seguir.
struct AvisoDeFallo: View {
  let mensaje: String

  /// Que puede hacer el usuario, si aplica.
  var sugerencia: String?

  /// Que hacer al tocar "Reintentar". Sin esto no se muestra el boton.
  var alReintentar: (() -> Void)?

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)

      VStack(alignment: .leading, spacing: 2) {
        Text(mensaje)
        if let sugerencia {
          Text(sugerencia)
            .foregroundStyle(.secondary)
        } else {
          Text("Estas viendo los datos guardados.")
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      if let alReintentar {
        Button("Reintentar", action: alReintentar)
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
    .font(.footnote)
    .listRowBackground(Color.orange.opacity(0.12))
    .accessibilityElement(children: .contain)
  }
}
