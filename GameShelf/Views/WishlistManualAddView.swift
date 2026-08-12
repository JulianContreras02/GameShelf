//
//  WishlistManualAddView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Agregar un juego a la lista de deseos escribiendo su nombre.
///
/// Es el respaldo que pide el issue: el endpoint de wishlist de Steam es
/// semi-oficial y ya cambio una vez, asi que la lista tiene que poder
/// mantenerse a mano si deja de responder. Tambien sirve para juegos que no
/// estan en Steam.
///
/// **Esto no toca la wishlist de Steam.** La API es de solo lectura: no hay
/// endpoint publico para escribir, y hacerlo exigiria la sesion de la tienda,
/// que la app no tiene ni deberia pedir. El juego queda solo en GameShelf, y
/// por eso la pantalla lo dice en vez de dejar que se asuma lo contrario.
struct WishlistManualAddView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let viewModel: WishlistViewModel

  @State private var nombre = ""
  @State private var mensajeDeError: String?
  @FocusState private var escribiendo: Bool

  private var puedeGuardar: Bool {
    !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Nombre del juego", text: $nombre)
            .focused($escribiendo)
            .submitLabel(.done)
            .onSubmit(guardar)
        } footer: {
          Text(
            """
            Queda solo en GameShelf: tu lista de deseos de Steam no cambia, \
            porque su API no deja escribir.

            Se agrega con estado "Lista de deseos", y puedes cambiarlo despues \
            desde su ficha.
            """
          )
        }
      }
      .navigationTitle("Agregar a la lista")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Agregar", action: guardar)
            .fontWeight(.semibold)
            .disabled(!puedeGuardar)
        }
      }
      .onAppear { escribiendo = true }
      .alert(
        "No se pudo agregar",
        isPresented: .init(
          get: { mensajeDeError != nil },
          set: { if !$0 { mensajeDeError = nil } }
        )
      ) {
        Button("Entendido", role: .cancel) {}
      } message: {
        Text(mensajeDeError ?? "")
      }
    }
  }

  private func guardar() {
    guard puedeGuardar else { return }

    do {
      try viewModel.addManually(name: nombre, in: modelContext)
      dismiss()
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}
