//
//  GameCollectionsPicker.swift
//  GameShelf
//

import SwiftData
import SwiftUI

/// Hoja para elegir en que colecciones esta un juego.
///
/// Los cambios se guardan al momento: no hay boton de confirmar, igual que en
/// Fotos o Recordatorios.
struct GameCollectionsPicker: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \GameCollection.sortOrder) private var colecciones: [GameCollection]

  let juego: Game

  @State private var viewModel = CollectionsViewModel()
  @State private var creandoColeccion = false
  @State private var mensajeDeError: String?

  var body: some View {
    NavigationStack {
      Group {
        if colecciones.isEmpty {
          estadoVacio
        } else {
          lista
        }
      }
      .navigationTitle("Colecciones")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Listo") { dismiss() }
        }
        if !colecciones.isEmpty {
          ToolbarItem(placement: .topBarLeading) {
            Button("Nueva", systemImage: "plus") { creandoColeccion = true }
          }
        }
      }
      .sheet(isPresented: $creandoColeccion) {
        CollectionEditorView(coleccion: nil, viewModel: viewModel)
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
  }

  private var lista: some View {
    List(colecciones) { coleccion in
      Button {
        alternar(coleccion)
      } label: {
        HStack(spacing: 12) {
          Image(systemName: coleccion.symbolName)
            .foregroundStyle(coleccion.color.swiftUIColor)
            .frame(width: 28)

          Text(coleccion.name)
            .foregroundStyle(.primary)

          Spacer()

          if coleccion.contains(juego) {
            Image(systemName: "checkmark")
              .foregroundStyle(.tint)
              .fontWeight(.semibold)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      // El check no se comunica solo con el icono: VoiceOver dice si esta
      .accessibilityElement(children: .combine)
      .accessibilityLabel(coleccion.name)
      .accessibilityValue(coleccion.contains(juego) ? "En esta coleccion" : "No agregado")
      .accessibilityAddTraits(coleccion.contains(juego) ? [.isSelected] : [])
    }
  }

  private var estadoVacio: some View {
    ContentUnavailableView {
      Label("Sin colecciones", systemImage: "folder")
    } description: {
      Text("Crea una coleccion para empezar a agrupar tus juegos.")
    } actions: {
      Button("Crear coleccion") { creandoColeccion = true }
        .buttonStyle(.borderedProminent)
    }
  }

  private func alternar(_ coleccion: GameCollection) {
    do {
      try viewModel.toggle(juego, in: coleccion, context: modelContext)
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

/// Hoja para agregar **varios** juegos a una coleccion de una vez.
///
/// A diferencia del selector de un solo juego, aca se elige una coleccion y se
/// confirma: mover 20 juegos por error seria molesto de deshacer.
struct BulkAddToCollectionView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \GameCollection.sortOrder) private var colecciones: [GameCollection]

  let juegos: [Game]

  @State private var viewModel = CollectionsViewModel()
  @State private var creandoColeccion = false
  @State private var mensajeDeError: String?

  var body: some View {
    NavigationStack {
      Group {
        if colecciones.isEmpty {
          ContentUnavailableView {
            Label("Sin colecciones", systemImage: "folder")
          } description: {
            Text("Crea una coleccion para mover estos juegos.")
          } actions: {
            Button("Crear coleccion") { creandoColeccion = true }
              .buttonStyle(.borderedProminent)
          }
        } else {
          List(colecciones) { coleccion in
            Button {
              agregar(a: coleccion)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: coleccion.symbolName)
                  .foregroundStyle(coleccion.color.swiftUIColor)
                  .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                  Text(coleccion.name).foregroundStyle(.primary)
                  Text(textoNuevos(en: coleccion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      }
      .navigationTitle("Agregar \(juegos.count) a…")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
      }
      .sheet(isPresented: $creandoColeccion) {
        CollectionEditorView(coleccion: nil, viewModel: viewModel)
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
  }

  /// Avisa cuantos se van a agregar de verdad, para que no sorprenda que el
  /// numero final sea menor si algunos ya estaban.
  private func textoNuevos(en coleccion: GameCollection) -> String {
    let nuevos = juegos.filter { !coleccion.contains($0) }.count
    switch nuevos {
    case 0: return "Ya estan todos aqui"
    case juegos.count: return "Se agregan \(nuevos)"
    default: return "Se agregan \(nuevos), \(juegos.count - nuevos) ya estaban"
    }
  }

  private func agregar(a coleccion: GameCollection) {
    do {
      try viewModel.add(juegos, to: coleccion, context: modelContext)
      dismiss()
    } catch {
      mensajeDeError = error.localizedDescription
    }
  }
}

#Preview("Selector") {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  if let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, configurations: config
  ) {
    let juego = Game(name: "Hollow Knight")
    contenedor.mainContext.insert(juego)
    contenedor.mainContext.insert(GameCollection(name: "Favoritos", symbolName: "star", color: .yellow))
    contenedor.mainContext.insert(GameCollection(name: "Pendientes", symbolName: "moon", color: .purple))
    return AnyView(GameCollectionsPicker(juego: juego).modelContainer(contenedor))
  } else {
    return AnyView(Text("No se pudo crear el contenedor"))
  }
}
