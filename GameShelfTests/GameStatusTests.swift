//
//  GameStatusTests.swift
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
private func insertar(_ nombres: [String], in context: ModelContext) -> [Game] {
  let juegos = nombres.map { Game(name: $0) }
  for juego in juegos { context.insert(juego) }
  return juegos
}

@Suite("Cambiar el estado de un juego")
@MainActor
struct SetStatusTests {

  @Test("Un juego nuevo arranca en pendiente")
  func estadoInicial() {
    #expect(Game(name: "Nuevo").status == .backlog)
  }

  @Test("Cambiar el estado lo guarda")
  func cambiarEstado() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juego = insertar(["Celeste"], in: context)[0]

    let cambio = try viewModel.setStatus(.playing, for: juego, in: context)

    #expect(cambio)
    #expect(juego.status == .playing)

    let leido = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(leido.status == .playing)
  }

  @Test("Poner el mismo estado que ya tenia no cuenta como cambio")
  func mismoEstadoNoEsCambio() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juego = insertar(["Celeste"], in: context)[0]
    try viewModel.setStatus(.playing, for: juego, in: context)

    let cambio = try viewModel.setStatus(.playing, for: juego, in: context)

    #expect(cambio == false, "Evita guardar y avisar a las vistas sin motivo")
    #expect(juego.status == .playing)
  }

  @Test("Se puede recorrer todos los estados")
  func todosLosEstados() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juego = insertar(["Celeste"], in: context)[0]

    for estado in PlayStatus.allCases {
      try viewModel.setStatus(estado, for: juego, in: context)
      #expect(juego.status == estado)
    }
  }

  @Test("Cambiar el estado de varios a la vez")
  func cambiarVarios() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juegos = insertar(["Uno", "Dos", "Tres"], in: context)

    let cambiados = try viewModel.setStatus(.finished, for: juegos, in: context)

    #expect(cambiados == 3)
    #expect(juegos.allSatisfy { $0.status == .finished })
  }

  @Test("En lote solo cuentan los que de verdad cambian")
  func loteCuentaSoloLosQueCambian() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juegos = insertar(["Uno", "Dos", "Tres"], in: context)
    try viewModel.setStatus(.finished, for: juegos[0], in: context)

    let cambiados = try viewModel.setStatus(.finished, for: juegos, in: context)

    #expect(cambiados == 2, "El primero ya estaba terminado")
  }

  @Test("Cambiar el estado no toca las horas ni las colecciones")
  func noAfectaOtrosDatos() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juego = Game(name: "Celeste", playtimeHours: 42)
    context.insert(juego)
    let coleccion = GameCollection(name: "Favoritos")
    context.insert(coleccion)
    coleccion.add(juego)
    try context.save()

    try viewModel.setStatus(.finished, for: juego, in: context)

    #expect(juego.playtimeHours == 42)
    #expect(juego.collections.count == 1)
  }
}

@Suite("Contar juegos por estado")
@MainActor
struct StatusCountTests {

  @Test("Sin juegos, todos los estados quedan en cero")
  func sinJuegos() {
    let conteos = GameStatusViewModel.counts(for: [])

    #expect(conteos.count == PlayStatus.allCases.count, "Deben salir todos los estados")
    #expect(conteos.values.allSatisfy { $0 == 0 })
  }

  @Test("Cuenta bien cada estado")
  func cuentaPorEstado() {
    let juegos = [
      juego("A", .playing),
      juego("B", .backlog),
      juego("C", .backlog),
      juego("D", .finished)
    ]

    let conteos = GameStatusViewModel.counts(for: juegos)

    #expect(conteos[.playing] == 1)
    #expect(conteos[.backlog] == 2)
    #expect(conteos[.finished] == 1)
    #expect(conteos[.abandoned] == 0)
    #expect(conteos[.wishlist] == 0)
  }

  @Test("Los estados vacios tambien aparecen, con cero")
  func estadosVaciosPresentes() {
    let conteos = GameStatusViewModel.counts(for: [juego("A", .playing)])

    // Sin esto la pantalla cambiaria de tamaño segun lo que haya
    for estado in PlayStatus.allCases {
      #expect(conteos[estado] != nil, "Falta \(estado)")
    }
  }

  @Test("La suma de los conteos es el total de juegos")
  func sumaEsElTotal() {
    let juegos = PlayStatus.allCases.enumerated().flatMap { indice, estado in
      (0...indice).map { juego("J\(indice)-\($0)", estado) }
    }

    let conteos = GameStatusViewModel.counts(for: juegos)

    #expect(conteos.values.reduce(0, +) == juegos.count)
  }

  @Test("Los conteos desde la base coinciden con los del calculo puro")
  func conteosDesdeLaBase() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let juegos = insertar(["A", "B", "C"], in: context)
    try viewModel.setStatus(.playing, for: juegos[0], in: context)
    try viewModel.setStatus(.finished, for: juegos[1], in: context)

    let conteos = try viewModel.counts(in: context)

    #expect(conteos[.playing] == 1)
    #expect(conteos[.finished] == 1)
    #expect(conteos[.backlog] == 1)
  }

  private func juego(_ nombre: String, _ estado: PlayStatus) -> Game {
    let juego = Game(name: nombre)
    juego.status = estado
    return juego
  }
}

@Suite("Filtrar juegos por estado")
struct StatusFilterTests {

  @Test("Devuelve solo los del estado pedido, ordenados por nombre")
  func filtraYOrdena() {
    let juegos = [
      hacerJuego("Zelda", .backlog),
      hacerJuego("Alan Wake", .backlog),
      hacerJuego("Celeste", .playing)
    ]

    let pendientes = GameStatusViewModel.games(juegos, with: .backlog)

    #expect(pendientes.map(\.name) == ["Alan Wake", "Zelda"])
  }

  @Test("Un estado sin juegos devuelve lista vacia, no nil")
  func estadoVacio() {
    let pendientes = GameStatusViewModel.games([hacerJuego("A", .playing)], with: .wishlist)

    #expect(pendientes.isEmpty)
  }

  private func hacerJuego(_ nombre: String, _ estado: PlayStatus) -> Game {
    let juego = Game(name: nombre)
    juego.status = estado
    return juego
  }
}

@Suite("El estado sobrevive a la sincronizacion")
@MainActor
struct StatusSurvivesSyncTests {

  @Test("Re-sincronizar con Steam no cambia el estado que puso el usuario")
  func sincronizarNoPisaElEstado() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let dtos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(dtos, into: context)

    // El usuario marca sus estados
    let todos = try context.fetch(FetchDescriptor<Game>()).sorted { $0.name < $1.name }
    try viewModel.setStatus(.finished, for: todos[0], in: context)
    try viewModel.setStatus(.playing, for: todos[1], in: context)
    let idTerminado = todos[0].id
    let idJugando = todos[1].id

    try SteamLibrarySyncer.sync(dtos, into: context)

    let despues = try context.fetch(FetchDescriptor<Game>())
    let terminado = try #require(despues.first { $0.id == idTerminado })
    let jugando = try #require(despues.first { $0.id == idJugando })

    #expect(terminado.status == .finished)
    #expect(jugando.status == .playing)
  }

  @Test("Diez sincronizaciones seguidas tampoco cambian el estado")
  func muchasSincronizaciones() throws {
    let context = try hacerContexto()
    let viewModel = GameStatusViewModel()
    let dtos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(dtos, into: context)
    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    try viewModel.setStatus(.abandoned, for: juego, in: context)
    let identificador = juego.id

    for _ in 1...10 {
      try SteamLibrarySyncer.sync(dtos, into: context)
    }

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == identificador }
    )
    #expect(despues.status == .abandoned)
  }
}

@Suite("Presentacion de los estados")
struct PlayStatusPresentationTests {

  @Test("Todos los estados tienen nombre, simbolo y explicacion")
  func todosTienenPresentacion() {
    for estado in PlayStatus.allCases {
      #expect(estado.displayName.isEmpty == false, "Falta nombre en \(estado)")
      #expect(estado.symbolName.isEmpty == false, "Falta simbolo en \(estado)")
      #expect(estado.explanation.isEmpty == false, "Falta explicacion en \(estado)")
    }
  }

  @Test("El orden de presentacion incluye todos los estados, sin repetir")
  func ordenCompleto() {
    #expect(PlayStatus.displayOrder.count == PlayStatus.allCases.count)
    #expect(Set(PlayStatus.displayOrder) == Set(PlayStatus.allCases))
  }

  @Test("Solo la lista de deseos cuenta como no poseido")
  func poseidos() {
    let noPoseidos = PlayStatus.allCases.filter { !$0.isOwned }

    #expect(noPoseidos == [.wishlist])
  }
}
