//
//  ContentView.swift
//  GameShelf
//
//  Created by Julian Contreras on 10/08/26.
//

import SwiftData
import SwiftUI

/// Pantalla provisional que lista la biblioteca.
///
/// La vista real de biblioteca llega en el issue #10. Por ahora solo confirma
/// que el modelo funciona de punta a punta.
struct ContentView: View {
  // Lectura directa con @Query: es una lectura simple, sin logica que probar.
  // Ver docs/decisiones/001-arquitectura.md
  @Query(sort: \Game.name) private var games: [Game]

  var body: some View {
    NavigationStack {
      Group {
        if games.isEmpty {
          ContentUnavailableView(
            "Sin juegos todavia",
            systemImage: "gamecontroller",
            description: Text("Cuando conectes Steam, tu biblioteca aparece aca.")
          )
        } else {
          List(games) { game in
            VStack(alignment: .leading, spacing: 4) {
              Text(game.name)
                .font(.headline)
              Text(game.stores.map(\.displayName).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("Biblioteca")
    }
  }
}

#Preview {
  ContentView()
    .modelContainer(for: Game.self, inMemory: true)
}
