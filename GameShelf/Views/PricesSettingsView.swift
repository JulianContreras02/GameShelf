//
//  PricesSettingsView.swift
//  GameShelf
//

import SwiftUI

/// Pegar la API key de IsThereAnyDeal, la que trae los precios de la wishlist.
///
/// Mas simple que conectar una tienda: no hay usuario ni sesion, solo una
/// clave. Por eso no se verifica contra la red al guardarla, a diferencia de
/// Steam: si resulta invalida, la wishlist ya lo maneja mostrando la lista sin
/// precios en vez de romperse.
struct PricesSettingsView: View {
  @Environment(\.openURL) private var openURL

  let viewModel: ITADSettingsViewModel

  @State private var apiKey = ""
  @State private var confirmandoBorrado = false
  @FocusState private var escribiendo: Bool

  private var puedeGuardar: Bool {
    !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    Form {
      if viewModel.hasAPIKey {
        seccionGuardada
      } else {
        seccionInstrucciones
        seccionClave
      }
    }
    .navigationTitle("Ofertas y precios")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Borrar la clave",
      isPresented: $confirmandoBorrado,
      titleVisibility: .visible
    ) {
      Button("Borrar", role: .destructive) { viewModel.remove() }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("La wishlist se sigue viendo, solo que sin precios ni ofertas.")
    }
  }

  private var seccionGuardada: some View {
    Section {
      Label("Clave guardada", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)

      Button("Borrar", role: .destructive) { confirmandoBorrado = true }
    } footer: {
      Text("Los precios se traen solos al abrir la lista de deseos.")
    }
  }

  private var seccionInstrucciones: some View {
    Section {
      Button("Sacar tu API key", systemImage: "key") {
        openURL(Self.apiKeyURL)
      }
    } header: {
      Text("Antes de guardar")
    } footer: {
      Text(
        """
        Es gratis y no necesita crear cuenta. No sale de tu telefono: se \
        guarda cifrada en el llavero.
        """
      )
    }
  }

  private var seccionClave: some View {
    Section {
      SecureField("API key", text: $apiKey)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($escribiendo)
        .submitLabel(.done)
        .onSubmit(guardar)

      Button("Guardar", action: guardar)
        .disabled(!puedeGuardar)
    }
  }

  private func guardar() {
    guard puedeGuardar else { return }
    escribiendo = false
    viewModel.save(apiKey: apiKey)
    apiKey = ""
  }

  static let apiKeyURL = URL(string: "https://isthereanydeal.com/apps/my/")!
}

#Preview("Sin guardar") {
  NavigationStack {
    PricesSettingsView(viewModel: ITADSettingsViewModel(keychain: InMemoryKeychainStore()))
  }
}
