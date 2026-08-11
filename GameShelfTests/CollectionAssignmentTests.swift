//
//  CollectionAssignmentTests.swift
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

@discardableResult
private func insertarJuegos(_ nombres: [String], in context: ModelContext) -> [Game] {
  let juegos = nombres.map { Game(name: $0) }
  for juego in juegos { context.insert(juego) }
  return juegos
}

@Suite("Asignar un juego a colecciones")
@MainActor
struct ToggleAssignmentTests {

  @Test("Alternar mete el juego si no estaba")
  func alternarAgrega() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juego = insertarJuegos(["Celeste"], in: context)[0]

    let quedoDentro = try viewModel.toggle(juego, in: coleccion, context: context)

    #expect(quedoDentro)
    #expect(coleccion.contains(juego))
    #expect(juego.collections.count == 1)
  }

  @Test("Alternar lo saca si ya estaba, sin borrar el juego")
  func alternarQuita() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juego = insertarJuegos(["Celeste"], in: context)[0]
    try viewModel.toggle(juego, in: coleccion, context: context)

    let quedoDentro = try viewModel.toggle(juego, in: coleccion, context: context)

    #expect(quedoDentro == false)
    #expect(coleccion.isEmpty)
    #expect(
      try context.fetch(FetchDescriptor<Game>()).count == 1,
      "Sacarlo de la coleccion no puede borrarlo"
    )
  }

  @Test("Alternar varias veces deja el estado coherente")
  func alternarRepetido() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "X", in: context)
    let juego = insertarJuegos(["Un juego"], in: context)[0]

    for _ in 1...5 {
      try viewModel.toggle(juego, in: coleccion, context: context)
    }

    #expect(coleccion.gameCount == 1, "Numero impar de alternancias: queda dentro")
  }

  @Test("Un juego puede entrar en varias colecciones")
  func juegoEnVarias() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let favoritos = try viewModel.create(name: "Favoritos", in: context)
    let pendientes = try viewModel.create(name: "Pendientes", in: context)
    let juego = insertarJuegos(["Celeste"], in: context)[0]

    try viewModel.toggle(juego, in: favoritos, context: context)
    try viewModel.toggle(juego, in: pendientes, context: context)

    #expect(juego.collections.count == 2)
  }

  @Test("Sacarlo de una coleccion no lo saca de las otras")
  func quitarDeUnaNoAfectaOtras() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let favoritos = try viewModel.create(name: "Favoritos", in: context)
    let pendientes = try viewModel.create(name: "Pendientes", in: context)
    let juego = insertarJuegos(["Celeste"], in: context)[0]
    try viewModel.toggle(juego, in: favoritos, context: context)
    try viewModel.toggle(juego, in: pendientes, context: context)

    try viewModel.toggle(juego, in: favoritos, context: context)

    #expect(favoritos.isEmpty)
    #expect(pendientes.gameCount == 1)
    #expect(juego.collections.count == 1)
  }
}

@Suite("Asignar varios juegos de una vez")
@MainActor
struct BulkAssignmentTests {

  @Test("Agrega todos los juegos seleccionados")
  func agregarVarios() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juegos = insertarJuegos(["Uno", "Dos", "Tres"], in: context)

    let agregados = try viewModel.add(juegos, to: coleccion, context: context)

    #expect(agregados == 3)
    #expect(coleccion.gameCount == 3)
  }

  @Test("Los que ya estaban no se duplican ni se cuentan")
  func noDuplicaLosQueYaEstaban() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juegos = insertarJuegos(["Uno", "Dos", "Tres"], in: context)

    try viewModel.add([juegos[0]], to: coleccion, context: context)
    let agregados = try viewModel.add(juegos, to: coleccion, context: context)

    #expect(agregados == 2, "Solo cuentan los que de verdad entraron")
    #expect(coleccion.gameCount == 3, "No debe quedar ninguno repetido")
  }

  @Test("Agregar una lista vacia no hace nada")
  func listaVacia() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)

    let agregados = try viewModel.add([], to: coleccion, context: context)

    #expect(agregados == 0)
    #expect(coleccion.isEmpty)
  }

  @Test("Quitar varios saca solo los que estaban")
  func quitarVarios() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juegos = insertarJuegos(["Uno", "Dos", "Tres"], in: context)
    try viewModel.add([juegos[0], juegos[1]], to: coleccion, context: context)

    let quitados = try viewModel.remove(juegos, from: coleccion, context: context)

    #expect(quitados == 2, "El tercero no estaba, no cuenta")
    #expect(coleccion.isEmpty)
  }

  @Test("Quitar varios no borra ningun juego de la biblioteca")
  func quitarNoborraJuegos() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juegos = insertarJuegos(["Uno", "Dos", "Tres"], in: context)
    try viewModel.add(juegos, to: coleccion, context: context)

    try viewModel.remove(juegos, from: coleccion, context: context)

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 3)
  }

  @Test("Agregar en lote a dos colecciones deja el juego en ambas")
  func loteADosColecciones() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let primera = try viewModel.create(name: "A", in: context)
    let segunda = try viewModel.create(name: "B", in: context)
    let juegos = insertarJuegos(["Uno", "Dos"], in: context)

    try viewModel.add(juegos, to: primera, context: context)
    try viewModel.add(juegos, to: segunda, context: context)

    #expect(primera.gameCount == 2)
    #expect(segunda.gameCount == 2)
    #expect(juegos[0].collections.count == 2)
  }
}

@Suite("Asignaciones y sincronizacion")
@MainActor
struct AssignmentSyncTests {

  @Test("Re-sincronizar con Steam no saca los juegos de sus colecciones")
  func sincronizarConservaAsignaciones() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let dtos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(dtos, into: context)

    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let todos = try context.fetch(FetchDescriptor<Game>())
    try viewModel.add(Array(todos.prefix(3)), to: coleccion, context: context)

    try SteamLibrarySyncer.sync(dtos, into: context)

    #expect(
      coleccion.gameCount == 3,
      "La organizacion del usuario no la puede deshacer una sincronizacion"
    )
  }

  @Test("Borrar un juego lo saca de sus colecciones sin dejar huecos")
  func borrarJuegoLimpiaColecciones() throws {
    let context = try hacerContexto()
    let viewModel = CollectionsViewModel()
    let coleccion = try viewModel.create(name: "Favoritos", in: context)
    let juegos = insertarJuegos(["Uno", "Dos"], in: context)
    try viewModel.add(juegos, to: coleccion, context: context)

    context.delete(juegos[0])
    try context.save()

    #expect(coleccion.gameCount == 1)
    #expect(coleccion.games.first?.name == "Dos")
  }
}
