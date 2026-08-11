//
//  RootView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Contenedor principal con las secciones de la app.
///
/// Se separa de `LibraryView` para que agregar secciones (ajustes,
/// estadisticas, lista de deseos) no obligue a tocar la biblioteca.
struct RootView: View {
  var body: some View {
    TabView {
      Tab("Biblioteca", systemImage: "square.grid.2x2") {
        LibraryView()
      }

      Tab("Progreso", systemImage: "chart.bar") {
        GameProgressView()
      }

      Tab("Colecciones", systemImage: "folder") {
        CollectionsView()
      }
    }
  }
}

#Preview {
  RootView()
    .modelContainer(for: [Game.self, StoreEntry.self, GameCollection.self], inMemory: true)
}
