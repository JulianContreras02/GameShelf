//
//  XboxConnectView.swift
//  GameShelf
//

import SwiftUI

/// Conectar la cuenta de Xbox: primero la app de Azure, despues la sesion.
///
/// Microsoft no ofrece un client publico para apps de terceros como si hacen
/// PSN y Epic con los suyos, asi que el usuario tiene que registrar su propia
/// app en Azure antes de poder conectar nada. Por eso esta pantalla tiene dos
/// partes independientes en vez de un solo flujo.
struct XboxConnectView: View {
  @Environment(\.openURL) private var openURL

  let viewModel: XboxAccountViewModel

  @State private var clientID = ""
  @State private var clientSecret = ""
  @State private var codigo = ""
  @State private var confirmandoDesconexion = false
  @FocusState private var escribiendo: Bool

  private var puedeGuardarApp: Bool {
    !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var puedeConectar: Bool {
    !codigo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && viewModel.hasAppCredentials
      && !viewModel.state.isWorking
  }

  var body: some View {
    Form {
      seccionApp

      if viewModel.state.isConnected {
        seccionConectado
      } else {
        seccionInstrucciones
        seccionCodigo
      }

      if case .necesitaCodigoNuevo(let mensaje, let sugerencia) = viewModel.state {
        seccionAviso(mensaje, sugerencia, esGrave: true)
      }
      if case .fallo(let mensaje, let sugerencia) = viewModel.state {
        seccionAviso(mensaje, sugerencia, esGrave: false)
      }
    }
    .navigationTitle("Xbox")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Desconectar Xbox",
      isPresented: $confirmandoDesconexion,
      titleVisibility: .visible
    ) {
      Button("Desconectar", role: .destructive) { viewModel.disconnect() }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("Se borra la sesion del llavero. Tu app de Azure y tus juegos guardados no se tocan.")
    }
  }

  // MARK: - App de Azure

  private var seccionApp: some View {
    Section {
      Button("Abrir portal.azure.com", systemImage: "safari") {
        openURL(Self.azurePortalURL)
      }

      TextField("Client ID", text: $clientID)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($escribiendo)

      SecureField("Client secret", text: $clientSecret)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($escribiendo)

      Button("Guardar app") { guardarApp() }
        .disabled(!puedeGuardarApp)

      if viewModel.hasAppCredentials {
        Label("App guardada", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
    } header: {
      Text("Tu app de Azure")
    } footer: {
      Text(
        """
        Microsoft no deja usar una app compartida como con PlayStation o Epic: \
        hay que registrar una propia, una sola vez. En "App registrations", \
        cuentas personales, con http://localhost/auth/callback como Redirect \
        URI de tipo Web, y un client secret nuevo en "Certificates & secrets". \
        El paso a paso completo esta en el README.
        """
      )
    }
  }

  // MARK: - Ya conectado

  private var seccionConectado: some View {
    Section {
      Label("Cuenta conectada", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)

      if let gamertag = viewModel.gamertag {
        LabeledContent("Gamertag") { Text(gamertag) }
      }

      Button("Desconectar", role: .destructive) { confirmandoDesconexion = true }
    } footer: {
      Text("No hay que hacer nada mientras tanto: el acceso se renueva solo.")
    }
  }

  // MARK: - Instrucciones

  private var seccionInstrucciones: some View {
    Section {
      Paso(numero: 1, texto: "Con la app de Azure ya guardada arriba, abre la pagina de inicio de sesion.")

      if let url = urlDeAutorizacion {
        Button("1. Iniciar sesion con Microsoft", systemImage: "person.crop.circle") {
          openURL(url)
        }
      }

      Paso(numero: 2, texto: "Inicia sesion y autoriza la app. Que falle al llegar a localhost es lo esperado.")

      Paso(numero: 3, texto: "Copia lo que hay tras \"code=\" en la barra de direcciones y pegalo abajo.")
    } header: {
      Text("Como obtener el codigo")
    } footer: {
      Text(
        """
        Que la pagina no cargue al final es normal: nada escucha en \
        localhost. El codigo ya esta en la direccion, no en la pagina.
        """
      )
    }
  }

  private var seccionCodigo: some View {
    Section {
      SecureField("Pega el codigo aca", text: $codigo)
        .focused($escribiendo)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
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

  private func seccionAviso(_ mensaje: String, _ sugerencia: String?, esGrave: Bool) -> some View {
    Section {
      VStack(alignment: .leading, spacing: 4) {
        Label(mensaje, systemImage: esGrave ? "exclamationmark.triangle.fill" : "info.circle")
          .foregroundStyle(esGrave ? Color.orange : Color.secondary)
        if let sugerencia {
          Text(sugerencia)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)
    }
  }

  private var urlDeAutorizacion: URL? {
    guard let id = viewModel.savedClientID else { return nil }
    return XboxAuthService.authorizeURL(clientID: id)
  }

  private func guardarApp() {
    guard puedeGuardarApp else { return }
    viewModel.saveAppCredentials(clientID: clientID, clientSecret: clientSecret)
    clientID = ""
    clientSecret = ""
  }

  private func conectar() {
    guard puedeConectar else { return }
    escribiendo = false

    Task {
      await viewModel.connect(authorizationCode: codigo)
      if viewModel.state.isConnected { codigo = "" }
    }
  }

  static let azurePortalURL = URL(string: "https://portal.azure.com")!
}

/// Un paso numerado de las instrucciones.
private struct Paso: View {
  let numero: Int
  let texto: LocalizedStringKey

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(verbatim: "\(numero)")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 20, height: 20)
        .background(Color.accentColor, in: Circle())

      Text(texto)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("Sin conectar") {
  NavigationStack {
    XboxConnectView(viewModel: XboxAccountViewModel(keychain: InMemoryKeychainStore()))
  }
}
