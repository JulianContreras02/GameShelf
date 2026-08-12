//
//  TrophyBreakdownView.swift
//  GameShelf
//

import SwiftUI

/// El desglose de trofeos de un juego, por tipo.
///
/// Se abre al tocar el porcentaje en la ficha. El porcentaje solo dice cuanto
/// falta; esto dice **de que** falta, que es lo que sirve para decidir si vale
/// la pena volver a un juego.
struct TrophyBreakdownView: View {
  @Environment(\.dismiss) private var dismiss

  let gameName: String
  let breakdown: TrophyBreakdown

  private var earned: TrophyCounts { breakdown.earned }
  private var defined: TrophyCounts { breakdown.defined }

  var body: some View {
    NavigationStack {
      List {
        seccionResumen

        Section {
          ForEach(TrophyKind.allCases, id: \.self) { tipo in
            FilaDeTrofeo(
              tipo: tipo,
              conseguidos: earned.count(of: tipo),
              totales: defined.count(of: tipo)
            )
          }
        } header: {
          Text("Por tipo")
        } footer: {
          // El texto vive en `TrophyKind` y no aca suelto: es lo que es un
          // platino, no una nota de esta pantalla.
          if let explicacion = TrophyKind.platinum.explanation {
            Text(explicacion)
          }
        }
      }
      .navigationTitle("Trofeos")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Listo") { dismiss() }
        }
      }
    }
  }

  private var seccionResumen: some View {
    Section {
      LabeledContent("Juego") { Text(gameName).multilineTextAlignment(.trailing) }

      if let progress = breakdown.progress {
        LabeledContent("Coleccion") {
          Text(progress.formatted(.percent.scale(1)))
            .fontWeight(.semibold)
            .foregroundStyle(progress == 100 ? Color.green : Color.primary)
        }
      }

      LabeledContent("Conseguidos") {
        Text(verbatim: "\(earned.total) / \(defined.total)")
          .monospacedDigit()
      }
    } footer: {
      if defined.platinum > 0 && earned.platinum > 0 {
        Label("Platino conseguido", systemImage: "trophy.fill")
          .foregroundStyle(TrophyKind.platinum.color)
      }
    }
  }
}

/// Una fila del desglose: el tipo, cuantos llevas y una barra de progreso.
private struct FilaDeTrofeo: View {
  let tipo: TrophyKind
  let conseguidos: Int
  let totales: Int

  private var fraccion: Double {
    guard totales > 0 else { return 0 }
    return Double(conseguidos) / Double(totales)
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "trophy.fill")
        .foregroundStyle(tipo.color)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(tipo.displayName)

        // La barra solo aparece si el juego tiene trofeos de ese tipo: una
        // barra vacia al 0% de cero trofeos confundiria.
        if totales > 0 {
          ProgressView(value: fraccion)
            .tint(tipo.color)
        }
      }

      Spacer(minLength: 8)

      if totales > 0 {
        Text(verbatim: "\(conseguidos) / \(totales)")
          .monospacedDigit()
          .foregroundStyle(.secondary)
      } else {
        Text("No tiene")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(etiquetaAccesible)
  }

  private var etiquetaAccesible: String {
    guard totales > 0 else {
      return String(
        localized: "\(tipo.displayName): este juego no tiene",
        comment: "Un tipo de trofeo que el juego no incluye"
      )
    }
    return String(
      localized: "\(tipo.displayName): \(conseguidos) de \(totales)",
      comment: "Cuantos trofeos de un tipo se consiguieron"
    )
  }
}

extension TrophyKind {
  /// El color con el que PlayStation representa cada tipo.
  ///
  /// Se usan colores y no imagenes porque la API solo da el icono de cada
  /// trofeo concreto, no uno por tipo. El color y la forma de copa se
  /// reconocen igual.
  var color: Color {
    switch self {
    case .bronze: Color(red: 0.72, green: 0.45, blue: 0.20)
    case .silver: Color(red: 0.60, green: 0.64, blue: 0.67)
    case .gold: Color(red: 0.83, green: 0.69, blue: 0.22)
    case .platinum: Color(red: 0.45, green: 0.62, blue: 0.81)
    }
  }
}

#Preview("Con platino") {
  TrophyBreakdownView(
    gameName: "Halo: Campaign Evolved",
    breakdown: TrophyBreakdown(
      earned: TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1),
      defined: TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1),
      progress: 100
    )
  )
}

#Preview("A medias") {
  TrophyBreakdownView(
    gameName: "Grand Theft Auto V",
    breakdown: TrophyBreakdown(
      earned: TrophyCounts(bronze: 2, silver: 0, gold: 0, platinum: 0),
      defined: TrophyCounts(bronze: 48, silver: 7, gold: 1, platinum: 1),
      progress: 3
    )
  )
}
