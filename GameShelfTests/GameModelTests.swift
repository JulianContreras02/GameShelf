//
//  GameModelTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@Suite("Modelo de dominio")
struct GameModelTests {

  /// Contenedor en memoria: cada prueba arranca con una base limpia y no toca
  /// el disco.
  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([Game.self, StoreEntry.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
  }

  @Test("Se puede guardar un juego y volver a leerlo")
  func guardarYLeerJuego() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let game = Game(name: "Hollow Knight", playtimeHours: 42.5)
    context.insert(game)
    try context.save()

    let leidos = try context.fetch(FetchDescriptor<Game>())

    #expect(leidos.count == 1)
    #expect(leidos.first?.name == "Hollow Knight")
    #expect(leidos.first?.playtimeHours == 42.5)
    #expect(leidos.first?.status == .backlog)
  }

  @Test("Un juego guarda sus entradas de tienda y la relacion va en ambos sentidos")
  func juegoConEntradasDeTienda() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let game = Game(name: "Celeste")
    let steam = StoreEntry(store: .steam, storeGameID: "504230", playtimeHours: 12)
    let epic = StoreEntry(store: .epic, storeGameID: "celeste-epic", playtimeHours: 3)

    game.storeEntries = [steam, epic]
    context.insert(game)
    try context.save()

    let leido = try #require(try context.fetch(FetchDescriptor<Game>()).first)

    #expect(leido.storeEntries.count == 2)
    // La relacion inversa se debe poblar sola
    #expect(leido.storeEntries.allSatisfy { $0.game?.id == leido.id })
  }

  @Test("El mismo juego en dos tiendas sigue siendo un solo Game")
  func mismoJuegoEnDosTiendas() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let game = Game(name: "Stardew Valley")
    game.storeEntries = [
      StoreEntry(store: .steam, storeGameID: "413150"),
      StoreEntry(store: .psn, storeGameID: "CUSA07056")
    ]
    context.insert(game)
    try context.save()

    let juegos = try context.fetch(FetchDescriptor<Game>())

    #expect(juegos.count == 1, "No debe duplicarse por estar en dos tiendas")
    #expect(juegos.first?.stores == [Store.psn, Store.steam])
    #expect(juegos.first?.isAvailable(on: .steam) == true)
    #expect(juegos.first?.isAvailable(on: .epic) == false)
  }

  @Test("Borrar un juego borra sus entradas de tienda")
  func borrarJuegoBorraEntradas() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let game = Game(name: "Hades")
    game.storeEntries = [StoreEntry(store: .steam, storeGameID: "1145360")]
    context.insert(game)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 1)

    context.delete(game)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Game>()).isEmpty)
    #expect(
      try context.fetch(FetchDescriptor<StoreEntry>()).isEmpty,
      "La regla de borrado en cascada debe limpiar las entradas huerfanas"
    )
  }

  @Test("Los datos personales sobreviven a un cambio de datos de tienda")
  func datosPersonalesNoSePisan() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let game = Game(name: "Elden Ring")
    let entry = StoreEntry(store: .steam, storeGameID: "1245620", playtimeHours: 10)
    game.storeEntries = [entry]
    context.insert(game)

    game.notes = "Jefe pendiente: Malenia"
    game.status = .playing
    try context.save()

    // Simula una re-sincronizacion: cambian las horas, no lo personal
    entry.playtimeHours = 55
    entry.lastSyncedAt = Date()
    try context.save()

    let leido = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(leido.notes == "Jefe pendiente: Malenia")
    #expect(leido.status == .playing)
    #expect(leido.storeEntries.first?.playtimeHours == 55)
  }

  @Test("Cada juego recibe un id distinto")
  func idsUnicos() {
    #expect(Game(name: "A").id != Game(name: "B").id)
  }
}

@Suite("Enums de dominio")
struct DomainEnumTests {

  @Test("Store se guarda por su nombre, no por posicion")
  func storeUsaRawValueEstable() {
    #expect(Store.steam.rawValue == "steam")
    #expect(Store.psn.rawValue == "psn")
    #expect(Store.epic.rawValue == "epic")
    #expect(Store.allCases.count == 3)
  }

  @Test("PlayStatus cubre los cinco estados y solo wishlist no es poseido")
  func playStatusCubreLosCasos() {
    #expect(PlayStatus.allCases.count == 5)
    #expect(PlayStatus.wishlist.isOwned == false)
    #expect(PlayStatus.backlog.isOwned == true)
    #expect(PlayStatus.finished.isOwned == true)
  }
}
