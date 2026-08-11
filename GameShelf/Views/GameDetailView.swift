//
//  GameDetailView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Ficha de un juego.
///
/// Solo muestra: no llama a servicios ni sincroniza. Las secciones de estado,
/// colecciones y notas quedan reservadas para los issues #16, #15 y #20.
struct GameDetailView: View {
  let game: Game

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        caratula
        encabezado
        Divider()
        datos
        if let enlace = game.storeLink() {
          botonTienda(enlace)
        }
        Divider()
        proximamente
      }
      .padding()
    }
    .navigationTitle(game.name)
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Partes

  private var caratula: some View {
    GameCoverLarge(urlString: game.coverImageURL)
      .frame(maxWidth: .infinity)
  }

  private var encabezado: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(game.name)
        .font(.title2.bold())
        // Permite que crezca con Dynamic Type en vez de recortarse
        .fixedSize(horizontal: false, vertical: true)

      if !game.stores.isEmpty {
        HStack(spacing: 6) {
          ForEach(game.stores, id: \.self) { store in
            Text(store.displayName)
              .font(.caption.weight(.medium))
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(.quaternary, in: Capsule())
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "Disponible en \(game.stores.map(\.displayName).joined(separator: " y "))"
        )
      }
    }
  }

  private var datos: some View {
    VStack(spacing: 12) {
      FilaDato(
        etiqueta: "Tiempo jugado",
        valor: PlaytimeFormatter.short(hours: game.playtimeHours),
        valorAccesible: PlaytimeFormatter.accessible(hours: game.playtimeHours)
      )

      FilaDato(
        etiqueta: "Ultima vez",
        valor: LastPlayedFormatter.text(for: game.lastPlayedAt)
      )

      if game.storeEntries.count > 1 {
        // Con varias tiendas, el desglose explica de donde salen las horas
        ForEach(game.storeEntries.sorted { $0.store.rawValue < $1.store.rawValue }) { entrada in
          FilaDato(
            etiqueta: entrada.store.displayName,
            valor: PlaytimeFormatter.short(hours: entrada.playtimeHours),
            valorAccesible: PlaytimeFormatter.accessible(hours: entrada.playtimeHours)
          )
          .font(.subheadline)
        }
      }
    }
  }

  private func botonTienda(_ url: URL) -> some View {
    Link(destination: url) {
      Label("Ver en la tienda", systemImage: "arrow.up.right.square")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .accessibilityHint("Abre la ficha del juego en el navegador")
  }

  private var proximamente: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Proximamente")
        .font(.headline)

      ForEach(Self.pendientes, id: \.titulo) { pendiente in
        HStack(spacing: 10) {
          Image(systemName: pendiente.icono)
            .frame(width: 24)
            .foregroundStyle(.secondary)
          Text(pendiente.titulo)
          Spacer()
        }
        .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Proximamente: " + Self.pendientes.map(\.titulo).joined(separator: ", ")
    )
  }

  /// Lo que va a vivir en esta pantalla mas adelante.
  private static let pendientes: [(titulo: String, icono: String)] = [
    ("Marcar estado del juego", "flag"),
    ("Agregar a una coleccion", "folder"),
    ("Notas personales", "note.text")
  ]
}

/// Una linea de "etiqueta: valor".
private struct FilaDato: View {
  let etiqueta: String
  let valor: String
  var valorAccesible: String?

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(etiqueta)
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      Text(valor)
        .multilineTextAlignment(.trailing)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(etiqueta): \(valorAccesible ?? valor)")
  }
}

/// Caratula grande para la ficha.
struct GameCoverLarge: View {
  let urlString: String?

  private static let proporcion: CGFloat = 460.0 / 215.0

  var body: some View {
    Group {
      if let urlString, let url = URL(string: urlString) {
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { fase in
          switch fase {
          case .success(let imagen):
            imagen.resizable().scaledToFill()
          case .failure:
            marcador(icono: "photo")
          case .empty:
            marcador(icono: nil)
          @unknown default:
            marcador(icono: "photo")
          }
        }
      } else {
        marcador(icono: "gamecontroller")
      }
    }
    .aspectRatio(Self.proporcion, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityHidden(true)
  }

  private func marcador(icono: String?) -> some View {
    ZStack {
      Rectangle().fill(.quaternary)
      if let icono {
        Image(systemName: icono)
          .font(.largeTitle)
          .foregroundStyle(.secondary)
      } else {
        ProgressView()
      }
    }
  }
}

#Preview("Con caratula") {
  let game = Game(
    name: "Red Dead Redemption 2",
    coverImageURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1174180/header.jpg",
    playtimeHours: 227.9
  )
  game.storeEntries = [
    StoreEntry(
      store: .steam,
      storeGameID: "1174180",
      storeURL: "https://store.steampowered.com/app/1174180",
      playtimeHours: 227.9,
      lastPlayedAt: Date().addingTimeInterval(-3 * 86_400)
    )
  ]

  return NavigationStack {
    GameDetailView(game: game)
  }
}

#Preview("Sin jugar y sin caratula") {
  NavigationStack {
    GameDetailView(game: Game(name: "Un juego que nunca abri"))
  }
}
