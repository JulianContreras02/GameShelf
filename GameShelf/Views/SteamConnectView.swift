//
//  SteamConnectView.swift
//  GameShelf
//

import SwiftUI

/// Conectar la cuenta de Steam con el SteamID64 y una API key propia.
///
/// A diferencia de PSN y Epic, Steam si ofrece un camino oficial y sencillo:
/// no hace falta iniciar sesion desde la app ni copiar un token de sesion,
/// solo dos datos publicos que la propia Steam entrega por cuenta.
struct SteamConnectView: View {
  @Environment(\.openURL) private var openURL

  let viewModel: SteamAccountViewModel

  @State private var steamID = ""
  @State private var apiKey = ""
  @State private var confirmandoDesconexion = false
  @FocusState private var campoActivo: Campo?

  private enum Campo {
    case steamID
    case apiKey
  }

  private var puedeConectar: Bool {
    !steamID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !viewModel.state.isWorking
  }

  var body: some View {
    Form {
      if viewModel.state.isConnected {
        seccionConectado
      } else {
        seccionInstrucciones
        seccionCredenciales
      }

      if case .fallo(let mensaje, let sugerencia) = viewModel.state {
        seccionAviso(mensaje, sugerencia)
      }
    }
    .navigationTitle("Steam")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Desconectar Steam",
      isPresented: $confirmandoDesconexion,
      titleVisibility: .visible
    ) {
      Button("Desconectar", role: .destructive) { viewModel.disconnect() }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("Se borran las credenciales del llavero. Tus juegos guardados no se tocan.")
    }
  }

  // MARK: - Ya conectado

  private var seccionConectado: some View {
    Section {
      Label("Cuenta conectada", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)

      Button("Desconectar", role: .destructive) { confirmandoDesconexion = true }
    } footer: {
      Text("La biblioteca y la lista de deseos se sincronizan desde sus propias pantallas.")
    }
  }

  // MARK: - Instrucciones

  private var seccionInstrucciones: some View {
    Section {
      Button("Sacar tu SteamID64", systemImage: "person.text.rectangle") {
        openURL(Self.steamIDURL)
      }
      Button("Sacar tu API key", systemImage: "key") {
        openURL(Self.apiKeyURL)
      }
    } header: {
      Text("Antes de conectar")
    } footer: {
      Text(
        """
        Los dos son gratis y quedan asociados a tu cuenta de Steam. Ninguno \
        sale de tu telefono: se guardan cifrados en el llavero.
        """
      )
    }
  }

  private var seccionCredenciales: some View {
    Section {
      TextField("SteamID64", text: $steamID)
        .keyboardType(.numberPad)
        .focused($campoActivo, equals: .steamID)
        .submitLabel(.next)
        .onSubmit { campoActivo = .apiKey }

      // Se marca como contrasena: la API key da acceso a datos de la cuenta y
      // no deberia quedar a la vista ni en el historial del teclado.
      SecureField("API key", text: $apiKey)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($campoActivo, equals: .apiKey)
        .submitLabel(.go)
        .onSubmit(conectar)

      Button(action: conectar) {
        if viewModel.state.isWorking {
          HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Conectando…")
          }
        } else {
          Text("Conectar")
        }
      }
      .disabled(!puedeConectar)
    }
  }

  private func seccionAviso(_ mensaje: String, _ sugerencia: String?) -> some View {
    Section {
      VStack(alignment: .leading, spacing: 4) {
        Label(mensaje, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
        if let sugerencia {
          Text(sugerencia)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)
    }
  }

  private func conectar() {
    guard puedeConectar else { return }
    campoActivo = nil

    Task {
      await viewModel.connect(steamID: steamID, apiKey: apiKey)
      if viewModel.state.isConnected {
        steamID = ""
        apiKey = ""
      }
    }
  }

  static let steamIDURL = URL(string: "https://steamid.io")!
  static let apiKeyURL = URL(string: "https://steamcommunity.com/dev/apikey")!
}

#Preview("Sin conectar") {
  NavigationStack {
    SteamConnectView(viewModel: SteamAccountViewModel(keychain: InMemoryKeychainStore()))
  }
}
