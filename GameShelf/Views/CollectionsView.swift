//
//  CollectionsView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Lista de colecciones, con crear, editar, borrar y reordenar.
struct CollectionsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \GameCollection.sortOrder) private var colecciones: [GameCollection]

  @State private var viewModel = CollectionsViewModel()
  @State private var mostrandoEditor = false
  @State private var coleccionEnEdicion: GameCollection?
  @State private var coleccionPorBorrar: GameCollection?
  @State private var mensajeDeError: String?
  @State private var modoReordenar: EditMode = .inactive

  var body: some View {
    NavigationStack {
      Group {
        if colecciones.isEmpty {
          estadoVacio
        } else {
          lista
        }
      }
      .navigationTitle("Colecciones")
      .environment(\.editMode, $modoReordenar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Nueva coleccion", systemImage: "plus") {
            coleccionEnEdicion = nil
            mostrandoEditor = true
          }
        }
        if colecciones.count > 1 {
          ToolbarItem(placement: .topBarLeading) {
            // Boton propio en vez de EditButton: ese usa el idioma del sistema
            // y salia "Edit" con el resto de la app en español.
            Button(modoReordenar.isEditing ? "Listo" : "Reordenar") {
              withAnimation {
                modoReordenar = modoReordenar.isEditing ? .inactive : .active
              }
            }
          }
        }
      }
      .sheet(isPresented: $mostrandoEditor) {
        CollectionEditorView(coleccion: coleccionEnEdicion, viewModel: viewModel)
      }
      // Confirmacion antes de borrar: es destructivo y no hay deshacer
      .confirmationDialog(
        "Borrar coleccion",
        isPresented: .init(
          get: { coleccionPorBorrar != nil },
          set: { if !$0 { coleccionPorBorrar = nil } }
        ),
        titleVisibility: .visible,
        presenting: coleccionPorBorrar
      ) { coleccion in
        Button("Borrar \"\(coleccion.name)\"", role: .destructive) {
          borrar(coleccion)
        }
        Button("Cancelar", role: .cancel) {}
      } message: { coleccion in
        Text(mensajeDeBorrado(for: coleccion))
      }
      .alert(
        "No se pudo completar",
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

  // MARK: - Partes

  private var lista: some View {
    List {
      ForEach(colecciones) { coleccion in
        NavigationLink {
          CollectionDetailView(coleccion: coleccion)
        } label: {
          fila(coleccion)
        }
        .swipeActions(edge: .trailing) {
          Button("Borrar", systemImage: "trash", role: .destructive) {
            coleccionPorBorrar = coleccion
          }
          Button("Editar", systemImage: "pencil") {
            coleccionEnEdicion = coleccion
            mostrandoEditor = true
          }
          .tint(.blue)
        }
      }
      .onMove(perform: mover)
    }
  }

  private func fila(_ coleccion: GameCollection) -> some View {
    HStack(spacing: 12) {
      Image(systemName: coleccion.symbolName)
        .font(.title3)
        .foregroundStyle(coleccion.color.swiftUIColor)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(coleccion.name)
        Text(textoCantidad(coleccion))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(coleccion.name), \(textoCantidad(coleccion))")
    .accessibilityHint("Toca para ver sus juegos")
  }

  private var estadoVacio: some View {
    ContentUnavailableView {
      Label("Sin colecciones", systemImage: "folder")
    } description: {
      Text("Agrupa tus juegos como quieras, sin importar de que tienda vengan.")
    } actions: {
      Button("Crear la primera") {
        coleccionEnEdicion = nil
        mostrandoEditor = true
      }
      .buttonStyle(.borderedProminent)
    }
  }

  // MARK: - Textos

  private func textoCantidad(_ coleccion: GameCollection) -> String {
    switch coleccion.gameCount {
    case 0: "Vacia"
    case 1: "1 juego"
    default: "\(coleccion.gameCount) juegos"
    }
  }

  private func mensajeDeBorrado(for coleccion: GameCollection) -> String {
    coleccion.isEmpty
      ? "Esta accion no se puede deshacer."
      : """
        Los \(coleccion.gameCount) juegos que contiene seguiran en tu biblioteca: \
        solo se deshace la agrupacion. Esta accion no se puede deshacer.
        """
  }

  // MARK: - Acciones

  private func borrar(_ coleccion: GameCollection) {
    do {
      try viewModel.delete(coleccion, in: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
    coleccionPorBorrar = nil
  }

  private func mover(from origen: IndexSet, to destino: Int) {
    do {
      try viewModel.move(colecciones, from: origen, to: destino, in: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

#Preview("Con colecciones") {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, configurations: config
  )

  struct Ejemplo {
    let nombre: String
    let simbolo: String
    let color: CollectionColor
  }

  if let contenedor {
    let ejemplos = [
      Ejemplo(nombre: "Favoritos", simbolo: "star", color: .yellow),
      Ejemplo(nombre: "Para el fin de semana", simbolo: "flame", color: .orange),
      Ejemplo(nombre: "Pendientes eternos", simbolo: "moon", color: .purple)
    ]
    for (indice, ejemplo) in ejemplos.enumerated() {
      contenedor.mainContext.insert(
        GameCollection(
          name: ejemplo.nombre,
          symbolName: ejemplo.simbolo,
          color: ejemplo.color,
          sortOrder: indice
        )
      )
    }
    return AnyView(CollectionsView().modelContainer(contenedor))
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}

#Preview("Vacia") {
  CollectionsView()
    .modelContainer(for: [Game.self, StoreEntry.self, GameCollection.self], inMemory: true)
}
