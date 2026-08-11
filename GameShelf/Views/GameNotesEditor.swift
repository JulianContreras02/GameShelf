//
//  GameNotesEditor.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Editor de las notas de un juego.
///
/// No hay boton de guardar: el texto se guarda solo al cerrar la hoja y tambien
/// si la app pasa a segundo plano mientras se escribe. Las notas son lo unico
/// que no se puede recuperar sincronizando, asi que vale la pena guardarlas de
/// mas antes que perderlas.
struct GameNotesEditor: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase

  let juego: Game

  @State private var viewModel = GameNotesViewModel()
  @State private var texto = ""
  @State private var mensajeDeError: String?
  @FocusState private var escribiendo: Bool

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 0) {
        TextEditor(text: $texto)
          .focused($escribiendo)
          .scrollContentBackground(.hidden)
          .padding(.horizontal, 12)
          .padding(.top, 8)
          .overlay(alignment: .topLeading) {
            if texto.isEmpty {
              Text("Escribe lo que quieras recordar de este juego.")
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 17)
                .padding(.top, 16)
                .allowsHitTesting(false)
            }
          }

        pieDeTexto
      }
      .navigationTitle("Notas")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if !texto.isEmpty {
            Button("Borrar", role: .destructive) { texto = "" }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Listo") {
            guardar()
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
      .onAppear {
        texto = juego.notes
        escribiendo = true
      }
      // Guardado automatico: al cerrar la hoja...
      .onDisappear(perform: guardar)
      // ...y si la app se va a segundo plano mientras se escribe
      .onChange(of: scenePhase) { _, nueva in
        if nueva != .active { guardar() }
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
    }
  }

  @ViewBuilder
  private var pieDeTexto: some View {
    HStack {
      Text("Se guarda solo al salir.")
      Spacer()
      if GameNotesViewModel.shouldShowCounter(texto) {
        Text("\(texto.count) / \(GameNotesViewModel.maxLength)")
          .foregroundStyle(
            GameNotesViewModel.exceedsLimit(texto) ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary)
          )
          .monospacedDigit()
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private func guardar() {
    do {
      try viewModel.save(texto, for: juego, in: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

#Preview("Vacias") {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  if let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self, configurations: config
  ) {
    let juego = Game(name: "Hollow Knight")
    contenedor.mainContext.insert(juego)
    return AnyView(GameNotesEditor(juego: juego).modelContainer(contenedor))
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}

#Preview("Con texto") {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  if let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self, configurations: config
  ) {
    let juego = Game(name: "Elden Ring", notes: "Jefe pendiente: Malenia.\nProbar build de sangrado.")
    contenedor.mainContext.insert(juego)
    return AnyView(GameNotesEditor(juego: juego).modelContainer(contenedor))
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}
