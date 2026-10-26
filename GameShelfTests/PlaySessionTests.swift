//
//  PlaySessionTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

/// Una fecha fija, para que las duraciones no dependan de cuando corre la
/// prueba.
private let inicio = Date(timeIntervalSince1970: 1_700_000_000)

@Suite("Sesion de juego: el modelo")
struct PlaySessionModelTests {

  @Test("Una sesion recien empezada esta activa y cuenta hasta ahora")
  func activa() {
    let sesion = PlaySession(startDate: inicio)

    #expect(sesion.isActive)
    #expect(sesion.endDate == nil)
    #expect(sesion.duration(at: inicio.addingTimeInterval(90)) == 90)
  }

  @Test("Sin fecha de fin, duration usa la hora actual")
  func usaLaHoraActual() {
    let sesion = PlaySession(startDate: Date.now.addingTimeInterval(-60))

    #expect(sesion.duration >= 60)
    #expect(sesion.duration < 120)
  }

  @Test("Una sesion cerrada dura lo mismo la mires cuando la mires")
  func cerrada() throws {
    let sesion = PlaySession(startDate: inicio)

    try sesion.end(at: inicio.addingTimeInterval(3600))

    #expect(!sesion.isActive)
    #expect(sesion.endDate == inicio.addingTimeInterval(3600))
    #expect(sesion.duration(at: inicio.addingTimeInterval(99_999)) == 3600, "Ya no depende de la hora actual")
  }

  @Test("Una sesion de segundos se cuenta entera, sin redondear a cero")
  func muyCorta() throws {
    let sesion = PlaySession(startDate: inicio)

    try sesion.end(at: inicio.addingTimeInterval(5))

    #expect(sesion.duration == 5)
  }

  @Test("Terminar antes de empezar se rechaza y la sesion sigue activa")
  func finAntesDelInicio() {
    let sesion = PlaySession(startDate: inicio)

    #expect(throws: PlaySessionError.finAntesDelInicio) {
      try sesion.end(at: inicio.addingTimeInterval(-1))
    }
    #expect(sesion.isActive)
    #expect(sesion.endDate == nil)
  }

  @Test("Terminar en el mismo instante en que empezo vale: dura cero")
  func duracionCero() throws {
    let sesion = PlaySession(startDate: inicio)

    try sesion.end(at: inicio)

    #expect(!sesion.isActive)
    #expect(sesion.duration == 0)
  }

  @Test("Terminar dos veces se rechaza y no mueve la primera fecha")
  func dosVeces() throws {
    let sesion = PlaySession(startDate: inicio)
    try sesion.end(at: inicio.addingTimeInterval(60))

    #expect(throws: PlaySessionError.yaTerminada) {
      try sesion.end(at: inicio.addingTimeInterval(600))
    }
    #expect(sesion.endDate == inicio.addingTimeInterval(60))
  }

  @Test("Si el reloj se atrasa con la sesion activa, cuenta cero y no negativo")
  func relojAtrasado() {
    let sesion = PlaySession(startDate: inicio)

    #expect(sesion.duration(at: inicio.addingTimeInterval(-100)) == 0)
  }
}

@MainActor
@Suite("Sesion de juego: reglas de toda la app")
struct PlaySessionTrackerTests {

  private func hacerContexto() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let contenedor = try ModelContainer(
      for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self, PlaySession.self,
      configurations: config
    )
    return ModelContext(contenedor)
  }

  private func juego(_ nombre: String, en context: ModelContext) -> Game {
    let juego = Game(name: nombre)
    context.insert(juego)
    return juego
  }

  private func sesiones(en context: ModelContext) throws -> [PlaySession] {
    try context.fetch(FetchDescriptor<PlaySession>())
  }

  @Test("Empezar crea una sesion activa del juego")
  func empieza() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)

    let sesion = try PlaySessionTracker.start(hades, at: inicio, in: context)

    #expect(sesion.isActive)
    #expect(sesion.game === hades)
    #expect(hades.playSessions.count == 1)
    #expect(try PlaySessionTracker.activeSession(in: context) === sesion)
  }

  @Test("No se pueden tener dos sesiones activas a la vez, aunque sean de juegos distintos")
  func dosALaVez() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)
    let celeste = juego("Celeste", en: context)
    let primera = try PlaySessionTracker.start(hades, at: inicio, in: context)

    #expect(throws: PlaySessionError.yaHayUnaActiva(juego: "Hades")) {
      try PlaySessionTracker.start(celeste, at: inicio.addingTimeInterval(10), in: context)
    }

    #expect(try sesiones(en: context).count == 1, "La segunda no se crea")
    #expect(celeste.playSessions.isEmpty)
    #expect(try PlaySessionTracker.activeSession(in: context) === primera, "La primera sigue igual")
  }

  @Test("Tampoco dos del mismo juego")
  func dosDelMismo() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)
    try PlaySessionTracker.start(hades, at: inicio, in: context)

    #expect(throws: PlaySessionError.self) {
      try PlaySessionTracker.start(hades, at: inicio.addingTimeInterval(10), in: context)
    }
    #expect(hades.playSessions.count == 1)
  }

  @Test("Al terminar una, ya se puede empezar otra")
  func otraDespues() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)
    let celeste = juego("Celeste", en: context)
    let primera = try PlaySessionTracker.start(hades, at: inicio, in: context)
    try PlaySessionTracker.end(primera, at: inicio.addingTimeInterval(60), in: context)

    let segunda = try PlaySessionTracker.start(celeste, at: inicio.addingTimeInterval(120), in: context)

    #expect(try PlaySessionTracker.activeSession(in: context) === segunda)
  }

  @Test("Al cerrar una sesion, su duracion se suma a las horas del juego")
  func sumaLasHoras() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)
    hades.storeEntries = [StoreEntry(store: .steam, storeGameID: "1145360", playtimeHours: 10)]
    SteamGameMapper.recalculatePlaytime(for: hades)

    let sesion = try PlaySessionTracker.start(hades, at: inicio, in: context)
    try PlaySessionTracker.end(sesion, at: inicio.addingTimeInterval(90 * 60), in: context)

    #expect(hades.playtimeHours == 11.5, "10 h de Steam mas hora y media de la sesion")
    #expect(hades.sessionPlaytimeHours == 1.5)
  }

  @Test("Una sesion de segundos tambien suma, aunque sea poco")
  func muyCortaSuma() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)

    let sesion = try PlaySessionTracker.start(hades, at: inicio, in: context)
    try PlaySessionTracker.end(sesion, at: inicio.addingTimeInterval(5), in: context)

    #expect(hades.playtimeHours == 5.0 / 3600)
    #expect(!hades.isUnplayed, "Cinco segundos ya son haberlo abierto")
  }

  @Test("Mientras la sesion sigue activa, las horas del juego no cambian")
  func activaNoSuma() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)

    try PlaySessionTracker.start(hades, at: Date.now.addingTimeInterval(-3600), in: context)

    #expect(hades.playtimeHours == 0)
    #expect(hades.sessionPlaytimeHours == 0)
  }

  @Test("Una fecha de fin invalida no cierra la sesion ni toca las horas")
  func finInvalida() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)
    let sesion = try PlaySessionTracker.start(hades, at: inicio, in: context)

    #expect(throws: PlaySessionError.finAntesDelInicio) {
      try PlaySessionTracker.end(sesion, at: inicio.addingTimeInterval(-60), in: context)
    }

    #expect(sesion.isActive)
    #expect(hades.playtimeHours == 0)
    #expect(try PlaySessionTracker.activeSession(in: context) === sesion)
  }

  @Test("Las horas de las sesiones sobreviven a volver a sincronizar la tienda")
  func sobreviveALaSincronizacion() throws {
    let context = try hacerContexto()
    let json = #"{"appid": 1145360, "name": "Hades", "playtime_forever": 600}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)
    let hades = try #require(try context.fetch(FetchDescriptor<Game>()).first)

    let sesion = try PlaySessionTracker.start(hades, at: inicio, in: context)
    try PlaySessionTracker.end(sesion, at: inicio.addingTimeInterval(3600), in: context)
    #expect(hades.playtimeHours == 11)

    // Cada sincronizacion rehace el total desde las tiendas. Si la sesion se
    // hubiera sumado una sola vez, aca se perderia.
    try SteamLibrarySyncer.sync([dto], into: context)

    #expect(hades.playtimeHours == 11, "10 h de Steam mas la hora de la sesion")
  }

  @Test("Borrar el juego borra sus sesiones")
  func borradoEnCascada() throws {
    let context = try hacerContexto()
    let hades = juego("Hades", en: context)
    let sesion = try PlaySessionTracker.start(hades, at: inicio, in: context)
    try PlaySessionTracker.end(sesion, at: inicio.addingTimeInterval(60), in: context)

    context.delete(hades)
    try context.save()

    #expect(try sesiones(en: context).isEmpty)
  }

  @Test("El aviso de sesion activa nombra el juego")
  func avisoConNombre() {
    let aviso = PlaySessionError.yaHayUnaActiva(juego: "Hades").errorDescription ?? ""

    #expect(aviso.contains("Hades"))
  }
}
