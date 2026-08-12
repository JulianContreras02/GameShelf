//
//  LibraryInsightsView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Lo que la app deduce sola de la biblioteca: resumen, secciones automaticas y
/// como se reparte el tiempo.
struct LibraryInsightsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var juegos: [Game]

  @State private var statusViewModel = GameStatusViewModel()
  @State private var confirmandoBacklog = false
  @State private var mensaje: String?

  private var resumen: LibraryInsights.Summary {
    LibraryInsights.summary(for: juegos)
  }

  private var secciones: [LibraryInsights.Section] {
    LibraryInsights.sections(for: juegos)
  }

  private var candidatos: [Game] {
    LibraryInsights.candidatesForBacklog(in: juegos)
  }

  var body: some View {
    Group {
      if resumen.isEmpty {
        ContentUnavailableView {
          Label("Nada que analizar", systemImage: "chart.bar")
        } description: {
          Text("Sincroniza tu biblioteca para ver como repartes tu tiempo.")
        }
      } else {
        List {
          seccionResumen
          seccionDistribucion
          if !candidatos.isEmpty { seccionSugerencia }
          ForEach(secciones) { seccion in
            seccionAutomatica(seccion)
          }
        }
      }
    }
    .navigationTitle("Analisis")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      LibraryInsights.backlogSuggestionTitle(count: candidatos.count),
      isPresented: $confirmandoBacklog,
      titleVisibility: .visible
    ) {
      Button(LibraryInsights.backlogConfirmationAction(count: candidatos.count)) {
        marcarComoPendientes()
      }
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text(LibraryInsights.backlogConfirmationMessage(count: candidatos.count))
    }
    .alert(
      "Listo",
      isPresented: .init(
        get: { mensaje != nil },
        set: { if !$0 { mensaje = nil } }
      )
    ) {
      Button("Entendido", role: .cancel) {}
    } message: {
      Text(mensaje ?? "")
    }
  }

  // MARK: - Resumen

  private var seccionResumen: some View {
    Section {
      FilaDeDato(
        etiqueta: String(localized: "Juegos", comment: "Dato del resumen"),
        valor: "\(resumen.totalGames)"
      )
      FilaDeDato(
        etiqueta: String(localized: "Tiempo total", comment: "Dato del resumen"),
        valor: PlaytimeFormatter.short(hours: resumen.totalHours),
        valorAccesible: PlaytimeFormatter.accessible(hours: resumen.totalHours)
      )
      FilaDeDato(
        etiqueta: String(localized: "Nunca jugados", comment: "Juegos que nunca se abrieron"),
        valor: "\(resumen.unplayedCount) · \(porcentaje(resumen.unplayedFraction))"
      )
      FilaDeDato(
        etiqueta: String(localized: "Promedio por juego jugado", comment: "Dato del resumen"),
        valor: PlaytimeFormatter.short(hours: resumen.averageHoursPerPlayedGame)
      )
    } header: {
      Text("Resumen")
    } footer: {
      Text("Se calcula con las horas que reporta cada tienda, no con el estado que pusiste tu.")
    }
  }

  // MARK: - Distribucion

  @ViewBuilder
  private var seccionDistribucion: some View {
    let reparto = LibraryInsights.concentration(for: juegos)

    if reparto.gamesForHalfTheTime > 0 {
      Section("Como repartes tu tiempo") {
        FilaDeDato(
          etiqueta: String(localized: "La mitad de tus horas", comment: "Dato de la distribucion"),
          valor: String(
            localized: "en \(reparto.gamesForHalfTheTime) juegos",
            comment: "En cuantos juegos se concentra la mitad del tiempo"
          )
        )
        FilaDeDato(
          etiqueta: String(localized: "El que mas juegas", comment: "Dato de la distribucion"),
          valor: delTotal(reparto.topGameShare)
        )
        FilaDeDato(
          etiqueta: String(localized: "Tus cinco favoritos", comment: "Dato de la distribucion"),
          valor: delTotal(reparto.topFiveShare)
        )
      }
    }
  }

  // MARK: - Sugerencia

  private var seccionSugerencia: some View {
    Section {
      Button {
        confirmandoBacklog = true
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text(LibraryInsights.backlogSuggestionTitle(count: candidatos.count))
            Text(LibraryInsights.backlogSuggestionSubtitle())
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "tray.full")
            .foregroundStyle(.tint)
        }
      }
    } header: {
      Text("Sugerencia")
    }
  }

  // MARK: - Secciones automaticas

  private func seccionAutomatica(_ seccion: LibraryInsights.Section) -> some View {
    Section {
      ForEach(seccion.games) { juego in
        NavigationLink {
          GameDetailView(game: juego)
        } label: {
          GameRow(game: juego)
        }
      }

      if seccion.hasMore {
        Text("y \(seccion.totalCount - seccion.games.count) mas")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } header: {
      HStack {
        Label(seccion.kind.title, systemImage: seccion.kind.symbolName)
        Spacer()
        Text("\(seccion.totalCount)")
          .textCase(nil)
      }
    } footer: {
      Text(seccion.kind.explanation)
    }
  }

  // MARK: - Apoyo

  /// "51 % del total", con el porcentaje ya formateado segun el idioma.
  private func delTotal(_ fraccion: Double) -> String {
    String(localized: "\(porcentaje(fraccion)) del total", comment: "Que parte del tiempo se lleva")
  }

  private func porcentaje(_ fraccion: Double) -> String {
    fraccion.formatted(.percent.precision(.fractionLength(0)))
  }

  private func marcarComoPendientes() {
    do {
      let cambiados = try statusViewModel.setStatus(
        .backlog,
        for: candidatos,
        in: modelContext
      )
      mensaje = LibraryInsights.backlogResultMessage(count: cambiados)
    } catch {
      mensaje = error.localizedDescription
    }
  }
}

/// Fila de "etiqueta: valor" para las tablas de datos.
private struct FilaDeDato: View {
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
