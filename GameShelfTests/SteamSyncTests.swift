//
//  SteamSyncTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

/// Construye un `SteamGameDTO` decodificando JSON, porque sus propiedades son
/// `let` sin inicializador publico.
private func hacerDTO(
  appID: Int,
  name: String? = "Un Juego",
  playtimeMinutes: Int = 60,
  playtime2Weeks: Int? = nil
) throws -> SteamGameDTO {
  var campos: [String] = ["\"appid\": \(appID)", "\"playtime_forever\": \(playtimeMinutes)"]
  if let name { campos.append("\"name\": \"\(name)\"") }
  if let playtime2Weeks { campos.append("\"playtime_2weeks\": \(playtime2Weeks)") }
  let json = "{\(campos.joined(separator: ","))}"
  return try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
}

private func hacerContexto() throws -> ModelContext {
  let schema = Schema([Game.self, StoreEntry.self])
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}

private func todosLosJuegos(_ context: ModelContext) throws -> [Game] {
  try context.fetch(FetchDescriptor<Game>())
}

@Suite("Mapeo de Steam a dominio")
struct SteamGameMapperTests {

  @Test("Un DTO se convierte en Game con su entrada de Steam")
  func mapeoBasico() throws {
    let dto = try hacerDTO(appID: 440, name: "Team Fortress 2", playtimeMinutes: 1234)

    let game = SteamGameMapper.makeGame(from: dto)

    #expect(game.name == "Team Fortress 2")
    #expect(game.storeEntries.count == 1)
    #expect(game.storeEntries.first?.store == .steam)
    #expect(game.storeEntries.first?.storeGameID == "440")
  }

  @Test("Los minutos de Steam se guardan como horas")
  func minutosAHoras() throws {
    let dto = try hacerDTO(appID: 1, playtimeMinutes: 90)

    let game = SteamGameMapper.makeGame(from: dto)

    #expect(game.playtimeHours == 1.5)
    #expect(game.storeEntries.first?.playtimeHours == 1.5)
  }

  @Test("La caratula se construye a partir del appID")
  func caratula() throws {
    let game = SteamGameMapper.makeGame(from: try hacerDTO(appID: 440))

    #expect(
      game.coverImageURL == "https://cdn.cloudflare.steamstatic.com/steam/apps/440/header.jpg"
    )
  }

  @Test("Un juego sin nombre recibe uno con su appID, no queda en blanco")
  func sinNombre() throws {
    let game = SteamGameMapper.makeGame(from: try hacerDTO(appID: 999, name: nil))

    #expect(game.name == "Juego de Steam 999")
    #expect(game.name.isEmpty == false)
  }

  @Test("Un juego nuevo arranca en backlog y sin notas")
  func valoresInicialesPersonales() throws {
    let game = SteamGameMapper.makeGame(from: try hacerDTO(appID: 1))

    #expect(game.status == .backlog)
    #expect(game.notes.isEmpty)
  }

  @Test("Las horas totales suman todas las tiendas, no solo Steam")
  func sumaDeVariasTiendas() throws {
    let game = SteamGameMapper.makeGame(from: try hacerDTO(appID: 1, playtimeMinutes: 60))
    game.storeEntries.append(
      StoreEntry(store: .psn, storeGameID: "CUSA123", playtimeHours: 4)
    )

    SteamGameMapper.recalculatePlaytime(for: game)

    #expect(game.playtimeHours == 5, "1 hora de Steam + 4 de PSN")
  }
}

@Suite("Sincronizacion: no duplicar")
struct SteamSyncIdempotencyTests {

  @Test("La primera sincronizacion crea los juegos")
  func primeraSincronizacion() throws {
    let context = try hacerContexto()
    let dtos = [try hacerDTO(appID: 1), try hacerDTO(appID: 2)]

    let result = try SteamLibrarySyncer.sync(dtos, into: context)

    #expect(result.created == 2)
    #expect(result.updated == 0)
    #expect(try todosLosJuegos(context).count == 2)
  }

  @Test("Sincronizar dos veces lo mismo NO duplica")
  func sincronizarDosVeces() throws {
    let context = try hacerContexto()
    let dtos = [try hacerDTO(appID: 1), try hacerDTO(appID: 2)]

    try SteamLibrarySyncer.sync(dtos, into: context)
    let segunda = try SteamLibrarySyncer.sync(dtos, into: context)

    #expect(segunda.created == 0, "No deberia crear nada la segunda vez")
    #expect(segunda.updated == 2)
    #expect(try todosLosJuegos(context).count == 2, "Siguen siendo 2 juegos, no 4")
  }

  @Test("Diez sincronizaciones seguidas dejan la base igual")
  func muchasSincronizaciones() throws {
    let context = try hacerContexto()
    let dtos = [try hacerDTO(appID: 1), try hacerDTO(appID: 2), try hacerDTO(appID: 3)]

    for _ in 1...10 {
      try SteamLibrarySyncer.sync(dtos, into: context)
    }

    #expect(try todosLosJuegos(context).count == 3)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 3)
  }

  @Test("Un juego nuevo en la segunda sincronizacion se agrega sin tocar los viejos")
  func juegoNuevoDespues() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1)], into: context)

    let result = try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1), try hacerDTO(appID: 2)],
      into: context
    )

    #expect(result.created == 1)
    #expect(result.updated == 1)
    #expect(try todosLosJuegos(context).count == 2)
  }

  @Test("Un juego que ya no viene de Steam NO se borra")
  func noBorraLoQueFalta() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1), try hacerDTO(appID: 2)],
      into: context
    )

    // La segunda respuesta trae solo uno
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1)], into: context)

    #expect(
      try todosLosJuegos(context).count == 2,
      "Borrar juegos por una respuesta incompleta seria peor que dejarlos"
    )
  }

  @Test("Una respuesta vacia no borra ni cambia nada")
  func respuestaVacia() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1)], into: context)

    let result = try SteamLibrarySyncer.sync([], into: context)

    #expect(result == SteamLibrarySyncer.Result())
    #expect(try todosLosJuegos(context).count == 1)
  }
}

@Suite("Sincronizacion: los datos del usuario son sagrados")
struct SteamSyncPreservesUserDataTests {

  /// La prueba mas importante del proyecto hasta ahora: re-sincronizar no puede
  /// borrar lo que el usuario escribio.
  @Test("Re-sincronizar NO borra las notas ni el estado")
  func noPisaDatosPersonales() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 440)], into: context)

    // El usuario personaliza el juego
    let guardado = try #require(try todosLosJuegos(context).first)
    guardado.notes = "Jefe pendiente: Malenia"
    guardado.status = .playing
    let idOriginal = guardado.id
    let fechaOriginal = guardado.addedAt
    try context.save()

    // Steam devuelve datos nuevos (jugo mas horas)
    try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 440, playtimeMinutes: 6000)],
      into: context
    )

    let despues = try #require(try todosLosJuegos(context).first)
    #expect(despues.notes == "Jefe pendiente: Malenia", "Las notas no se pueden perder")
    #expect(despues.status == .playing, "El estado no se puede perder")
    #expect(despues.id == idOriginal, "Debe ser el mismo registro, no uno nuevo")
    #expect(despues.addedAt == fechaOriginal)
    #expect(despues.playtimeHours == 100, "Las horas SI se actualizan")
  }

  @Test("Diez sincronizaciones seguidas tampoco se comen las notas")
  func notasSobrevivenMuchasSincronizaciones() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1)], into: context)

    let juego = try #require(try todosLosJuegos(context).first)
    juego.notes = "No borrar"
    juego.status = .finished
    try context.save()

    for minutos in stride(from: 100, through: 1000, by: 100) {
      try SteamLibrarySyncer.sync(
        [try hacerDTO(appID: 1, playtimeMinutes: minutos)],
        into: context
      )
    }

    let final = try #require(try todosLosJuegos(context).first)
    #expect(final.notes == "No borrar")
    #expect(final.status == .finished)
    #expect(final.playtimeHours == 1000.0 / 60)
  }

  @Test("El nombre y la caratula si se refrescan si Steam los cambia")
  func datosDeSteamSiSeActualizan() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1, name: "Nombre Viejo")],
      into: context
    )

    try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1, name: "Nombre Nuevo")],
      into: context
    )

    #expect(try todosLosJuegos(context).first?.name == "Nombre Nuevo")
  }

  @Test("Si Steam deja de mandar el nombre, se conserva el que ya habia")
  func nombreAusenteNoBorraElExistente() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1, name: "Nombre Bueno")],
      into: context
    )

    // Respuesta sin include_appinfo: llega sin nombre
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1, name: nil)], into: context)

    #expect(
      try todosLosJuegos(context).first?.name == "Nombre Bueno",
      "Un nombre ausente no debe reemplazar uno bueno por el generico"
    )
  }

  @Test("Sincronizar Steam no toca las entradas de otras tiendas")
  func noTocaOtrasTiendas() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1, playtimeMinutes: 60)], into: context)

    // El juego tambien esta en PSN
    let juego = try #require(try todosLosJuegos(context).first)
    juego.storeEntries.append(
      StoreEntry(store: .psn, storeGameID: "CUSA123", playtimeHours: 10)
    )
    SteamGameMapper.recalculatePlaytime(for: juego)
    try context.save()

    try SteamLibrarySyncer.sync([try hacerDTO(appID: 1, playtimeMinutes: 120)], into: context)

    let despues = try #require(try todosLosJuegos(context).first)
    let psn = try #require(despues.storeEntries.first { $0.store == .psn })

    #expect(despues.storeEntries.count == 2)
    #expect(psn.playtimeHours == 10, "Las horas de PSN no se tocan al sincronizar Steam")
    #expect(despues.playtimeHours == 12, "2 h de Steam + 10 de PSN")
  }
}

@Suite("Sincronizacion: datos realistas")
struct SteamSyncRealisticTests {

  @Test("Sincroniza la respuesta guardada de Steam")
  func sincronizaFixture() throws {
    let context = try hacerContexto()
    let payload = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response

    let result = try SteamLibrarySyncer.sync(payload.games, into: context)

    #expect(result.created == 5)
    #expect(try todosLosJuegos(context).count == 5)

    // El juego sin nombre del fixture recibe el generico
    let juegos = try todosLosJuegos(context)
    #expect(juegos.contains { $0.name == "Juego de Steam 1245620" })
  }

  @Test("Sincronizar el fixture dos veces no duplica")
  func fixtureEsIdempotente() throws {
    let context = try hacerContexto()
    let juegos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(juegos, into: context)
    let segunda = try SteamLibrarySyncer.sync(juegos, into: context)

    #expect(segunda.created == 0)
    #expect(segunda.updated == 5)
    #expect(try todosLosJuegos(context).count == 5)
  }
}
