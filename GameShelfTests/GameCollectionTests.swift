//
//  GameCollectionTests.swift
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

@Suite("Coleccion: datos basicos")
struct GameCollectionBasicsTests {

  @Test("Se guarda y se vuelve a leer con todos sus campos")
  func guardarYLeer() throws {
    let context = try hacerContexto()

    let coleccion = GameCollection(
      name: "Para el fin de semana",
      symbolName: "star",
      color: .purple,
      sortOrder: 3
    )
    context.insert(coleccion)
    try context.save()

    let leidas = try context.fetch(FetchDescriptor<GameCollection>())
    let leida = try #require(leidas.first)

    #expect(leidas.count == 1)
    #expect(leida.name == "Para el fin de semana")
    #expect(leida.symbolName == "star")
    #expect(leida.color == .purple)
    #expect(leida.sortOrder == 3)
  }

  @Test("Una coleccion nueva arranca vacia y con valores por defecto")
  func valoresPorDefecto() {
    let coleccion = GameCollection(name: "Nueva")

    #expect(coleccion.isEmpty)
    #expect(coleccion.gameCount == 0)
    #expect(coleccion.symbolName == GameCollection.defaultSymbol)
    #expect(coleccion.color == .blue)
    #expect(coleccion.sortOrder == 0)
  }

  @Test("Cada coleccion recibe un id distinto")
  func idsUnicos() {
    #expect(GameCollection(name: "A").id != GameCollection(name: "B").id)
  }

  @Test("El color se guarda por su nombre, no por posicion")
  func colorEstable() {
    #expect(CollectionColor.blue.rawValue == "blue")
    #expect(CollectionColor.purple.rawValue == "purple")
    #expect(CollectionColor.allCases.count == 9)
  }
}

@Suite("Coleccion: relacion con los juegos")
struct GameCollectionRelationshipTests {

  @Test("Agregar un juego lo deja visible desde los dos lados")
  func relacionEnAmbosSentidos() throws {
    let context = try hacerContexto()

    let juego = Game(name: "Hollow Knight")
    let coleccion = GameCollection(name: "Metroidvanias")
    context.insert(juego)
    context.insert(coleccion)

    coleccion.add(juego)
    try context.save()

    let coleccionLeida = try #require(try context.fetch(FetchDescriptor<GameCollection>()).first)
    let juegoLeido = try #require(try context.fetch(FetchDescriptor<Game>()).first)

    #expect(coleccionLeida.games.count == 1)
    #expect(
      juegoLeido.collections.count == 1,
      "La relacion inversa se debe poblar sola"
    )
    #expect(juegoLeido.collections.first?.name == "Metroidvanias")
  }

  @Test("Un juego puede estar en varias colecciones a la vez")
  func juegoEnVariasColecciones() throws {
    let context = try hacerContexto()

    let juego = Game(name: "Celeste")
    let favoritos = GameCollection(name: "Favoritos")
    let plataformas = GameCollection(name: "Plataformas")
    context.insert(juego)
    context.insert(favoritos)
    context.insert(plataformas)

    favoritos.add(juego)
    plataformas.add(juego)
    try context.save()

    let leido = try #require(try context.fetch(FetchDescriptor<Game>()).first)

    #expect(leido.collections.count == 2)
    #expect(Set(leido.collections.map(\.name)) == ["Favoritos", "Plataformas"])
  }

  @Test("Una coleccion puede tener varios juegos")
  func coleccionConVariosJuegos() throws {
    let context = try hacerContexto()

    let coleccion = GameCollection(name: "Pendientes")
    context.insert(coleccion)

    for nombre in ["Uno", "Dos", "Tres"] {
      let juego = Game(name: nombre)
      context.insert(juego)
      coleccion.add(juego)
    }
    try context.save()

    let leida = try #require(try context.fetch(FetchDescriptor<GameCollection>()).first)

    #expect(leida.gameCount == 3)
    #expect(leida.isEmpty == false)
  }

  @Test("Agregar dos veces el mismo juego no lo duplica")
  func noDuplicaAlAgregar() throws {
    let context = try hacerContexto()

    let juego = Game(name: "Hades")
    let coleccion = GameCollection(name: "Roguelikes")
    context.insert(juego)
    context.insert(coleccion)

    coleccion.add(juego)
    coleccion.add(juego)
    coleccion.add(juego)
    try context.save()

    #expect(coleccion.gameCount == 1)
  }

  @Test("Quitar un juego lo saca de la coleccion pero NO lo borra")
  func quitarNoBorraElJuego() throws {
    let context = try hacerContexto()

    let juego = Game(name: "Stardew Valley")
    let coleccion = GameCollection(name: "Relajantes")
    context.insert(juego)
    context.insert(coleccion)
    coleccion.add(juego)
    try context.save()

    coleccion.remove(juego)
    try context.save()

    #expect(coleccion.isEmpty)
    #expect(
      try context.fetch(FetchDescriptor<Game>()).count == 1,
      "Sacar un juego de una carpeta no puede borrarlo de la biblioteca"
    )
  }

  @Test("contains dice si el juego ya esta")
  func contieneJuego() throws {
    let coleccion = GameCollection(name: "X")
    let dentro = Game(name: "Dentro")
    let fuera = Game(name: "Fuera")

    coleccion.add(dentro)

    #expect(coleccion.contains(dentro))
    #expect(coleccion.contains(fuera) == false)
  }

  @Test("Las horas de la coleccion suman las de sus juegos")
  func sumaDeHoras() throws {
    let coleccion = GameCollection(name: "X")
    coleccion.add(Game(name: "A", playtimeHours: 10))
    coleccion.add(Game(name: "B", playtimeHours: 5.5))

    #expect(coleccion.totalPlaytimeHours == 15.5)
  }
}

@Suite("Coleccion: borrados")
struct GameCollectionDeletionTests {

  @Test("Borrar una coleccion NO borra sus juegos")
  func borrarColeccionConservaJuegos() throws {
    let context = try hacerContexto()

    let coleccion = GameCollection(name: "Temporal")
    context.insert(coleccion)
    for nombre in ["Uno", "Dos"] {
      let juego = Game(name: nombre)
      context.insert(juego)
      coleccion.add(juego)
    }
    try context.save()

    context.delete(coleccion)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<GameCollection>()).isEmpty)
    #expect(
      try context.fetch(FetchDescriptor<Game>()).count == 2,
      "Borrar una carpeta no puede llevarse los juegos"
    )
  }

  @Test("Borrar un juego NO borra las colecciones donde estaba")
  func borrarJuegoConservaColecciones() throws {
    let context = try hacerContexto()

    let juego = Game(name: "Se va")
    let coleccion = GameCollection(name: "Se queda")
    context.insert(juego)
    context.insert(coleccion)
    coleccion.add(juego)
    try context.save()

    context.delete(juego)
    try context.save()

    let leida = try #require(try context.fetch(FetchDescriptor<GameCollection>()).first)
    #expect(leida.name == "Se queda")
    #expect(leida.isEmpty, "El juego borrado no puede quedar como referencia rota")
  }
}

@Suite("Coleccion: convivencia con la sincronizacion")
struct GameCollectionSyncTests {

  @Test("Re-sincronizar con Steam no saca los juegos de sus colecciones")
  func sincronizarConservaColecciones() throws {
    let context = try hacerContexto()
    let juegos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(juegos, into: context)

    // El usuario organiza
    let coleccion = GameCollection(name: "Mis favoritos")
    context.insert(coleccion)
    let primero = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    coleccion.add(primero)
    try context.save()

    // Steam vuelve a mandar los mismos juegos
    try SteamLibrarySyncer.sync(juegos, into: context)

    let leida = try #require(try context.fetch(FetchDescriptor<GameCollection>()).first)
    #expect(
      leida.gameCount == 1,
      "La organizacion del usuario no la puede deshacer una sincronizacion"
    )
    #expect(leida.games.first?.id == primero.id)
  }
}
