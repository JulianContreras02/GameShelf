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
  @State private var agregandoAMano = false

  /// Los deseados, los mas recientes primero.
  ///
  /// Se ordena por cuando los deseaste, no alfabeticamente: lo ultimo que
  /// quisiste es lo que tienes mas presente. Los que agregaste a mano no traen
  /// fecha de Steam, asi que caen al final por nombre.
  private var juegos: [Game] {
    todos
      .filter { $0.status == .wishlist }
      .sorted { izq, der in
        switch (izq.wishlistedAt, der.wishlistedAt) {
        case let (fechaIzq?, fechaDer?): fechaIzq > fechaDer
        case (nil, _?): false
        case (_?, nil): true
        case (nil, nil): izq.name.localizedStandardCompare(der.name) == .orderedAscending
        }
      }
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
          Button("Sincronizar con Steam", systemImage: "arrow.clockwise", action: sincronizar)
            .disabled(viewModel.state.isSyncing)
          Button("Agregar a mano", systemImage: "plus") { agregandoAMano = true }
        } label: {
          Label("Opciones", systemImage: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $agregandoAMano) {
      WishlistManualAddView(viewModel: viewModel)
    }
    .refreshable { await viewModel.sync(into: modelContext) }
  }

  // MARK: - Lista

  private var lista: some View {
    List {
      if case .failed(let mensaje, let sugerencia) = viewModel.state {
        Section {
          AvisoDeFallo(mensaje: mensaje, sugerencia: sugerencia, alReintentar: sincronizar)
        }
      }

      Section {
        ForEach(juegos) { juego in
          NavigationLink {
            GameDetailView(game: juego)
          } label: {
            WishlistRow(game: juego)
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
          Text("\(juegos.count) juegos")
          if viewModel.state.isSyncing {
            Spacer()
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

  var body: some View {
    HStack(spacing: 12) {
      GameCover(urlString: game.coverImageURL)

      VStack(alignment: .leading, spacing: 4) {
        Text(game.name)
          .font(.headline)
          .lineLimit(2)

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
