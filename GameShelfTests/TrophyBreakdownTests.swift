//
//  TrophyBreakdownTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@Suite("Trofeos: conteos por tipo")
struct TrophyCountsTests {

  @Test("Suma los cuatro tipos")
  func total() {
    let cuentas = TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1)

    #expect(cuentas.total == 58)
    #expect(!cuentas.isEmpty)
  }

  @Test("Un juego sin trofeos esta vacio")
  func vacio() {
    #expect(TrophyCounts().isEmpty)
    #expect(TrophyCounts().total == 0)
  }

  @Test("Devuelve el conteo de cada tipo")
  func porTipo() {
    let cuentas = TrophyCounts(bronze: 10, silver: 5, gold: 2, platinum: 1)

    #expect(cuentas.count(of: .bronze) == 10)
    #expect(cuentas.count(of: .silver) == 5)
    #expect(cuentas.count(of: .gold) == 2)
    #expect(cuentas.count(of: .platinum) == 1)
  }

  @Test("Los cuatro tipos tienen nombre, y el platino se explica")
  func textos() {
    for tipo in TrophyKind.allCases {
      #expect(!tipo.displayName.isEmpty, "Falta el nombre de \(tipo)")
    }

    // El platino es el unico que no se entiende solo.
    #expect(TrophyKind.platinum.explanation?.isEmpty == false)
    #expect(TrophyKind.bronze.explanation == nil)
  }

  @Test("El orden es el de la consola, con el platino al final")
  func orden() {
    #expect(TrophyKind.allCases == [.bronze, .silver, .gold, .platinum])
  }
}

@Suite("Trofeos: leerlos de la respuesta de PSN")
struct TrophyDTOTests {

  @Test("Convierte los conteos del DTO")
  func desdeElDTO() {
    let dto = PSNTrophyCountsDTO(bronze: 52, silver: 3, gold: 2, platinum: 1)

    #expect(dto.counts == TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1))
  }

  @Test("Los campos que falten cuentan como cero")
  func camposQueFaltan() {
    let dto = PSNTrophyCountsDTO(bronze: 10, silver: nil, gold: nil, platinum: nil)

    #expect(dto.counts == TrophyCounts(bronze: 10, silver: 0, gold: 0, platinum: 0))
  }

  @Test("Lee el desglose real de la respuesta guardada")
  func respuestaReal() throws {
    let mapa = try Fixture.decode(PSNTrophyMapResponse.self, from: "psn_mapa_trofeos")
    let halo = try #require(mapa.progresoPorTitleID["PPSA28038_00"])

    #expect(halo.progress == 88)
    #expect(halo.definedTrophies?.counts == TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1))
    #expect(halo.earnedTrophies?.counts == TrophyCounts(bronze: 52, silver: 2, gold: 1, platinum: 0))
  }

  @Test("El desglose explica lo que el porcentaje no dice")
  func loQueAportaElDesglose() throws {
    let mapa = try Fixture.decode(PSNTrophyMapResponse.self, from: "psn_mapa_trofeos")
    let halo = try #require(mapa.progresoPorTitleID["PPSA28038_00"])
    let conseguidos = try #require(halo.earnedTrophies?.counts)
    let definidos = try #require(halo.definedTrophies?.counts)

    // 88% no dice que lo que falta es justo el platino y un oro.
    #expect(conseguidos.bronze == definidos.bronze, "Todos los bronces estan")
    #expect(conseguidos.platinum < definidos.platinum, "El platino es lo que falta")
  }
}

@MainActor
@Suite("Trofeos: guardar el desglose")
struct TrophyPersistenceTests {

  private func hacerContexto() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let contenedor = try ModelContainer(
      for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self,
      configurations: config
    )
    return ModelContext(contenedor)
  }

  private func juego(
    _ titleId: String = "P1",
    nombre: String = "Halo",
    progreso: Int? = 88,
    conseguidos: TrophyCounts? = TrophyCounts(bronze: 52, silver: 2, gold: 1, platinum: 0),
    definidos: TrophyCounts? = TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1)
  ) -> PSNGame {
    PSNGame(
      titleId: titleId,
      name: nombre,
      coverURL: nil,
      playtimeHours: 10,
      playCount: 1,
      lastPlayedAt: nil,
      firstPlayedAt: nil,
      trophyProgress: progreso,
      earnedTrophies: conseguidos,
      definedTrophies: definidos
    )
  }

  @Test("El desglose sobrevive al guardado")
  func seGuarda() throws {
    let context = try hacerContexto()

    try PSNLibrarySyncer.sync([juego()], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    let desglose = try #require(guardado.trophyBreakdown)

    #expect(desglose.defined.total == 58)
    #expect(desglose.earned.bronze == 52)
    #expect(desglose.earned.platinum == 0)
  }

  @Test("Un juego sin trofeos no tiene desglose")
  func sinTrofeos() throws {
    let context = try hacerContexto()

    try PSNLibrarySyncer.sync(
      [juego(progreso: nil, conseguidos: nil, definidos: nil)],
      into: context
    )

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(guardado.trophyBreakdown == nil)
    #expect(guardado.trophyProgress == nil)
  }

  @Test("Con dos listas de trofeos se muestra la mas avanzada")
  func dosListas() throws {
    let context = try hacerContexto()

    // Es el caso de un juego que esta en PS4 y en PS5, cada version con su
    // propia lista. La que interesa es la que lleva mas.
    try PSNLibrarySyncer.sync([
      juego(
        "PS4", nombre: "Until Dawn", progreso: 20,
        conseguidos: TrophyCounts(bronze: 5),
        definidos: TrophyCounts(bronze: 30, silver: 5, gold: 2, platinum: 1)
      ),
      juego(
        "PS5", nombre: "Until Dawn", progreso: 75,
        conseguidos: TrophyCounts(bronze: 25, silver: 4),
        definidos: TrophyCounts(bronze: 30, silver: 5, gold: 2, platinum: 1)
      )
    ], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    let desglose = try #require(guardado.trophyBreakdown)

    #expect(guardado.trophyProgress == 75)
    #expect(desglose.earned.bronze == 25, "El desglose es el de la version mas avanzada")
    #expect(desglose.earned.silver == 4)
  }

  @Test("El porcentaje del desglose es el de la lista que se muestra")
  func porcentajeCoherente() throws {
    let context = try hacerContexto()

    // Una entrada vieja, guardada antes de que se guardaran los conteos: tiene
    // porcentaje pero no desglose. Y otra con desglose, pero menos avanzada.
    let juego = Game(name: "Until Dawn")
    juego.storeEntries = [
      StoreEntry(store: .psn, storeGameID: "PS4", trophyProgress: 90),
      StoreEntry(
        store: .psn,
        storeGameID: "PS5",
        trophyProgress: 50,
        earnedTrophies: TrophyCounts(bronze: 15),
        definedTrophies: TrophyCounts(bronze: 30, silver: 5, gold: 2, platinum: 1)
      )
    ]
    context.insert(juego)

    let desglose = try #require(juego.trophyBreakdown)

    // Sin esto la ficha ensena "90%" encima de un "15 / 38" que sale de la
    // otra lista, y los dos numeros se contradicen.
    #expect(desglose.progress == 50)
    #expect(desglose.earned.total == 15)
  }

  @Test("Re-sincronizar refresca el desglose")
  func seRefresca() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juego()], into: context)

    // Se consiguio el platino.
    try PSNLibrarySyncer.sync([
      juego(
        progreso: 100,
        conseguidos: TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1),
        definidos: TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1)
      )
    ], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    let desglose = try #require(guardado.trophyBreakdown)

    #expect(desglose.earned.platinum == 1)
    #expect(guardado.trophyProgress == 100)
  }

  @Test("Sin desglose nuevo se conserva el que habia")
  func noBorraElDesglose() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juego()], into: context)

    // Si una respuesta viene sin los conteos, borrarlos dejaria la ficha peor
    // que antes.
    try PSNLibrarySyncer.sync(
      [juego(progreso: 90, conseguidos: nil, definidos: nil)],
      into: context
    )

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(guardado.trophyBreakdown != nil)
    #expect(guardado.trophyProgress == 90, "El porcentaje si se actualizo")
  }

  @Test("De la respuesta real a la ficha, de punta a punta")
  func deExtremoAExtremo() async throws {
    let context = try hacerContexto()

    let juegos = try String(data: Fixture.data("psn_juegos"), encoding: .utf8) ?? ""
    let mapa = try String(data: Fixture.data("psn_mapa_trofeos"), encoding: .utf8) ?? ""

    let servicio = PSNLibraryService(
      client: RoutingHTTPClient(rutas: [("gamelist", juegos), ("trophyTitles", mapa)]),
      accessToken: { "TOKEN" }
    )

    try PSNLibrarySyncer.sync(try await servicio.fetchPlayedGames(), into: context)

    let halo = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.name == "Halo: Campaign Evolved" }
    )
    let desglose = try #require(halo.trophyBreakdown)

    #expect(halo.trophyProgress == 88)
    #expect(desglose.defined == TrophyCounts(bronze: 52, silver: 3, gold: 2, platinum: 1))
    #expect(desglose.earned == TrophyCounts(bronze: 52, silver: 2, gold: 1, platinum: 0))
  }
}
