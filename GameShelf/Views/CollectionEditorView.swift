//
//  CollectionEditorView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Formulario para crear o editar una coleccion.
///
/// Se usa el mismo para las dos cosas: cambian el titulo y el boton, no los
/// campos.
struct CollectionEditorView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  /// Coleccion a editar, o `nil` para crear una nueva.
  let coleccion: GameCollection?
  let viewModel: CollectionsViewModel

  @State private var nombre: String = ""
  @State private var simbolo: String = GameCollection.defaultSymbol
  @State private var color: CollectionColor = .default
  @State private var mensajeDeError: String?

  private var estaEditando: Bool { coleccion != nil }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Nombre", text: $nombre)
            .textInputAutocapitalization(.sentences)
            .onChange(of: nombre) { mensajeDeError = nil }

          if let mensajeDeError {
            Label(mensajeDeError, systemImage: "exclamationmark.circle")
              .foregroundStyle(.red)
              .font(.footnote)
          }
        } header: {
          Text("Nombre")
        } footer: {
          Text("Maximo \(CollectionsViewModel.maxNameLength) caracteres.")
        }

        Section("Icono") {
          selectorDeSimbolos
        }

        Section("Color") {
          selectorDeColores
        }

        Section {
          vistaPrevia
        } header: {
          Text("Asi se vera")
        }
      }
      .navigationTitle(estaEditando ? "Editar coleccion" : "Nueva coleccion")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(estaEditando ? "Guardar" : "Crear") { guardar() }
            .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .onAppear(perform: cargarValores)
    }
  }

  // MARK: - Partes

  private var selectorDeSimbolos: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
      ForEach(CollectionsViewModel.availableSymbols, id: \.self) { nombreSimbolo in
        Button {
          simbolo = nombreSimbolo
        } label: {
          Image(systemName: nombreSimbolo)
            .font(.title3)
            .frame(width: 44, height: 44)
            .background(
              simbolo == nombreSimbolo ? color.swiftUIColor.opacity(0.25) : Color.clear,
              in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(simbolo == nombreSimbolo ? color.swiftUIColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nombreSimbolo)
        .accessibilityAddTraits(simbolo == nombreSimbolo ? [.isSelected] : [])
      }
    }
    .padding(.vertical, 4)
  }

  private var selectorDeColores: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
      ForEach(CollectionColor.allCases, id: \.self) { opcion in
        Button {
          color = opcion
        } label: {
          Circle()
            .fill(opcion.swiftUIColor)
            .frame(width: 34, height: 34)
            .overlay {
              if color == opcion {
                Image(systemName: "checkmark")
                  .font(.caption.bold())
                  .foregroundStyle(.white)
              }
            }
        }
        .buttonStyle(.plain)
        // El color no se comunica solo con color: VoiceOver lee su nombre
        .accessibilityLabel(opcion.displayName)
        .accessibilityAddTraits(color == opcion ? [.isSelected] : [])
      }
    }
    .padding(.vertical, 4)
  }

  private var vistaPrevia: some View {
    Label {
      Text(nombre.isEmpty
        ? String(localized: "Nombre de la coleccion", comment: "Marcador en la vista previa")
        : nombre)
        .foregroundStyle(nombre.isEmpty ? .secondary : .primary)
    } icon: {
      Image(systemName: simbolo)
        .foregroundStyle(color.swiftUIColor)
    }
  }

  // MARK: - Acciones

  private func cargarValores() {
    guard let coleccion else { return }
    nombre = coleccion.name
    simbolo = coleccion.symbolName
    color = coleccion.color
  }

  private func guardar() {
    do {
      if let coleccion {
        try viewModel.rename(coleccion, to: nombre, in: modelContext)
        try viewModel.updateAppearance(
          coleccion,
          symbolName: simbolo,
          color: color,
          in: modelContext
        )
      } else {
        try viewModel.create(
          name: nombre,
          symbolName: simbolo,
          color: color,
          in: modelContext
        )
      }
      dismiss()
    } catch {
      // El error se muestra en el formulario, no se traga
      mensajeDeError = (error as? LocalizedError)?.errorDescription
        ?? error.localizedDescription
    }
  }
}

#Preview("Nueva") {
  CollectionEditorView(coleccion: nil, viewModel: CollectionsViewModel())
    .modelContainer(for: [Game.self, StoreEntry.self, GameCollection.self], inMemory: true)
}
