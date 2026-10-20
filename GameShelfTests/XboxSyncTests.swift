//
//  XboxSyncTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@Suite("Xbox: comparar nombres entre tiendas")
struct XboxNameMatchingTests {

  private func clave(_ nombre: String) -> String {
    LibraryMatcher.clave(de: nombre)
  }

  @Test("Ignora las marcas registradas, ademas de mayusculas y tildes")
  func marcas() {
    #expect(clave("Assassin's Creed® Syndicate") == clave("assassin's creed syndicate"))
    #expect(clave("Forza Horizon 5™") == clave("Forza Horizon 5"))
    #expect(clave("Pokémon©") == clave("POKEMON"))
  }

  @Test("Quitar la marca no deja espacios de mas")
  func sinEspaciosDeMas() {
    #expect(clave("Halo ™") == clave("Halo"))
  }

  @Test("No junta juegos que si son distintos")
  func distintos() {
    #expect(clave("Halo 3") != clave("Halo 3: ODST"))
  }
}

@MainActor
@Suite("Xbox: guardar y deduplicar")
struct XboxSyncTests {

  private func hacerContexto() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let contenedor = try ModelContainer(
      for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self,
      configurations: config
    )
    return ModelContext(contenedor)
  }

  private func juego(
    _ titleId: String,
    _ nombre: String,
    horas: Double? = 5,
    puntos: Gamerscore? = Gamerscore(earned: 100, total: 1000)
  ) -> XboxGame {
    XboxGame(titleId: titleId, name: nombre, coverURL: nil, playtimeHours: horas, lastPlayedAt: nil, gamerscore: puntos)
  }

  @Test("Guarda los juegos con su entrada de Xbox y su Gamerscore")
  func guarda() throws {
    let context = try hacerContexto()

    let resultado = try XboxLibrarySyncer.sync([juego("1", "Halo Infinite"), juego("2", "Starfield")], into: context)

    #expect(resultado.created == 2)
    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.allSatisfy { $0.stores == [.xbox] })
    #expect(juegos.allSatisfy { $0.status == .backlog })
    #expect(juegos.allSatisfy { $0.gamerscore == Gamerscore(earned: 100, total: 1000) })
    #expect(juegos.allSatisfy { $0.trophyProgress == nil }, "El Gamerscore no se hace pasar por trofeos")
  }

  @Test("Sincronizar dos veces no duplica")
  func idempotente() throws {
    let context = try hacerContexto()
    let lista = [juego("1", "Halo Infinite"), juego("2", "Starfield")]

    try XboxLibrarySyncer.sync(lista, into: context)
    let segunda = try XboxLibrarySyncer.sync(lista, into: context)

    #expect(segunda.created == 0)
    #expect(segunda.updated == 2)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 2)
  }

  @Test("Un juego que ya estaba en Steam no se duplica, aunque Xbox le ponga ®")
  func deduplicaConSteam() throws {
    let context = try hacerContexto()
    let json = #"{"appid": 1, "name": "Assassin's Creed Syndicate", "playtime_forever": 600}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)

    let resultado = try XboxLibrarySyncer.sync(
      [juego("1560034050", "Assassin's Creed® Syndicate", horas: 20)],
      into: context
    )

    #expect(resultado.merged == 1)
    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 1)

    let unico = try #require(juegos.first)
    #expect(Set(unico.stores) == [.steam, .xbox])
    #expect(abs(unico.playtimeHours - 30) < 0.01, "10 h de Steam mas 20 de Xbox")
    #expect(unico.name == "Assassin's Creed Syndicate", "Se conserva el nombre que ya tenia")
  }

  @Test("Tambien deduplica contra PlayStation y conserva sus trofeos")
  func deduplicaConPSN() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([
      PSNGame(
        titleId: "PPSA1", name: "Minecraft", coverURL: nil,
        playtimeHours: 2, playCount: 1, lastPlayedAt: nil, firstPlayedAt: nil, trophyProgress: 40
      )
    ], into: context)

    let resultado = try XboxLibrarySyncer.sync([juego("1828326430", "Minecraft")], into: context)

    #expect(resultado.merged == 1)
    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(Set(unico.stores) == [.psn, .xbox])
    #expect(unico.trophyProgress == 40, "Lo de PlayStation se conserva")
    #expect(unico.gamerscore != nil, "Y se suma lo de Xbox")
  }

  @Test("No pisa el estado ni las notas")
  func respetaLoDelUsuario() throws {
    let context = try hacerContexto()
    try XboxLibrarySyncer.sync([juego("1", "Halo Infinite")], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    guardado.status = .finished
    guardado.notes = "Terminado"
    try context.save()

    try XboxLibrarySyncer.sync([juego("1", "Halo Infinite", horas: 30)], into: context)

    let despues = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(despues.status == .finished)
    #expect(despues.notes == "Terminado")
    #expect(despues.playtimeHours == 30, "Las horas si se refrescan")
  }

  @Test("Si esta vez no llegaron horas, se conservan las que habia")
  func horasQueNoLlegaron() throws {
    let context = try hacerContexto()
    try XboxLibrarySyncer.sync([juego("1", "Halo Infinite", horas: 30)], into: context)

    try XboxLibrarySyncer.sync([juego("1", "Halo Infinite", horas: nil)], into: context)

    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(unico.playtimeHours == 30, "Una consulta de horas fallida no las pone en cero")
  }

  @Test("El Gamerscore se refresca")
  func refrescaGamerscore() throws {
    let context = try hacerContexto()
    let antes = Gamerscore(earned: 100, total: 1000)
    let despues = Gamerscore(earned: 250, total: 1000)
    try XboxLibrarySyncer.sync([juego("1", "Halo Infinite", puntos: antes)], into: context)

    try XboxLibrarySyncer.sync([juego("1", "Halo Infinite", puntos: despues)], into: context)

    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(unico.gamerscore == despues)
  }

  @Test("Un juego sin logros no ensena Gamerscore")
  func sinLogros() throws {
    let context = try hacerContexto()

    try XboxLibrarySyncer.sync([juego("1", "Call of Duty: Modern Warfare", puntos: nil)], into: context)

    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(unico.gamerscore == nil)
  }

  @Test("Dos versiones del mismo juego acaban en uno, con una entrada cada una")
  func dosVersiones() throws {
    let context = try hacerContexto()

    // La de Xbox 360 y la de Xbox One: mismo nombre, otro titleId, y cada una
    // con sus logros y sus horas.
    let resultado = try XboxLibrarySyncer.sync([
      juego("360", "Fallout 3", horas: 40, puntos: Gamerscore(earned: 1000, total: 1000)),
      juego("one", "Fallout 3", horas: 2, puntos: Gamerscore(earned: 50, total: 1000))
    ], into: context)

    #expect(resultado.created == 1)
    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(unico.storeEntries.count == 2, "Una no pisa a la otra")
    #expect(unico.playtimeHours == 42, "Las horas de las dos se suman")
    #expect(unico.gamerscore == Gamerscore(earned: 1000, total: 1000), "Se ensena la mas avanzada")

    // Y la segunda vez cada una se reconoce por su id.
    let segunda = try XboxLibrarySyncer.sync([
      juego("360", "Fallout 3", horas: 40),
      juego("one", "Fallout 3", horas: 3)
    ], into: context)
    #expect(segunda.updated == 2)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }
}
