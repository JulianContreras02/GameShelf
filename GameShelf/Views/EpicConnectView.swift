//
//  EpicConnectView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Conectar la cuenta de Epic pegando un codigo de autorizacion.
///
/// Como PSN, Epic no ofrece un "iniciar sesion" para apps de terceros y hay
/// que copiar un codigo del navegador. A diferencia de PSN, **Epic avisa en esa
/// misma pagina de que el codigo da acceso completo a la cuenta**. Ese aviso se
/// repite aca: el usuario tiene que poder decidir con la informacion delante.
struct EpicConnectView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext

  let viewModel: EpicAccountViewModel

  @State private var codigo = ""
  @State private var confirmandoDesconexion = false
  @FocusState private var escribiendo: Bool

  private var puedeConectar: Bool {
    !codigo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.state.isWorking
  }

  var body: some View {
    Form {
      if viewModel.state.isConnected {
        seccionConectado
      } else {
        seccionAviso
        seccionInstrucciones
        seccionCodigo
      }

      if case .necesitaCodigoNuevo(let mensaje, let sugerencia) = viewModel.state {
        seccionError(mensaje, sugerencia, esGrave: true)
      }
      if case .fallo(let mensaje, let sugerencia) = viewModel.state {
        seccionError(mensaje, sugerencia, esGrave: false)
      }
    }
    .navigationTitle("Epic Games")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Desconectar Epic",
      isPresented: $confirmandoDesconexion,
      titleVisibility: .visible
    ) {
      Button("Desconectar", role: .destructive) { viewModel.disconnect() }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("Se borra el codigo del llavero. Tus juegos guardados no se tocan.")
    }
  }

  // MARK: - Aviso

  /// Lo que Epic dice en su propia pagina, dicho aca antes de empezar.
  private var seccionAviso: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        Label("Este codigo da acceso completo a tu cuenta", systemImage: "exclamationmark.shield.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.orange)

        Text(
          """
          Lo dice Epic en la pagina donde lo genera. Aca se guarda cifrado en el \
          llavero del telefono y no se manda a ningun servidor, pero conviene que \
          lo sepas: no lo pegues en ningun otro sitio.
          """
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Ya conectado

  private var seccionConectado: some View {
    Section {
      Label("Cuenta conectada", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)

      if let nombre = viewModel.displayName {
        LabeledContent("Cuenta") { Text(nombre) }
      }

      if let volver = viewModel.reconnectBy {
        LabeledContent("Volver a generar el codigo") {
          Text(volver, style: .relative)
        }
      }

      Button(action: sincronizar) {
        if viewModel.libraryState.isSyncing {
          HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Trayendo tus juegos…")
          }
        } else {
          Label("Traer mis juegos de Epic", systemImage: "arrow.down.circle")
        }
      }
      .disabled(viewModel.libraryState.isSyncing)

      if case .succeeded(let creados, let actualizados, let unidos) = viewModel.libraryState {
        Text(resumen(creados: creados, actualizados: actualizados, unidos: unidos))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if case .failed(let mensaje) = viewModel.libraryState {
        Label(mensaje, systemImage: "exclamationmark.triangle.fill")
          .font(.footnote)
          .foregroundStyle(.orange)
      }

      Button("Desconectar", role: .destructive) { confirmandoDesconexion = true }
    } footer: {
      Text("El acceso se renueva solo mientras uses la app.")
    }
  }

  // MARK: - Instrucciones

  private var seccionInstrucciones: some View {
    Section {
      Paso(numero: 1, texto: "Inicia sesion en Epic Games desde el navegador.")

      Button("1. Iniciar sesion en Epic", systemImage: "person.crop.circle") {
        openURL(EpicAuthService.loginURL)
      }

      Paso(numero: 2, texto: "Abre la pagina del codigo. Veras un texto largo tras \"authorizationCode\".")

      Button("2. Abrir la pagina del codigo", systemImage: "safari") {
        openURL(EpicAuthService.codeURL)
      }

      Paso(numero: 3, texto: "Copia solo lo que hay entre comillas y pegalo abajo, sin demorarte.")
    } header: {
      Text("Como obtener el codigo")
    } footer: {
      Text(
        """
        Si la pagina dice `"authorizationCode": null`, falta el paso 1.

        Los codigos de Epic caducan en segundos, asi que conviene pegarlo \
        enseguida. Si caduca, basta con recargar la pagina y copiar el nuevo.
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

  private func seccionError(_ mensaje: String, _ sugerencia: String?, esGrave: Bool) -> some View {
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

  private func sincronizar() {
    Task { await viewModel.syncLibrary(into: modelContext) }
  }

  /// Que cambio en la ultima sincronizacion.
  private func resumen(creados: Int, actualizados: Int, unidos: Int) -> String {
    var partes = [
      String(localized: "\(creados) juegos nuevos", comment: "Resultado de sincronizar con PSN"),
      String(localized: "\(actualizados) actualizados", comment: "Resultado de sincronizar con PSN")
    ]
    if unidos > 0 {
      partes.append(
        String(
          localized: "\(unidos) que ya tenias en otra tienda",
          comment: "Juegos que ya estaban y ahora tambien tienen PSN"
        )
      )
    }
    return partes.joined(separator: " · ")
  }

  private func conectar() {
    guard puedeConectar else { return }
    escribiendo = false

    Task {
      await viewModel.connect(authorizationCode: codigo)
      if viewModel.state.isConnected { codigo = "" }
    }
  }
}

/// Un paso numerado de las instrucciones.
///
/// Vive aca y no compartido con la pantalla de PlayStation porque son dos
/// flujos que pueden separarse: si Epic cambia el suyo, no deberia obligar a
/// tocar el de Sony.
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
    EpicConnectView(viewModel: EpicAccountViewModel(keychain: InMemoryKeychainStore()))
  }
}
