//
//  GameTagsEditor.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Editor de etiquetas de un juego, con autocompletado.
///
/// Se escribe y se sugiere lo que ya existe, para no terminar con "coop",
/// "co-op" y "cooperativo" como tres etiquetas distintas.
struct GameTagsEditor: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \GameTag.name) private var todasLasEtiquetas: [GameTag]

  let juego: Game

  @State private var viewModel = TagsViewModel()
  @State private var texto = ""
  @State private var mensajeDeError: String?
  @FocusState private var campoEnfocado: Bool

  var body: some View {
    NavigationStack {
      List {
        seccionPuestas
        seccionSugerencias
      }
      .navigationTitle("Etiquetas")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Listo") { dismiss() }
        }
      }
      .alert(
        "No se pudo guardar",
        isPresented: .init(
          get: { mensajeDeError != nil },
          set: { if !$0 { mensajeDeError = nil } }
        )
      ) {
        Button("Entendido", role: .cancel) {}
      } message: {
        Text(mensajeDeError ?? "")
      }
      .onAppear { campoEnfocado = true }
    }
  }

  // MARK: - Secciones

  private var seccionPuestas: some View {
    Section {
      TextField("Escribe una etiqueta", text: $texto)
        .focused($campoEnfocado)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .onSubmit(agregarLoEscrito)

      if !juego.tags.isEmpty {
        FlowLayout(spacing: 8) {
          ForEach(etiquetasOrdenadas) { etiqueta in
            Button {
              quitar(etiqueta)
            } label: {
              HStack(spacing: 4) {
                Text(etiqueta.name)
                Image(systemName: "xmark.circle.fill")
                  .font(.caption2)
              }
              .font(.caption.weight(.medium))
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(.tint.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Etiqueta \(etiqueta.name)")
            .accessibilityHint("Toca para quitarla de este juego")
          }
        }
        .padding(.vertical, 4)
      }
    } header: {
      Text(juego.tags.isEmpty ? "Sin etiquetas" : "Etiquetas de este juego")
    } footer: {
      Text("Maximo \(GameTag.maxNameLength) caracteres. Toca una etiqueta para quitarla.")
    }
  }

  @ViewBuilder
  private var seccionSugerencias: some View {
    let sugerencias = TagsViewModel.suggestions(
      for: texto,
      from: todasLasEtiquetas,
      excluding: juego.tags
    )
    let esNueva = TagsViewModel.wouldCreateNew(texto, among: todasLasEtiquetas)

    if esNueva || !sugerencias.isEmpty {
      Section {
        // Crear la que se esta escribiendo, si no existe ya
        if esNueva {
          Button {
            agregarLoEscrito()
          } label: {
            Label {
              Text("Crear \"\(GameTag.clean(texto))\"")
            } icon: {
              Image(systemName: "plus.circle.fill")
            }
          }
        }

        ForEach(sugerencias) { etiqueta in
          Button {
            agregar(etiqueta)
          } label: {
            HStack {
              Label(etiqueta.name, systemImage: "tag")
                .foregroundStyle(.primary)
              Spacer()
              Text(textoUso(etiqueta))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      } header: {
        Text(texto.isEmpty ? "Etiquetas que ya usas" : "Sugerencias")
      }
    }
  }

  // MARK: - Apoyo

  private var etiquetasOrdenadas: [GameTag] {
    juego.tags.sorted { $0.normalized < $1.normalized }
  }

  private func textoUso(_ etiqueta: GameTag) -> String {
    etiqueta.gameCount == 1 ? "1 juego" : "\(etiqueta.gameCount) juegos"
  }

  // MARK: - Acciones

  private func agregarLoEscrito() {
    let porAgregar = texto
    guard !GameTag.clean(porAgregar).isEmpty else { return }

    do {
      try viewModel.addTag(named: porAgregar, to: juego, in: modelContext)
      texto = ""
    } catch {
      mensajeDeError = (error as? LocalizedError)?.errorDescription
        ?? error.localizedDescription
    }
  }

  private func agregar(_ etiqueta: GameTag) {
    do {
      try viewModel.addTag(named: etiqueta.name, to: juego, in: modelContext)
      texto = ""
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }

  private func quitar(_ etiqueta: GameTag) {
    do {
      try viewModel.removeTag(etiqueta, from: juego, in: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  if let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self, configurations: config
  ) {
    let juego = Game(name: "Hollow Knight")
    contenedor.mainContext.insert(juego)
    for nombre in ["metroidvania", "dificil", "coop", "indie"] {
      contenedor.mainContext.insert(GameTag(name: nombre))
    }
    return AnyView(GameTagsEditor(juego: juego).modelContainer(contenedor))
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}
