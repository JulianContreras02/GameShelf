//
//  GameFiltersView.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Hoja para elegir que juegos se ven.
///
/// Los cambios se aplican al momento sobre la lista de atras; el boton
/// "Limpiar" quita todo de una vez.
struct GameFiltersView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \GameCollection.sortOrder) private var colecciones: [GameCollection]
  @Query(sort: \GameTag.name) private var etiquetas: [GameTag]

  @Binding var filter: GameFilter

  /// Cuantos juegos quedarian con lo que hay marcado. Se calcula fuera y se
  /// pasa, para que la hoja no tenga que consultar la base.
  let resultados: Int

  var body: some View {
    NavigationStack {
      List {
        seccionEstado
        seccionTienda
        if !colecciones.isEmpty { seccionColecciones }
        if !etiquetas.isEmpty { seccionEtiquetas }
      }
      .navigationTitle("Filtros")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Limpiar") { filter.clear() }
            .disabled(!filter.isActive)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Ver \(resultados)") { dismiss() }
            .fontWeight(.semibold)
        }
      }
    }
  }

  // MARK: - Secciones

  private var seccionEstado: some View {
    Section("Estado") {
      ForEach(PlayStatus.displayOrder, id: \.self) { estado in
        FilaDeFiltro(
          titulo: estado.displayName,
          simbolo: estado.symbolName,
          color: estado.tint,
          marcado: filter.statuses.contains(estado)
        ) {
          alternar(estado, en: &filter.statuses)
        }
      }
    }
  }

  private var seccionTienda: some View {
    Section("Tienda") {
      ForEach(Store.allCases, id: \.self) { tienda in
        FilaDeFiltro(
          titulo: tienda.displayName,
          simbolo: "bag",
          color: .secondary,
          marcado: filter.stores.contains(tienda)
        ) {
          alternar(tienda, en: &filter.stores)
        }
      }
    }
  }

  private var seccionColecciones: some View {
    Section("Colecciones") {
      ForEach(colecciones) { coleccion in
        FilaDeFiltro(
          titulo: coleccion.name,
          simbolo: coleccion.symbolName,
          color: coleccion.color.swiftUIColor,
          marcado: filter.collectionIDs.contains(coleccion.id)
        ) {
          alternar(coleccion.id, en: &filter.collectionIDs)
        }
      }
    }
  }

  private var seccionEtiquetas: some View {
    Section("Etiquetas") {
      ForEach(etiquetas) { etiqueta in
        FilaDeFiltro(
          titulo: etiqueta.name,
          simbolo: "tag",
          color: .secondary,
          marcado: filter.tagIDs.contains(etiqueta.id)
        ) {
          alternar(etiqueta.id, en: &filter.tagIDs)
        }
      }
    }
  }

  private func alternar<T: Hashable>(_ valor: T, en conjunto: inout Set<T>) {
    if conjunto.contains(valor) {
      conjunto.remove(valor)
    } else {
      conjunto.insert(valor)
    }
  }
}

/// Fila con casilla de un filtro.
private struct FilaDeFiltro: View {
  let titulo: String
  let simbolo: String
  let color: Color
  let marcado: Bool
  let alTocar: () -> Void

  var body: some View {
    Button(action: alTocar) {
      HStack(spacing: 12) {
        Image(systemName: simbolo)
          .foregroundStyle(color)
          .frame(width: 26)

        Text(titulo)
          .foregroundStyle(.primary)

        Spacer()

        Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(marcado ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // El estado no se comunica solo con el icono
    .accessibilityElement(children: .combine)
    .accessibilityLabel(titulo)
    .accessibilityValue(marcado ? "Filtrando" : "Sin filtrar")
    .accessibilityAddTraits(marcado ? [.isSelected] : [])
  }
}

#Preview {
  @Previewable @State var filtro = GameFilter()

  return GameFiltersView(filter: $filtro, resultados: 42)
    .modelContainer(
      for: [Game.self, StoreEntry.self, GameCollection.self, GameTag.self],
      inMemory: true
    )
}
