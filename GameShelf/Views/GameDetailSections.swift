//
//  GameDetailSections.swift
//  GameShelf
//

import SwiftUI

/// Secciones de la ficha del juego que solo muestran datos y avisan cuando hay
/// que editar.
///
/// Viven aparte de `GameDetailView` porque esa pantalla pasaba del limite de
/// tamaño de SwiftLint, y porque asi cada seccion declara lo que necesita en vez
/// de leer el estado de la vista que la contiene.

/// Colecciones a las que pertenece el juego.
struct GameCollectionsSection: View {
  let game: Game
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      CabeceraDeSeccion(titulo: "Colecciones", accion: "Editar", alTocar: onEdit)

      if game.collections.isEmpty {
        BotonVacio(titulo: "Agregar a una coleccion", icono: "folder.badge.plus", alTocar: onEdit)
      } else {
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
}

/// Etiquetas del juego.
struct GameTagsSection: View {
  let game: Game
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      CabeceraDeSeccion(titulo: "Etiquetas", accion: "Editar", alTocar: onEdit)

      if game.tags.isEmpty {
        BotonVacio(titulo: "Agregar etiquetas", icono: "tag", alTocar: onEdit)
      } else {
        FlowLayout(spacing: 8) {
          ForEach(game.tags.sorted { $0.normalized < $1.normalized }) { etiqueta in
            Text(etiqueta.name)
              .font(.caption.weight(.medium))
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(.quaternary, in: Capsule())
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(game.tags.count) etiquetas: " + game.tags.map(\.name).joined(separator: ", ")
        )
      }
    }
  }
}

/// Notas personales del juego.
struct GameNotesSection: View {
  let game: Game
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      CabeceraDeSeccion(
        titulo: "Notas",
        accion: game.notes.isEmpty ? "Agregar" : "Editar",
        alTocar: onEdit
      )

      if game.notes.isEmpty {
        BotonVacio(titulo: "Escribir una nota", icono: "note.text", alTocar: onEdit)
      } else {
        Button(action: onEdit) {
          Text(game.notes)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            // Crece con Dynamic Type en vez de recortarse
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notas: \(game.notes)")
        .accessibilityHint("Toca para editarlas")
      }
    }
  }
}

// MARK: - Piezas comunes

private struct CabeceraDeSeccion: View {
  let titulo: LocalizedStringKey
  let accion: LocalizedStringKey
  let alTocar: () -> Void

  var body: some View {
    HStack {
      Text(titulo)
        .font(.headline)
      Spacer()
      Button(accion, action: alTocar)
        .font(.subheadline)
    }
  }
}

private struct BotonVacio: View {
  let titulo: LocalizedStringKey
  let icono: String
  let alTocar: () -> Void

  var body: some View {
    Button(action: alTocar) {
      Label(titulo, systemImage: icono)
        .font(.subheadline)
    }
  }
}
