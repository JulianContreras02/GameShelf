//
//  CollectionDetailView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Los juegos que contiene una coleccion.
struct CollectionDetailView: View {
  @Environment(\.modelContext) private var modelContext

  let coleccion: GameCollection

  @State private var viewModel = CollectionsViewModel()
  @State private var editandoColeccion = false
  @State private var mensajeDeError: String?

  /// Ordenados por nombre. La relacion de SwiftData no garantiza ningun orden.
  private var juegos: [Game] {
    coleccion.games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  var body: some View {
    Group {
      if juegos.isEmpty {
        estadoVacio
      } else {
        lista
      }
    }
    .navigationTitle(coleccion.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Editar coleccion", systemImage: "pencil") { editandoColeccion = true }
      }
    }
    .sheet(isPresented: $editandoColeccion) {
      CollectionEditorView(coleccion: coleccion, viewModel: viewModel)
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

  private var lista: some View {
    List {
      Section {
        ForEach(juegos) { juego in
          NavigationLink {
            GameDetailView(game: juego)
          } label: {
            GameRow(game: juego)
          }
          .swipeActions(edge: .trailing) {
            // Quitar de la coleccion, no borrar el juego
            Button("Quitar", systemImage: "folder.badge.minus") {
              quitar(juego)
            }
            .tint(.orange)
          }
        }
      } header: {
        HStack {
          Text(textoCantidad)
          Spacer()
          Text(PlaytimeFormatter.short(hours: coleccion.totalPlaytimeHours))
            .textCase(nil)
        }
      } footer: {
        Text("Desliza un juego para quitarlo de la coleccion. Seguira en tu biblioteca.")
      }
    }
    .listStyle(.plain)
  }

  private var estadoVacio: some View {
    ContentUnavailableView {
      Label("Coleccion vacia", systemImage: coleccion.symbolName)
    } description: {
      Text(
        """
        Agrega juegos desde su ficha, o selecciona varios en la biblioteca \
        y muevelos aca de una vez.
        """
      )
    }
  }

  private var textoCantidad: String {
    switch juegos.count {
    case 1: "1 juego"
    default: "\(juegos.count) juegos"
    }
  }

  private func quitar(_ juego: Game) {
    do {
      try viewModel.remove([juego], from: coleccion, context: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  if let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, configurations: config
  ) {
    let coleccion = GameCollection(name: "Favoritos", symbolName: "star", color: .yellow)
    contenedor.mainContext.insert(coleccion)
    for nombre in ["Hollow Knight", "Celeste", "Hades"] {
      let juego = Game(name: nombre, playtimeHours: 12)
      contenedor.mainContext.insert(juego)
      coleccion.add(juego)
    }
    return AnyView(
      NavigationStack { CollectionDetailView(coleccion: coleccion) }
        .modelContainer(contenedor)
    )
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}
