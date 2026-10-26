//
//  SteamSyncMergeTests.swift
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

private func juegoDePSN(_ titleId: String, nombre: String, horas: Double) -> PSNGame {
  PSNGame(
    titleId: titleId, name: nombre, coverURL: nil,
    playtimeHours: horas, playCount: nil, lastPlayedAt: nil, firstPlayedAt: nil, trophyProgress: nil
  )
}

@MainActor
@Suite("Sincronizacion: un juego de otra tienda suma Steam")
struct SteamSyncMergeTests {

  @Test("Un juego que ya vino de PSN no se duplica: suma su entrada de Steam")
  func uneConPSN() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Red Dead Redemption 2", horas: 4)], into: context)

    let resultado = try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1174180, name: "Red Dead Redemption 2", playtimeMinutes: 600)],
      into: context
    )

    #expect(resultado == SteamLibrarySyncer.Result(merged: 1))

    let juegos = try todosLosJuegos(context)
    #expect(juegos.count == 1, "Es el mismo juego, no dos")

    let juego = try #require(juegos.first)
    #expect(Set(juego.stores) == [.steam, .psn])
    #expect(juego.storeEntries.count == 2)
    #expect(juego.playtimeHours == 14, "4 h de PSN + 10 de Steam")
  }

  @Test("Tambien une con Epic")
  func uneConEpic() throws {
    let context = try hacerContexto()
    try EpicLibrarySyncer.sync(
      [EpicGame(namespace: "ns", name: "Cyberpunk 2077", coverURL: nil, playtimeHours: 49.5)],
      into: context
    )

    let resultado = try SteamLibrarySyncer.sync(
      [try hacerDTO(appID: 1091500, name: "Cyberpunk 2077", playtimeMinutes: 30)],
      into: context
    )

    #expect(resultado.merged == 1)
    #expect(try todosLosJuegos(context).count == 1)

    let juego = try #require(try todosLosJuegos(context).first)
    #expect(Set(juego.stores) == [.steam, .epic])
    #expect(juego.playtimeHours == 50, "49,5 h de Epic + media de Steam")
  }

  @Test("Sincronizar Steam otra vez despues de la union no duplica ni suma de mas")
  func unionIdempotente() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Red Dead Redemption 2", horas: 4)], into: context)
    let dto = try hacerDTO(appID: 1174180, name: "Red Dead Redemption 2", playtimeMinutes: 600)

    try SteamLibrarySyncer.sync([dto], into: context)
    let segunda = try SteamLibrarySyncer.sync([dto], into: context)

    #expect(segunda == SteamLibrarySyncer.Result(updated: 1), "La segunda vez ya lo encuentra por su appID")
    #expect(try todosLosJuegos(context).count == 1)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 2, "Una entrada de PSN y una de Steam")
    #expect(try todosLosJuegos(context).first?.playtimeHours == 14, "Las horas se recalculan, no se acumulan")
  }

  @Test("La union no pisa el estado ni las notas del juego que ya estaba")
  func unionRespetaLoDelUsuario() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Hades", horas: 20)], into: context)

    let guardado = try #require(try todosLosJuegos(context).first)
    guardado.status = .finished
    guardado.notes = "Platino conseguido"
    let idOriginal = guardado.id
    let fechaOriginal = guardado.addedAt
    try context.save()

    let dto = try hacerDTO(appID: 1145360, name: "Hades", playtimeMinutes: 300)
    try SteamLibrarySyncer.sync([dto], into: context)
    try SteamLibrarySyncer.sync([dto], into: context)

    let despues = try #require(try todosLosJuegos(context).first)
    #expect(despues.id == idOriginal, "Es el mismo registro, no uno nuevo")
    #expect(despues.status == .finished, "El estado no se puede perder")
    #expect(despues.notes == "Platino conseguido", "Las notas no se pueden perder")
    #expect(despues.addedAt == fechaOriginal)
    #expect(despues.playtimeHours == 25, "20 h de PSN + 5 de Steam")
  }

  @Test("El nombre que ya tenia el juego de otra tienda no se pisa")
  func unionConservaElNombre() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync(
      [juegoDePSN("PPSA1", nombre: "DEATH STRANDING DIRECTOR'S CUT", horas: 1)],
      into: context
    )

    let dto = try hacerDTO(appID: 1850570, name: "Death Stranding Director's Cut")
    try SteamLibrarySyncer.sync([dto], into: context)
    try SteamLibrarySyncer.sync([dto], into: context)

    #expect(try todosLosJuegos(context).count == 1)
    #expect(
      try todosLosJuegos(context).first?.name == "DEATH STRANDING DIRECTOR'S CUT",
      "Si Steam lo pisara, PSN se lo volveria a cambiar en cada sincronizacion"
    )
  }

  @Test("Dos juegos de Steam con el mismo nombre siguen siendo dos")
  func mismoNombreEnSteam() throws {
    let context = try hacerContexto()
    // Resident Evil 4 de 2005 y su remake de 2023: mismo nombre, appID distinto.
    let original = try hacerDTO(appID: 254700, name: "Resident Evil 4", playtimeMinutes: 600)
    let remake = try hacerDTO(appID: 2050650, name: "Resident Evil 4", playtimeMinutes: 1200)

    let primera = try SteamLibrarySyncer.sync([original, remake], into: context)
    let segunda = try SteamLibrarySyncer.sync([original, remake], into: context)

    #expect(primera == SteamLibrarySyncer.Result(created: 2))
    #expect(segunda == SteamLibrarySyncer.Result(updated: 2))
    let horas = try todosLosJuegos(context).map(\.playtimeHours).sorted()
    #expect(horas == [10, 20], "Cada uno conserva sus horas")
  }

  @Test("Un juego unido con Steam no se une con otro appID de su mismo nombre")
  func unionNoPisaOtraEntradaDeSteam() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Resident Evil 4", horas: 3)], into: context)
    let original = try hacerDTO(appID: 254700, name: "Resident Evil 4", playtimeMinutes: 600)
    let remake = try hacerDTO(appID: 2050650, name: "Resident Evil 4", playtimeMinutes: 1200)

    let primera = try SteamLibrarySyncer.sync([original, remake], into: context)
    let segunda = try SteamLibrarySyncer.sync([original, remake], into: context)

    #expect(primera == SteamLibrarySyncer.Result(created: 1, merged: 1))
    #expect(segunda == SteamLibrarySyncer.Result(updated: 2))
    #expect(try todosLosJuegos(context).count == 2)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 3)
    let horas = try todosLosJuegos(context).map(\.playtimeHours).sorted()
    #expect(horas == [13, 20], "3 h de PSN + 10 del original, y el remake aparte con sus 20")
  }
}
