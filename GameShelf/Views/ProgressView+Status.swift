//
//  ProgressView+Status.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Resumen del progreso: cuantos juegos hay en cada estado, y acceso a cada
/// lista.
///
/// Cubre dos criterios del issue a la vez: el contador por estado y la vista
/// dedicada de pendientes, que es una de las listas de aca.
struct GameProgressView: View {
  @Query private var juegos: [Game]

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(PlayStatus.displayOrder, id: \.self) { estado in
            NavigationLink {
              // La lista de deseos tiene pantalla propia: sincroniza con Steam
              // y deja agregar juegos a mano, cosa que los demas estados no
              // necesitan.
              if estado == .wishlist {
                WishlistView()
              } else {
                StatusGamesView(status: estado)
              }
            } label: {
              fila(estado)
            }
          }
        } header: {
          Text("\(juegos.count) juegos en total")
        } footer: {
          Text("El estado lo pones tu: ninguna sincronizacion con Steam lo cambia.")
        }

        Section {
          NavigationLink {
            LibraryInsightsView()
          } label: {
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text("Analisis de la biblioteca")
                Text("Que juegas, que no, y donde se va tu tiempo")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            } icon: {
              Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(.tint)
            }
          }
        } footer: {
          Text("Se calcula solo, con las horas que reporta cada tienda.")
        }
      }
      .navigationTitle("Progreso")
    }
  }

  private var conteos: [PlayStatus: Int] {
    GameStatusViewModel.counts(for: juegos)
  }

  private func fila(_ estado: PlayStatus) -> some View {
    let cantidad = conteos[estado] ?? 0

    return HStack(spacing: 12) {
      Image(systemName: estado.symbolName)
        .font(.title3)
        .foregroundStyle(estado.tint)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(estado.displayName)
        Text(estado.explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text("\(cantidad)")
        .font(.headline)
        .foregroundStyle(cantidad == 0 ? .tertiary : .primary)
        .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(estado.displayName), \(cantidad) juegos")
    .accessibilityHint(estado.explanation)
  }
}

/// Los juegos que estan en un estado concreto.
struct StatusGamesView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Game.name) private var todos: [Game]

  let status: PlayStatus

  @State private var viewModel = GameStatusViewModel()
  @State private var mensajeDeError: String?

  private var juegos: [Game] {
    GameStatusViewModel.games(todos, with: status)
  }

  var body: some View {
    Group {
      if juegos.isEmpty {
        estadoVacio
      } else {
        lista
      }
    }
    .navigationTitle(status.displayName)
    .navigationBarTitleDisplayMode(.inline)
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
          .contextMenu {
            PlayStatusMenu(actual: juego.status) { nuevo in
              cambiar(juego, a: nuevo)
            }
          }
        }
      } header: {
        Text("\(juegos.count) juegos")
      } footer: {
        Text("Manten pulsado un juego para cambiarle el estado.")
      }
    }
    .listStyle(.plain)
  }

  private var estadoVacio: some View {
    ContentUnavailableView {
      Label("Nada en \(status.displayName.lowercased())", systemImage: status.symbolName)
    } description: {
      Text(status.explanation + ". Marca juegos con este estado desde su ficha.")
    }
  }

  private func cambiar(_ juego: Game, a estado: PlayStatus) {
    do {
      try viewModel.setStatus(estado, for: juego, in: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

#Preview("Progreso") {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  if let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, configurations: config
  ) {
    let ejemplos: [(String, PlayStatus)] = [
      ("Jugando ahora", .playing),
      ("Pendiente uno", .backlog),
      ("Pendiente dos", .backlog),
      ("Ya terminado", .finished)
    ]
    for (nombre, estado) in ejemplos {
      let juego = Game(name: nombre, playtimeHours: 5)
      juego.status = estado
      contenedor.mainContext.insert(juego)
    }
    return AnyView(GameProgressView().modelContainer(contenedor))
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}
