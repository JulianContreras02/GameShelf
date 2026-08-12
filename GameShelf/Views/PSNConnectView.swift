//
//  PSNConnectView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Conectar la cuenta de PlayStation pegando el codigo NPSSO.
///
/// Sony no ofrece un "iniciar sesion con PlayStation" para apps de terceros, asi
/// que el unico camino es que el usuario copie ese codigo desde el navegador
/// con su sesion ya iniciada. La pantalla existe sobre todo para explicar eso
/// bien: es un paso raro y sin instrucciones claras no hay forma de adivinarlo.
struct PSNConnectView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext

  let viewModel: PSNAccountViewModel

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
        seccionInstrucciones
        seccionCodigo
      }

      if case .necesitaTokenNuevo(let mensaje, let sugerencia) = viewModel.state {
        seccionAviso(mensaje, sugerencia, esGrave: true)
      }
      if case .fallo(let mensaje, let sugerencia) = viewModel.state {
        seccionAviso(mensaje, sugerencia, esGrave: false)
      }
    }
    .navigationTitle("PlayStation")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Desconectar PlayStation",
      isPresented: $confirmandoDesconexion,
      titleVisibility: .visible
    ) {
      Button("Desconectar", role: .destructive) { viewModel.disconnect() }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("Se borra el codigo del llavero. Tus juegos guardados no se tocan.")
    }
  }

  // MARK: - Ya conectado

  private var seccionConectado: some View {
    Section {
      Label("Cuenta conectada", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)

      // Solo se muestra la fecha que exige hacer algo. La del token de acceso
      // es de una hora y se renueva sola: ponerla aqui solo preocupa.
      if let volver = viewModel.reconnectBy {
        LabeledContent("Volver a copiar el codigo") {
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
          Label("Traer mis juegos de PlayStation", systemImage: "arrow.down.circle")
        }
      }
      .disabled(viewModel.libraryState.isSyncing)

      if case .succeeded(let creados, let actualizados, let unidos) = viewModel.libraryState {
        Text(resumen(creados: creados, actualizados: actualizados, unidos: unidos))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if case .failed(let mensaje, _) = viewModel.libraryState {
        Label(mensaje, systemImage: "exclamationmark.triangle.fill")
          .font(.footnote)
          .foregroundStyle(.orange)
      }

      Button("Desconectar", role: .destructive) { confirmandoDesconexion = true }
    } footer: {
      Text(
        """
        No hay que hacer nada mientras tanto: el acceso se renueva solo. Cuando \
        Sony deje de aceptarlo, la app te lo dice aca y solo hay que repetir \
        los tres pasos.
        """
      )
    }
  }

  // MARK: - Instrucciones

  private var seccionInstrucciones: some View {
    Section {
      Paso(numero: 1, texto: "Abre PlayStation y toca \"Iniciar sesion\". Este paso no se puede saltar.")

      Button("1. Abrir PlayStation e iniciar sesion", systemImage: "person.crop.circle") {
        openURL(PSNAuthService.signInURL)
      }

      Paso(numero: 2, texto: "Vuelve aca y abre la pagina del codigo. Veras un texto corto entre comillas.")

      Button("2. Abrir la pagina del codigo", systemImage: "safari") {
        openURL(PSNAuthService.npssoURL)
      }

      Paso(numero: 3, texto: "Copia solo lo que hay entre las comillas y pegalo abajo.")
    } header: {
      Text("Como obtener el codigo")
    } footer: {
      Text(
        """
        Los dos pasos tienen que ser en el **mismo navegador**: lo que \
        comparten es la sesion. Si la pagina del codigo dice "Invalid login", \
        es que falta el paso 1.

        Sony no ofrece un boton de "conectar" para apps de otros, asi que este \
        rodeo es el unico camino. El codigo se guarda cifrado en el llavero del \
        telefono y no sale de aca.
        """
      )
    }
  }

  private var seccionCodigo: some View {
    Section {
      // Se marca como contrasena: es un token de sesion de la cuenta de Sony,
      // no algo que deba quedar a la vista ni en el historial del teclado.
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

  private func sincronizar() {
    Task { await viewModel.syncLibrary(into: modelContext) }
  }

  /// Que cambio en la ultima sincronizacion.
  private func resumen(creados: Int, actualizados: Int, unidos: Int) -> String {
    var partes = [
      String(localized: "\(creados) juegos nuevos", comment: "Resultado de sincronizar con PSN"),
      String(localized: "\(actualizados) actualizados", comment: "Resultado de sincronizar con PSN")
    ]

    // Los unidos solo se mencionan si los hubo: es un concepto que no hace
    // falta explicar cuando no aplica.
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
      await viewModel.connect(npsso: codigo)
      if viewModel.state.isConnected { codigo = "" }
    }
  }
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
    PSNConnectView(viewModel: PSNAccountViewModel(keychain: InMemoryKeychainStore()))
  }
}
