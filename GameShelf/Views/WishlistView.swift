//
//  WishlistView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Lista de deseos: lo que quieres y todavia no tienes.
///
/// Muestra los juegos con `status == .wishlist`, vengan de Steam o los hayas
/// agregado a mano. Ese es el criterio a proposito: el estado lo pones tu, y
/// una lista de deseos que ignore tu decision no serviria de nada.
struct WishlistView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var todos: [Game]

  @State private var viewModel = WishlistViewModel.live()
  @State private var preferencias = WishlistPreferences()
  @State private var agregandoAMano = false

  /// Los deseados, en el orden elegido.
  private var juegos: [Game] {
    preferencias.sortOrder.sort(
      todos.filter { $0.status == .wishlist },
      precios: viewModel.prices
    )
  }

  var body: some View {
    Group {
      if juegos.isEmpty {
        WishlistEmptyStateView(
          state: viewModel.state,
          devolvioListaVacia: viewModel.lastSyncReturnedNoGames,
          alSincronizar: sincronizar,
          alAgregarAMano: { agregandoAMano = true }
        )
      } else {
        lista
      }
    }
    .navigationTitle("Lista de deseos")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Picker("Ordenar por", selection: $preferencias.sortOrder) {
            ForEach(WishlistSortOrder.allCases, id: \.self) { orden in
              Label(orden.displayName, systemImage: orden.symbolName).tag(orden)
            }
          }

          Divider()

          Button("Sincronizar con Steam", systemImage: "arrow.clockwise", action: sincronizar)
            .disabled(viewModel.state.isSyncing)
          Button("Actualizar precios", systemImage: "tag", action: cargarPrecios)
            .disabled(viewModel.pricesState.isLoading)
          Button("Agregar a mano", systemImage: "plus") { agregandoAMano = true }
        } label: {
          Label("Opciones", systemImage: "ellipsis.circle")
        }
      }
    }
    .task(id: juegos.count) {
      await viewModel.loadPrices(for: juegos)
    }
    .sheet(isPresented: $agregandoAMano) {
      WishlistManualAddView(viewModel: viewModel)
    }
    .refreshable {
      await viewModel.sync(into: modelContext)
      await viewModel.loadPrices(for: juegos)
    }
  }

  // MARK: - Lista

  private var lista: some View {
    List {
      if case .failed(let mensaje, let sugerencia) = viewModel.state {
        Section {
          AvisoDeFallo(mensaje: mensaje, sugerencia: sugerencia, alReintentar: sincronizar)
        }
      }

      // Que fallen los precios no impide ver la lista: se avisa y ya.
      if case .failed(let mensaje) = viewModel.pricesState {
        Section {
          AvisoDeFallo(
            mensaje: mensaje,
            sugerencia: String(
              localized: "La lista se ve igual, solo sin los precios.",
              comment: "Aviso cuando no se pudieron traer los precios"
            ),
            alReintentar: cargarPrecios
          )
        }
      }

      Section {
        ForEach(juegos) { juego in
          NavigationLink {
            GameDetailView(game: juego)
          } label: {
            WishlistRow(game: juego, prices: viewModel.prices(for: juego))
          }
          .swipeActions(edge: .trailing) {
            // Solo los agregados a mano: los de Steam volverian en la
            // siguiente sincronizacion.
            if WishlistViewModel.canDelete(juego) {
              Button("Borrar", systemImage: "trash", role: .destructive) {
                borrar(juego)
              }
            }
          }
        }
      } header: {
        HStack {
          Text(encabezado)
          Spacer()
          if viewModel.state.isSyncing || viewModel.pricesState.isLoading {
            ProgressView().controlSize(.small)
          }
        }
      } footer: {
        Text(pie)
      }
    }
    .listStyle(.plain)
  }

  private var pie: String {
    if viewModel.lastSyncReturnedNoGames {
      return String(
        localized: """
          Steam no devolvio nada en la ultima sincronizacion, asi que se dejo la \
          lista como estaba.
          """,
        comment: "Aviso cuando la wishlist llego vacia"
      )
    }
    if juegos.contains(where: { WishlistViewModel.canDelete($0) }) {
      return String(
        localized: """
          Los que agregaste a mano se borran deslizando. Los de Steam se quitan \
          en Steam: cuando compras uno, deja de aparecer aca.
          """,
        comment: "Como se mantiene la lista de deseos"
      )
    }
    return String(
      localized: "Cuando compras un juego, Steam lo saca de la lista y aca deja de aparecer.",
      comment: "Como se mantiene la lista de deseos"
    )
  }

  /// Cuantos juegos hay y, si aplica, cuantos estan en su minimo historico.
  private var encabezado: String {
    let enMinimo = viewModel.countAtHistoricalLow(among: juegos)
    guard enMinimo > 0 else {
      return String(localized: "\(juegos.count) juegos", comment: "Cuantos juegos hay")
    }
    return String(
      localized: "\(juegos.count) juegos · \(enMinimo) en minimo historico",
      comment: "Cuantos juegos hay y cuantos estan al precio mas bajo de su historia"
    )
  }

  private func cargarPrecios() {
    Task { await viewModel.loadPrices(for: juegos) }
  }

  private func borrar(_ juego: Game) {
    try? viewModel.delete(juego, in: modelContext)
  }

  private func sincronizar() {
    Task { await viewModel.sync(into: modelContext) }
  }
}

/// Una fila de la lista de deseos.
///
/// No se reusa `GameRow` porque aca sobra lo que esa muestra (las horas
/// jugadas, que siempre son cero) y falta lo que importa: si el juego ya salio.
struct WishlistRow: View {
  let game: Game

  /// Precios, si ya se consultaron. `nil` mientras cargan o si no se pudieron
  /// traer: la fila se ve igual, solo sin la linea del precio.
  var prices: GamePrices?

  var body: some View {
    HStack(spacing: 12) {
      GameCover(urlString: game.coverImageURL)

      VStack(alignment: .leading, spacing: 4) {
        Text(game.name)
          .font(.headline)
          .lineLimit(2)

        if let prices {
          WishlistPriceLabel(prices: prices)
        }

        if let detalle {
          Text(detalle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(detalle.map { "\(game.name), \($0)" } ?? game.name)
  }

  /// Segunda linea: si no ha salido lo dice, y si no, desde cuando lo quieres.
  private var detalle: String? {
    if game.isComingSoon {
      return String(localized: "Todavia no sale", comment: "Juego sin lanzar")
    }
    guard let deseado = game.wishlistedAt else { return nil }
    return String(
      localized: "Lo quieres desde \(LastPlayedFormatter.text(for: deseado).lowercased())",
      comment: "Desde cuando esta en la lista de deseos"
    )
  }
}
