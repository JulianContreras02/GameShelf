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
  @Environment(\.modelContext) private var modelContext

  let game: Game

  @State private var eligiendoColecciones = false
  @State private var statusViewModel = GameStatusViewModel()
  @State private var mensajeDeError: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        caratula
        encabezado
        Divider()
        seccionEstado
        Divider()
        datos
        if let enlace = game.storeLink() {
          botonTienda(enlace)
        }
        Divider()
        seccionColecciones
        Divider()
        proximamente
      }
      .padding()
    }
    .navigationTitle(game.name)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $eligiendoColecciones) {
      GameCollectionsPicker(juego: game)
    }
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

  // MARK: - Estado

  private var seccionEstado: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Estado")
        .font(.headline)

      Menu {
        PlayStatusMenu(actual: game.status) { nuevo in
          cambiarEstado(a: nuevo)
        }
      } label: {
        HStack {
          Label {
            Text(game.status.displayName)
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: game.status.symbolName)
              .foregroundStyle(game.status.tint)
          }
          Spacer()
          Image(systemName: "chevron.up.chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
      }
      .accessibilityLabel("Estado del juego: \(game.status.displayName)")
      .accessibilityHint("Toca para cambiarlo")

      Text(game.status.explanation)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func cambiarEstado(a estado: PlayStatus) {
    do {
      try statusViewModel.setStatus(estado, for: game, in: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }

  // MARK: - Colecciones

  private var seccionColecciones: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Colecciones")
          .font(.headline)
        Spacer()
        Button("Editar") { eligiendoColecciones = true }
          .font(.subheadline)
      }

      if game.collections.isEmpty {
        Button {
          eligiendoColecciones = true
        } label: {
          Label("Agregar a una coleccion", systemImage: "folder.badge.plus")
            .font(.subheadline)
        }
      } else {
        // Las etiquetas fluyen a varias lineas si no caben
        FlowLayout(spacing: 8) {
          ForEach(game.collections.sorted { $0.sortOrder < $1.sortOrder }) { coleccion in
            Label(coleccion.name, systemImage: coleccion.symbolName)
              .font(.caption.weight(.medium))
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(coleccion.color.swiftUIColor.opacity(0.18), in: Capsule())
              .foregroundStyle(coleccion.color.swiftUIColor)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "En \(game.collections.count) colecciones: "
            + game.collections.map(\.name).joined(separator: ", ")
        )
      }
    }
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
    ("Notas personales", "note.text"),
    ("Etiquetas", "tag")
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
