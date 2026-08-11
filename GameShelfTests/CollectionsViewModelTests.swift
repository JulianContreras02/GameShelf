//
//  CollectionsViewModelTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

private func hacerContexto() throws -> ModelContext {
  let schema = Schema([Game.self, StoreEntry.self, GameCollection.self])
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}

private func colecciones(_ context: ModelContext) throws -> [GameCollection] {
  try context.fetch(FetchDescriptor<GameCollection>()).sorted { $0.sortOrder < $1.sortOrder }
}

@Suite("Colecciones: crear")
@MainActor
struct CreateCollectionTests {

  @Test("Crear una coleccion la guarda con sus datos")
  func crear() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()

    let creada = try viewModel.create(
      name: "Favoritos", symbolName: "star", color: .yellow, in: context
    )

    #expect(creada.name == "Favoritos")
    #expect(creada.symbolName == "star")
    #expect(creada.color == .yellow)
    #expect(try colecciones(context).count == 1)
  }

  @Test("Los espacios sobrantes del nombre se recortan")
  func recortaEspacios() throws {
    let context = try hacerContexto()

    let creada = try CollectionsViewModel().create(name: "  Favoritos  ", in: context)

    #expect(creada.name == "Favoritos")
  }

  @Test("Un nombre vacio se rechaza")
  func nombreVacio() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()

    #expect(throws: CollectionsViewModel.ValidationError.emptyName) {
      try viewModel.create(name: "   ", in: context)
    }
    #expect(try colecciones(context).isEmpty)
  }

  @Test("Un nombre repetido se rechaza, sin importar mayusculas ni tildes")
  func nombreRepetido() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    try viewModel.create(name: "Favoritos", in: context)

    #expect(throws: CollectionsViewModel.ValidationError.self) {
      try viewModel.create(name: "favoritos", in: context)
    }
    #expect(throws: CollectionsViewModel.ValidationError.self) {
      try viewModel.create(name: "FAVORITOS", in: context)
    }
    #expect(try colecciones(context).count == 1)
  }

  @Test("Un nombre muy largo se rechaza")
  func nombreMuyLargo() throws {
    let context = try hacerContexto()
    let largo = String(repeating: "a", count: CollectionsViewModel.maxNameLength + 1)

    #expect(throws: CollectionsViewModel.ValidationError.self) {
      try CollectionsViewModel().create(name: largo, in: context)
    }
  }

  @Test("Cada coleccion nueva se agrega al final")
  func ordenIncremental() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()

    try viewModel.create(name: "Primera", in: context)
    try viewModel.create(name: "Segunda", in: context)
    try viewModel.create(name: "Tercera", in: context)

    #expect(try colecciones(context).map(\.sortOrder) == [0, 1, 2])
    #expect(try colecciones(context).map(\.name) == ["Primera", "Segunda", "Tercera"])
  }
}

@Suite("Colecciones: editar")
@MainActor
struct EditCollectionTests {

  @Test("Renombrar cambia el nombre")
  func renombrar() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Viejo", in: context)

    try viewModel.rename(coleccion, to: "Nuevo", in: context)

    #expect(coleccion.name == "Nuevo")
  }

  @Test("Guardar sin cambiar el nombre no se toma como repetido")
  func mismoNombreNoEsDuplicado() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)

    // No debe lanzar: es su propio nombre
    try viewModel.rename(coleccion, to: "Favoritos", in: context)

    #expect(coleccion.name == "Favoritos")
  }

  @Test("No se puede renombrar al nombre de otra coleccion")
  func renombrarADuplicado() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    try viewModel.create(name: "Favoritos", in: context)
    let segunda = try viewModel.create(name: "Pendientes", in: context)

    #expect(throws: CollectionsViewModel.ValidationError.self) {
      try viewModel.rename(segunda, to: "Favoritos", in: context)
    }
    #expect(segunda.name == "Pendientes", "El nombre no debe cambiar si fallo")
  }

  @Test("Cambiar icono y color no toca el nombre ni los juegos")
  func cambiarApariencia() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juego = Game(name: "Un juego")
    context.insert(juego)
    coleccion.add(juego)
    try context.save()

    try viewModel.updateAppearance(coleccion, symbolName: "flame", color: .red, in: context)

    #expect(coleccion.symbolName == "flame")
    #expect(coleccion.color == .red)
    #expect(coleccion.name == "Favoritos")
    #expect(coleccion.gameCount == 1)
  }
}

@Suite("Colecciones: borrar")
@MainActor
struct DeleteCollectionTests {

  @Test("Borrar quita la coleccion")
  func borrar() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Temporal", in: context)

    try viewModel.delete(coleccion, in: context)

    #expect(try colecciones(context).isEmpty)
  }

  @Test("Borrar una coleccion NO borra sus juegos")
  func borrarConservaJuegos() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Temporal", in: context)

    for nombre in ["Uno", "Dos", "Tres"] {
      let juego = Game(name: nombre)
      context.insert(juego)
      coleccion.add(juego)
    }
    try context.save()

    try viewModel.delete(coleccion, in: context)

    #expect(
      try context.fetch(FetchDescriptor<Game>()).count == 3,
      "Los juegos deben seguir en la biblioteca"
    )
  }

  @Test("Despues de borrar, el orden queda sin huecos")
  func renumeraAlBorrar() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    try viewModel.create(name: "A", in: context)
    let bCollection = try viewModel.create(name: "B", in: context)
    try viewModel.create(name: "C", in: context)

    try viewModel.delete(bCollection, in: context)

    #expect(
      try colecciones(context).map(\.sortOrder) == [0, 1],
      "Sin renumerar quedaria [0, 2] y el arrastre se vuelve inconsistente"
    )
    #expect(try colecciones(context).map(\.name) == ["A", "C"])
  }

  @Test("Se puede volver a usar el nombre de una coleccion borrada")
  func nombreLiberado() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    try viewModel.delete(coleccion, in: context)

    // No debe lanzar
    try viewModel.create(name: "Favoritos", in: context)

    #expect(try colecciones(context).count == 1)
  }
}

@Suite("Colecciones: reordenar")
@MainActor
struct ReorderCollectionTests {

  private func crearTres(_ context: ModelContext) throws -> CollectionsViewModel {
    let viewModel = CollectionsViewModel()
    for nombre in ["A", "B", "C"] {
      try viewModel.create(name: nombre, in: context)
    }
    return viewModel
  }

  @Test("Mover el primero al final reordena bien")
  func moverAlFinal() throws {
    let context = try hacerContexto()
    let viewModel = try crearTres(context)

    try viewModel.move(try colecciones(context), from: IndexSet(integer: 0), to: 3, in: context)

    #expect(try colecciones(context).map(\.name) == ["B", "C", "A"])
    #expect(try colecciones(context).map(\.sortOrder) == [0, 1, 2])
  }

  @Test("Mover el ultimo al principio reordena bien")
  func moverAlPrincipio() throws {
    let context = try hacerContexto()
    let viewModel = try crearTres(context)

    try viewModel.move(try colecciones(context), from: IndexSet(integer: 2), to: 0, in: context)

    #expect(try colecciones(context).map(\.name) == ["C", "A", "B"])
    #expect(try colecciones(context).map(\.sortOrder) == [0, 1, 2])
  }

  @Test("El orden nuevo sobrevive a una relectura")
  func ordenPersiste() throws {
    let context = try hacerContexto()
    let viewModel = try crearTres(context)

    try viewModel.move(try colecciones(context), from: IndexSet(integer: 0), to: 3, in: context)

    let releidas = try context
      .fetch(FetchDescriptor<GameCollection>(sortBy: [SortDescriptor(\.sortOrder)]))
    #expect(releidas.map(\.name) == ["B", "C", "A"])
  }

  @Test(
    "La logica de reordenar coincide con la de SwiftUI",
    arguments: [
      (IndexSet(integer: 0), 3, ["B", "C", "A"]),
      (IndexSet(integer: 2), 0, ["C", "A", "B"]),
      (IndexSet(integer: 0), 2, ["B", "A", "C"]),
      (IndexSet(integer: 1), 0, ["B", "A", "C"]),
      (IndexSet(integer: 1), 1, ["A", "B", "C"]),
      (IndexSet([0, 1]), 3, ["C", "A", "B"])
    ]
  )
  func reordenamientoPuro(origen: IndexSet, destino: Int, esperado: [String]) {
    // Sin base de datos: solo la aritmetica de indices, que es lo facil de
    // equivocar (destino se mide ANTES de sacar los elementos).
    let resultado = CollectionsViewModel.reordenar(["A", "B", "C"], from: origen, to: destino)

    #expect(resultado == esperado)
  }

  @Test("Reordenar no cambia los juegos de cada coleccion")
  func reordenarNoTocaJuegos() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let primera = try viewModel.create(name: "A", in: context)
    try viewModel.create(name: "B", in: context)

    let juego = Game(name: "Un juego")
    context.insert(juego)
    primera.add(juego)
    try context.save()

    try viewModel.move(try colecciones(context), from: IndexSet(integer: 0), to: 2, in: context)

    let leida = try #require(try colecciones(context).first { $0.name == "A" })
    #expect(leida.gameCount == 1)
  }
}
