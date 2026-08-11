//
//  GameRow.swift
//  GameShelf
//

import SwiftUI

/// Una fila de la biblioteca: caratula, nombre y horas.
struct GameRow: View {
  let game: Game

  var body: some View {
    HStack(spacing: 12) {
      GameCover(urlString: game.coverImageURL)

      VStack(alignment: .leading, spacing: 4) {
        Text(game.name)
          .font(.headline)
          .lineLimit(2)

        HStack(spacing: 6) {
          Text(PlaytimeFormatter.short(hours: game.playtimeHours))

          if !game.stores.isEmpty {
            Text("·")
            Text(game.stores.map(\.displayName).joined(separator: ", "))
              .lineLimit(1)
          }
        }
        .font(.subheadline)
        // .secondary se adapta solo a modo claro y oscuro
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
    // La fila se lee como una sola unidad, no campo por campo
    .accessibilityElement(children: .combine)
    .accessibilityLabel(etiquetaAccesible)
  }

  private var etiquetaAccesible: String {
    var partes = [game.name, PlaytimeFormatter.accessible(hours: game.playtimeHours)]
    if !game.stores.isEmpty {
      partes.append("en \(game.stores.map(\.displayName).joined(separator: " y "))")
    }
    return partes.joined(separator: ", ")
  }
}

/// Caratula del juego, cargada de la red con marcador de posicion.
struct GameCover: View {
  let urlString: String?

  /// Proporcion de las caratulas horizontales de Steam (460x215).
  private static let proporcion: CGFloat = 460.0 / 215.0
  private static let ancho: CGFloat = 92

  private var alto: CGFloat { Self.ancho / Self.proporcion }

  var body: some View {
    Group {
      if let urlString, let url = URL(string: urlString) {
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { fase in
          switch fase {
          case .success(let imagen):
            imagen.resizable().scaledToFill()
          case .failure:
            // La caratula puede no existir para algunos appID
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
    .frame(width: Self.ancho, height: alto)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    // Decorativa: el nombre del juego ya lo dice todo
    .accessibilityHidden(true)
  }

  private func marcador(icono: String?) -> some View {
    ZStack {
      // Se adapta a modo claro y oscuro
      Rectangle().fill(.quaternary)
      if let icono {
        Image(systemName: icono)
          .foregroundStyle(.secondary)
      } else {
        ProgressView()
          .controlSize(.small)
      }
    }
  }
}

#Preview("Fila") {
  let game = Game(
    name: "Red Dead Redemption 2",
    coverImageURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1174180/header.jpg",
    playtimeHours: 227.9
  )
  game.storeEntries = [StoreEntry(store: .steam, storeGameID: "1174180")]

  return List {
    GameRow(game: game)
    GameRow(game: Game(name: "Juego sin caratula ni horas"))
  }
}
