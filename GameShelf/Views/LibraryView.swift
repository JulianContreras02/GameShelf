//
//  LibraryView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Pantalla principal: la biblioteca de juegos.
///
/// Lee los juegos con `@Query`, que es una lectura simple y se refresca sola.
/// Todo lo que puede fallar (hablar con Steam, guardar) pasa por
/// `LibraryViewModel`. Ver `docs/decisiones/001-arquitectura.md`.
struct LibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Game.name) private var games: [Game]

  @State private var viewModel: LibraryViewModel

  init(viewModel: LibraryViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? .live())
  }

  var body: some View {
    NavigationStack {
      contenido
        .navigationTitle("Biblioteca")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            if viewModel.state.isSyncing {
              ProgressView()
            } else {
              Button("Sincronizar", systemImage: "arrow.clockwise") {
                Task { await viewModel.sync(into: modelContext) }
              }
            }
          }
        }
        // Deslizar hacia abajo para sincronizar
        .refreshable {
          await viewModel.sync(into: modelContext)
        }
    }
  }

  @ViewBuilder
  private var contenido: some View {
    if games.isEmpty {
      estadoVacio
    } else {
      List {
        if case .failed(let mensaje, _) = viewModel.state {
          // Ya hay juegos guardados: el fallo se avisa sin tapar la biblioteca
          Label(mensaje, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Section {
          ForEach(games) { game in
            NavigationLink {
              GameDetailView(game: game)
            } label: {
              GameRow(game: game)
            }
          }
        } header: {
          Text("\(games.count) juegos")
        }
      }
      .listStyle(.plain)
    }
  }

  @ViewBuilder
  private var estadoVacio: some View {
    switch viewModel.state {
    case .syncing:
      ProgressView("Trayendo tu biblioteca…")

    case .failed(let mensaje, let sugerencia):
      ContentUnavailableView {
        Label("No se pudo sincronizar", systemImage: "exclamationmark.triangle")
      } description: {
        Text([mensaje, sugerencia].compactMap { $0 }.joined(separator: "\n\n"))
      } actions: {
        Button("Reintentar") {
          Task { await viewModel.sync(into: modelContext) }
        }
        .buttonStyle(.borderedProminent)
      }

    case .idle, .succeeded:
      ContentUnavailableView {
        Label("Sin juegos todavia", systemImage: "gamecontroller")
      } description: {
        Text("Trae tu biblioteca de Steam para empezar.")
      } actions: {
        Button("Sincronizar con Steam") {
          Task { await viewModel.sync(into: modelContext) }
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}

/// Contenedor en memoria con juegos de ejemplo, solo para las vistas previas.
@MainActor
private func contenedorDeEjemplo() -> ModelContainer? {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  guard let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, configurations: config
  ) else {
    return nil
  }

  struct Ejemplo {
    let nombre: String
    let horas: Double
    let appID: String
  }

  let ejemplos = [
    Ejemplo(nombre: "Red Dead Redemption 2", horas: 227.9, appID: "1174180"),
    Ejemplo(nombre: "Hollow Knight", horas: 1.5, appID: "367520"),
    Ejemplo(nombre: "Un juego sin jugar", horas: 0, appID: "413150")
  ]

  for ejemplo in ejemplos {
    let juego = Game(
      name: ejemplo.nombre,
      coverImageURL:
        "https://cdn.cloudflare.steamstatic.com/steam/apps/\(ejemplo.appID)/header.jpg",
      playtimeHours: ejemplo.horas
    )
    juego.storeEntries = [StoreEntry(store: .steam, storeGameID: ejemplo.appID)]
    contenedor.mainContext.insert(juego)
  }

  return contenedor
}

#Preview("Con juegos") {
  if let contenedor = contenedorDeEjemplo() {
    LibraryView(viewModel: LibraryViewModel(service: PreviewSteamService()))
      .modelContainer(contenedor)
  } else {
    Text("No se pudo crear el contenedor de ejemplo")
  }
}

#Preview("Vacia") {
  LibraryView(viewModel: LibraryViewModel(service: PreviewSteamService()))
    .modelContainer(
      for: [Game.self, StoreEntry.self],
      inMemory: true
    )
}

/// Servicio inerte para las vistas previas: no sale a la red.
private struct PreviewSteamService: SteamServicing {
  func fetchOwnedGames() async throws -> [SteamGameDTO] { [] }
}
