//
//  PSNSyncTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@MainActor
private func hacerContexto() throws -> ModelContext {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let contenedor = try ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self,
    configurations: config
  )
  return ModelContext(contenedor)
}

private func juegoDePSN(
  _ titleId: String = "PPSA00001_00",
  nombre: String = "Un Juego",
  horas: Double? = 10,
  trofeos: Int? = 50,
  veces: Int? = 3
) -> PSNGame {
  PSNGame(
    titleId: titleId,
    name: nombre,
    coverURL: URL(string: "https://ejemplo.test/\(titleId).png"),
    playtimeHours: horas,
    playCount: veces,
    lastPlayedAt: Date(timeIntervalSince1970: 1_700_000_000),
    firstPlayedAt: Date(timeIntervalSince1970: 1_600_000_000),
    trophyProgress: trofeos
  )
}

@MainActor
@Suite("PSN: guardar la biblioteca")
struct PSNSyncTests {

  @Test("Guarda los juegos con sus trofeos")
  func guarda() throws {
    let context = try hacerContexto()

    let resultado = try PSNLibrarySyncer.sync(
      [juegoDePSN("A", nombre: "Halo", trofeos: 88), juegoDePSN("B", nombre: "GTA V", trofeos: 3)],
      into: context
    )

    #expect(resultado.created == 2)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    let halo = try #require(juegos.first { $0.name == "Halo" })
    #expect(halo.trophyProgress == 88)
    #expect(halo.stores == [.psn])
    #expect(halo.status == .backlog, "El estado lo pone el usuario")
  }

  @Test("Sincronizar dos veces no duplica")
  func idempotente() throws {
    let context = try hacerContexto()
    let juegos = [juegoDePSN("A"), juegoDePSN("B", nombre: "Otro")]

    try PSNLibrarySyncer.sync(juegos, into: context)
    let segunda = try PSNLibrarySyncer.sync(juegos, into: context)

    #expect(segunda.created == 0)
    #expect(segunda.updated == 2)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 2)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 2)
  }

  @Test("Un juego que ya vino de Steam no se duplica: suma su entrada de PSN")
  func uneConSteam() throws {
    let context = try hacerContexto()

    let json = #"{"appid": 1, "name": "Red Dead Redemption 2", "playtime_forever": 600}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)

    let resultado = try PSNLibrarySyncer.sync(
      [juegoDePSN("PPSA1", nombre: "Red Dead Redemption 2", horas: 4, trofeos: 30)],
      into: context
    )

    #expect(resultado.merged == 1)
    #expect(resultado.created == 0)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 1, "Es el mismo juego, no dos")

    let juego = try #require(juegos.first)
    #expect(Set(juego.stores) == [.steam, .psn])
    #expect(juego.trophyProgress == 30)

    // 10 h de Steam + 4 h de PSN
    #expect(juego.playtimeHours == 14, "Las horas se suman entre tiendas")
  }

  @Test("La union ignora mayusculas y tildes")
  func unionNormalizada() throws {
    let context = try hacerContexto()
    let json = #"{"appid": 1, "name": "Assassin's Creed Shadows", "playtime_forever": 60}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)

    let resultado = try PSNLibrarySyncer.sync(
      [juegoDePSN("P1", nombre: "ASSASSIN'S CREED SHADOWS")],
      into: context
    )

    #expect(resultado.merged == 1)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }

  @Test("No pisa el estado ni las notas")
  func respetaLoDelUsuario() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("A", nombre: "Halo")], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    juego.status = .finished
    juego.notes = "Platino conseguido"
    try context.save()

    try PSNLibrarySyncer.sync([juegoDePSN("A", nombre: "Halo", trofeos: 100)], into: context)

    let despues = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(despues.status == .finished)
    #expect(despues.notes == "Platino conseguido")
    #expect(despues.trophyProgress == 100, "Los trofeos si se refrescan: son de la tienda")
  }

  @Test("Una duracion ilegible no borra las horas que ya habia")
  func noPisaLasHorasConCero() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("A", horas: 25)], into: context)

    // Si PSN manda una duracion que no se puede leer, `playtimeHours` es nil.
    // Guardar 0 seria perder 25 horas reales.
    try PSNLibrarySyncer.sync([juegoDePSN("A", horas: nil)], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(juego.playtimeHours == 25)
  }

  @Test("Un juego sin trofeos no se marca con cero")
  func sinTrofeos() throws {
    let context = try hacerContexto()

    try PSNLibrarySyncer.sync([juegoDePSN("A", trofeos: nil)], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    // nil es "no tiene trofeos"; 0 seria "los tiene y no llevas ninguno".
    #expect(juego.trophyProgress == nil)
  }

  @Test("Una lista vacia no toca nada")
  func listaVacia() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("A")], into: context)

    let resultado = try PSNLibrarySyncer.sync([], into: context)

    #expect(resultado.total == 0)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1, "No se borra lo guardado")
  }
}

@MainActor
@Suite("PSN: de la respuesta real a la base")
struct PSNEndToEndTests {

  @Test("Sincroniza la biblioteca real completa")
  func deExtremoAExtremo() async throws {
    let context = try hacerContexto()

    let juegos = try String(data: Fixture.data("psn_juegos"), encoding: .utf8) ?? ""
    let mapa = try String(data: Fixture.data("psn_mapa_trofeos"), encoding: .utf8) ?? ""

    let servicio = PSNLibraryService(
      client: RoutingHTTPClient(rutas: [
        ("gamelist", juegos),
        ("trophyTitles", mapa)
      ]),
      accessToken: { "TOKEN" }
    )

    let resultado = try await servicio.fetchPlayedGames()

    // 40 entradas menos Crunchyroll, que es una app y no un juego.
    #expect(resultado.count == 39)

    try PSNLibrarySyncer.sync(resultado, into: context)

    // Quedan 36 y no 39 porque tres juegos aparecen dos veces en PSN: una vez
    // como version de consola y otra como version de PC. Son el mismo juego y
    // se guardan como uno solo, con una entrada por version.
    let guardados = try context.fetch(FetchDescriptor<Game>())
    #expect(guardados.count == 36)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 39)
    #expect(guardados.allSatisfy { $0.stores == [.psn] })
    #expect(guardados.allSatisfy { $0.coverImageURL != nil })

    let halo = try #require(guardados.first { $0.name == "Halo: Campaign Evolved" })
    #expect(halo.trophyProgress == 88, "El progreso viene del mapa, no del nombre")
    #expect(abs(halo.playtimeHours - 29.795) < 0.01)

    // Los que no estaban en la tanda de trofeos que se pidio quedan sin
    // progreso, y eso es correcto: no se inventa un cero.
    let conTrofeos = guardados.filter { $0.trophyProgress != nil }
    #expect(conTrofeos.count == 5, "Solo se pidieron los trofeos de 5 juegos")
  }

  @Test("Un juego con version de consola y de PC suma las dos, sin duplicarse")
  func versionDeConsolaYDePC() throws {
    let context = try hacerContexto()

    // Es el caso real de Until Dawn: 39 minutos en PS5 y 11 h 42 en PC, con
    // titleId distintos y el mismo nombre.
    try PSNLibrarySyncer.sync([
      juegoDePSN("PPSA15421_00", nombre: "Until Dawn", horas: 0.66, trofeos: 10),
      juegoDePSN("PPSA24581_00", nombre: "Until Dawn", horas: 11.7, trofeos: 45)
    ], into: context)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 1, "Es un juego, no dos")

    let juego = try #require(juegos.first)
    #expect(juego.storeEntries.count == 2, "Una entrada por version")
    #expect(abs(juego.playtimeHours - 12.36) < 0.01, "Las horas se suman")
    #expect(juego.trophyProgress == 45, "El progreso mas alto de las dos")
  }

  @Test("Volver a sincronizar las dos versiones no las duplica")
  func versionesIdempotentes() throws {
    let context = try hacerContexto()
    let ambas = [
      juegoDePSN("A1", nombre: "Ghost of Tsushima", horas: 1.7),
      juegoDePSN("A2", nombre: "Ghost of Tsushima", horas: 1.1)
    ]

    try PSNLibrarySyncer.sync(ambas, into: context)
    try PSNLibrarySyncer.sync(ambas, into: context)

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 2)
    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(abs(juego.playtimeHours - 2.8) < 0.01, "No se acumulan al re-sincronizar")
  }

  @Test("Crunchyroll no entra en la biblioteca")
  func lasAppsSeQuedanFuera() async throws {
    let juegos = try String(data: Fixture.data("psn_juegos"), encoding: .utf8) ?? ""

    let servicio = PSNLibraryService(
      client: RoutingHTTPClient(rutas: [("gamelist", juegos), ("trophyTitles", #"{"titles":[]}"#)]),
      accessToken: { "TOKEN" }
    )

    let resultado = try await servicio.fetchPlayedGames()

    #expect(!resultado.contains { $0.name == "Crunchyroll" })
  }
}
