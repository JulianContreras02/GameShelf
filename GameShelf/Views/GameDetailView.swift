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
  @State private var mostrandoTrofeos = false
  @Environment(\.modelContext) private var modelContext

  let game: Game

  @State private var eligiendoColecciones = false
  @State private var editandoEtiquetas = false
  @State private var editandoNotas = false
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
        GameCollectionsSection(game: game) { eligiendoColecciones = true }
        Divider()
        GameTagsSection(game: game) { editandoEtiquetas = true }
        Divider()
        GameNotesSection(game: game) { editandoNotas = true }
      }
      .padding()
    }
    .navigationTitle(game.name)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $eligiendoColecciones) {
      GameCollectionsPicker(juego: game)
    }
    .sheet(isPresented: $editandoEtiquetas) {
      GameTagsEditor(juego: game)
    }
    .sheet(isPresented: $editandoNotas) {
      GameNotesEditor(juego: game)
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
        etiqueta: String(localized: "Tiempo jugado", comment: "Dato de la ficha"),
        valor: PlaytimeFormatter.short(hours: game.playtimeHours),
        valorAccesible: PlaytimeFormatter.accessible(hours: game.playtimeHours)
      )

      FilaDato(
        etiqueta: String(localized: "Ultima vez", comment: "Dato de la ficha"),
        valor: LastPlayedFormatter.text(for: game.lastPlayedAt)
      )

      // Solo PlayStation lleva la cuenta de trofeos, asi que este dato aparece
      // unicamente en los juegos que vienen de ahi.
      if let trofeos = game.trophyProgress {
        if let desglose = game.trophyBreakdown {
          // Con desglose el porcentaje se puede tocar: el numero dice cuanto
          // falta, y el desglose dice de que.
          Button {
            mostrandoTrofeos = true
          } label: {
            HStack(alignment: .firstTextBaseline) {
              Text("Trofeos")
                .foregroundStyle(.secondary)
              Spacer(minLength: 12)
              Text(trofeos.formatted(.percent.scale(1)))
              Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            }
          }
          .buttonStyle(.plain)
          // Sin esto solo responde al tocar el texto, y la fila parece
          // pulsable en todo su ancho: tocar el hueco del medio no hacia nada.
          .contentShape(Rectangle())
          .accessibilityElement(children: .combine)
          .accessibilityLabel(
            String(
              localized: "Trofeos: \(trofeos) %. Toca para ver el desglose por tipo.",
              comment: "Fila de trofeos, para VoiceOver"
            )
          )
          .accessibilityAddTraits(.isButton)
          .sheet(isPresented: $mostrandoTrofeos) {
            TrophyBreakdownView(
              gameName: game.name,
              earned: desglose.earned,
              defined: desglose.defined,
              progress: trofeos
            )
          }
        } else {
          // Sin desglose guardado (por ejemplo antes de re-sincronizar) se
          // muestra solo el porcentaje, sin prometer algo que no hay.
          FilaDato(
            etiqueta: String(localized: "Trofeos", comment: "Dato de la ficha"),
            valor: trofeos.formatted(.percent.scale(1))
          )
        }
      }

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
