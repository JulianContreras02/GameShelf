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
  @State private var modoSeleccion: EditMode = .inactive
  @State private var seleccionados: Set<UUID> = []
  @State private var agregandoAColeccion = false
  @State private var statusViewModel = GameStatusViewModel()
  @State private var busqueda = ""
  @State private var filtro = GameFilter()
  @State private var mostrandoFiltros = false
  @State private var preferencias = LibraryPreferences()

  /// Lo que hay que aplicar para obtener la lista que se ve.
  private var consulta: GameQuery {
    GameQuery(search: busqueda, filter: filtro, sort: preferencias.sortOrder)
  }

  /// Juegos que se muestran, ya buscados, filtrados y ordenados.
  private var juegosVisibles: [Game] {
    consulta.apply(to: games)
  }

  private var buscando: Bool {
    !busqueda.normalizedForSearch.isEmpty
  }

  init(viewModel: LibraryViewModel? = nil) {
    _viewModel = State(initialValue: viewModel ?? .live())
  }

  /// Los juegos marcados, resueltos desde sus identificadores.
  private var juegosSeleccionados: [Game] {
    games.filter { seleccionados.contains($0.id) }
  }

  var body: some View {
    NavigationStack {
      contenido
        .navigationTitle("Biblioteca")
        .environment(\.editMode, $modoSeleccion)
        .toolbar { barraDeHerramientas }
        .sheet(isPresented: $agregandoAColeccion) {
          BulkAddToCollectionView(juegos: juegosSeleccionados)
        }
        .sheet(isPresented: $mostrandoFiltros) {
          GameFiltersView(filter: $filtro, resultados: juegosVisibles.count)
        }
        // Al cambiar la busqueda se limpia la seleccion: si no, se podrian
        // mover juegos que ya no estan a la vista.
        .onChange(of: busqueda) { _, _ in
          if !seleccionados.isEmpty {
            seleccionados.removeAll()
          }
        }
        .onChange(of: agregandoAColeccion) { _, mostrando in
          // Al cerrar la hoja se sale del modo seleccion: dejarlo activo con
          // los mismos juegos marcados confunde sobre si ya se agregaron.
          if !mostrando {
            seleccionados.removeAll()
            modoSeleccion = .inactive
          }
        }
        .refreshable {
          await viewModel.sync(into: modelContext)
        }
        .searchable(
          text: $busqueda,
          placement: .navigationBarDrawer(displayMode: .automatic),
          prompt: "Buscar en tu biblioteca"
        )
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
      LibraryEmptyStateView(
        state: viewModel.state,
        syncReturnedNoGames: viewModel.lastSyncReturnedNoGames
      ) {
        Task { await viewModel.sync(into: modelContext) }
      }
    } else if juegosVisibles.isEmpty {
      // Hay juegos, pero ninguno coincide con la busqueda: es un caso distinto
      // de "todavia no tienes juegos" y merece su propio mensaje.
      sinResultados
    } else {
      listaDeJuegos
    }
  }

  private var sinResultados: some View {
    ContentUnavailableView {
      Label("Sin resultados", systemImage: "magnifyingglass")
    } description: {
      Text("Ningun juego coincide con \"\(busqueda)\".")
    } actions: {
      Button("Limpiar busqueda") { busqueda = "" }
        .buttonStyle(.bordered)
    }
  }

  // MARK: - Barra de herramientas

  @ToolbarContentBuilder
  private var barraDeHerramientas: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      if modoSeleccion.isEditing {
        Button("Listo") {
          seleccionados.removeAll()
          modoSeleccion = .inactive
        }
      } else if viewModel.state.isSyncing {
        ProgressView()
      } else {
        Button("Sincronizar", systemImage: "arrow.clockwise") {
          Task { await viewModel.sync(into: modelContext) }
        }
      }
    }

    if !games.isEmpty {
      ToolbarItem(placement: .topBarLeading) {
        if modoSeleccion.isEditing {
          Button("Agregar a coleccion", systemImage: "folder.badge.plus") {
            agregandoAColeccion = true
          }
          .disabled(seleccionados.isEmpty)
        } else {
          Menu {
            Section("Ordenar por") {
              Picker("Ordenar por", selection: $preferencias.sortOrder) {
                ForEach(GameSortOrder.allCases, id: \.self) { orden in
                  Label(orden.displayName, systemImage: orden.symbolName).tag(orden)
                }
              }
            }
            Divider()
            Button(textoBotonFiltrar, systemImage: "line.3.horizontal.decrease") {
              mostrandoFiltros = true
            }
            if filtro.isActive {
              Button("Quitar filtros", systemImage: "xmark.circle", role: .destructive) {
                filtro.clear()
              }
            }
            Button("Seleccionar juegos", systemImage: "checklist") {
              modoSeleccion = .active
            }
          } label: {
            Label("Opciones", systemImage: iconoDeOpciones)
          }
        }
      }
    }
  }

  // MARK: - Con juegos

  private var listaDeJuegos: some View {
    List(selection: $seleccionados) {
      // Si la red falla pero hay datos guardados, se avisa sin tapar la
      // biblioteca: los datos viejos siguen siendo utiles.
      if case .failed(let mensaje, _) = viewModel.state {
        avisoDeFallo(mensaje)
      }

      Section {
        ForEach(juegosVisibles) { game in
          NavigationLink {
            GameDetailView(game: game)
          } label: {
            GameRow(game: game)
          }
          .contextMenu {
            PlayStatusMenu(actual: game.status) { nuevo in
              cambiarEstado(de: game, a: nuevo)
            }
          }
        }
      } header: {
        HStack {
          Text(textoEncabezado)
          Spacer()
          if let texto = textoUltimaSincronizacion, !modoSeleccion.isEditing {
            Text(texto)
              .textCase(nil)
          }
        }
      }
    }
    .listStyle(.plain)
  }

  private var textoBotonFiltrar: String {
    filtro.isActive ? "Filtrar (\(filtro.activeCount))" : "Filtrar"
  }

  private var iconoDeOpciones: String {
    filtro.isActive
      ? "line.3.horizontal.decrease.circle.fill"
      : "line.3.horizontal.decrease.circle"
  }

  private var textoEncabezado: String {
    if modoSeleccion.isEditing {
      switch seleccionados.count {
      case 0: return "Selecciona juegos"
      case 1: return "1 seleccionado"
      default: return "\(seleccionados.count) seleccionados"
      }
    }

    // Con la lista recortada hay que decir cuantos se ven Y cuantos hay, o
    // parece que faltan juegos.
    guard consulta.isNarrowing else { return "\(games.count) juegos" }

    let visibles = juegosVisibles.count
    if buscando {
      return visibles == 1 ? "1 resultado" : "\(visibles) resultados"
    }
    return "\(visibles) de \(games.count) juegos"
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

  private func cambiarEstado(de juego: Game, a estado: PlayStatus) {
    // Un fallo al guardar el estado no merece tapar la pantalla: se ignora en
    // silencio porque el usuario ve que la etiqueta no cambio.
    try? statusViewModel.setStatus(estado, for: juego, in: modelContext)
  }

  private var textoUltimaSincronizacion: String? {
    guard let fecha = viewModel.lastSyncedAt else { return nil }
    return "Actualizado \(LastPlayedFormatter.text(for: fecha).lowercased())"
  }

}
