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
        .refreshable {
          await viewModel.sync(into: modelContext)
        }
        // Primera sincronizacion automatica: la biblioteca aparece sola al
        // abrir por primera vez, sin tener que tocar nada.
        .task {
          await viewModel.syncIfNeeded(into: modelContext)
        }
    }
  }

  @ViewBuilder
  private var contenido: some View {
    if games.isEmpty {
      estadoSinJuegos
    } else {
      listaDeJuegos
    }
  }

  // MARK: - Con juegos

  private var listaDeJuegos: some View {
    List {
      // Si la red falla pero hay datos guardados, se avisa sin tapar la
      // biblioteca: los datos viejos siguen siendo utiles.
      if case .failed(let mensaje, _) = viewModel.state {
        avisoDeFallo(mensaje)
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
        HStack {
          Text("\(games.count) juegos")
          Spacer()
          if let texto = textoUltimaSincronizacion {
            Text(texto)
              .textCase(nil)
          }
        }
      }
    }
    .listStyle(.plain)
  }

  private func avisoDeFallo(_ mensaje: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      VStack(alignment: .leading, spacing: 2) {
        Text(mensaje)
        Text("Estas viendo los datos guardados.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Reintentar") {
        Task { await viewModel.sync(into: modelContext) }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .font(.footnote)
    .listRowBackground(Color.orange.opacity(0.12))
    .accessibilityElement(children: .contain)
  }

  private var textoUltimaSincronizacion: String? {
    guard let fecha = viewModel.lastSyncedAt else { return nil }
    return "Actualizado \(LastPlayedFormatter.text(for: fecha).lowercased())"
  }

  // MARK: - Sin juegos

  @ViewBuilder
  private var estadoSinJuegos: some View {
    switch viewModel.state {
    case .syncing:
      ProgressView("Trayendo tu biblioteca…")
        .controlSize(.large)

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

    case .succeeded where viewModel.lastSyncReturnedNoGames:
      // Sincronizo bien pero Steam no devolvio nada. La causa mas comun es un
      // perfil privado, y la API no permite distinguirlo de una biblioteca
      // realmente vacia.
      ContentUnavailableView {
        Label("Steam no devolvio juegos", systemImage: "lock")
      } description: {
        Text(
          """
          La sincronizacion funciono, pero tu biblioteca llego vacia.

          Suele pasar cuando el perfil de Steam es privado. En Steam, revisa \
          Perfil > Editar perfil > Privacidad y deja "Detalles del juego" en \
          publico.
          """
        )
      } actions: {
        Button("Volver a intentar") {
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

// MARK: - Vistas previas

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

/// Servicio inerte para las vistas previas: no sale a la red.
private struct PreviewSteamService: SteamServicing {
  var error: Error?

  func fetchOwnedGames() async throws -> [SteamGameDTO] {
    if let error { throw error }
    return []
  }
}

/// UserDefaults aislado para que las vistas previas no toquen los del sistema.
@MainActor
private func defaultsDePrueba() -> UserDefaults {
  UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard
}

#Preview("Con juegos") {
  if let contenedor = contenedorDeEjemplo() {
    LibraryView(
      viewModel: LibraryViewModel(
        service: PreviewSteamService(),
        defaults: defaultsDePrueba()
      )
    )
    .modelContainer(contenedor)
  } else {
    Text("No se pudo crear el contenedor de ejemplo")
  }
}

#Preview("Vacia") {
  LibraryView(
    viewModel: LibraryViewModel(
      service: PreviewSteamService(),
      defaults: defaultsDePrueba()
    )
  )
  .modelContainer(for: [Game.self, StoreEntry.self], inMemory: true)
}

#Preview("Error de red") {
  LibraryView(
    viewModel: LibraryViewModel(
      service: PreviewSteamService(error: NetworkError.noConnection),
      defaults: defaultsDePrueba()
    )
  )
  .modelContainer(for: [Game.self, StoreEntry.self], inMemory: true)
}
