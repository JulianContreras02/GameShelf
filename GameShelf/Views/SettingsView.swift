//
//  SettingsView.swift
//  GameShelf
//

import SwiftUI

/// Ajustes de la app. Por ahora, las cuentas conectadas.
struct SettingsView: View {
  @State private var psn = PSNAccountViewModel()
  @State private var epic = EpicAccountViewModel()

  var body: some View {
    NavigationStack {
      List {
        Section {
          FilaDeTienda(
            nombre: "Steam",
            simbolo: "gamecontroller",
            detalle: String(
              localized: "Se configura con las claves del proyecto",
              comment: "Como se conecta Steam"
            ),
            conectado: true
          )

          NavigationLink {
            PSNConnectView(viewModel: psn)
          } label: {
            FilaDeTienda(
              nombre: "PlayStation Network",
              simbolo: "playstation.logo",
              detalle: detallePSN,
              conectado: psn.state.isConnected
            )
          }
          NavigationLink {
            EpicConnectView(viewModel: epic)
          } label: {
            FilaDeTienda(
              nombre: "Epic Games",
              simbolo: "gamecontroller.fill",
              detalle: detalleEpic,
              conectado: epic.state.isConnected
            )
          }
        } header: {
          Text("Cuentas")
        } footer: {
          Text("Los codigos de acceso se guardan en el llavero del sistema, cifrados.")
        }
      }
      .navigationTitle("Ajustes")
    }
  }

  private var detalleEpic: String {
    switch epic.state {
    case .conectado:
      epic.displayName ?? String(localized: "Conectado", comment: "Estado de una cuenta")
    case .necesitaCodigoNuevo:
      String(localized: "Hay que volver a conectarla", comment: "Estado de una cuenta")
    case .trabajando:
      String(localized: "Conectando…", comment: "Estado de una cuenta")
    case .desconectado, .fallo:
      String(localized: "Sin conectar", comment: "Estado de una cuenta")
    }
  }

  private var detallePSN: String {
    switch psn.state {
    case .conectado:
      String(localized: "Conectado", comment: "Estado de una cuenta")
    case .necesitaTokenNuevo:
      String(localized: "Hay que volver a conectarla", comment: "Estado de una cuenta")
    case .trabajando:
      String(localized: "Conectando…", comment: "Estado de una cuenta")
    case .desconectado, .fallo:
      String(localized: "Sin conectar", comment: "Estado de una cuenta")
    }
  }
}

/// Una fila de cuenta, con su estado.
private struct FilaDeTienda: View {
  let nombre: String
  let simbolo: String
  let detalle: String
  let conectado: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: simbolo)
        .font(.title3)
        .foregroundStyle(conectado ? Color.green : Color.secondary)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(nombre)
        Text(detalle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(nombre): \(detalle)")
  }
}
