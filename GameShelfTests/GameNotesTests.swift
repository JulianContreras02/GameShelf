//
//  GameNotesTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

private func hacerContexto() throws -> ModelContext {
  let schema = Schema([Game.self, StoreEntry.self, GameCollection.self, GameTag.self])
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}

@discardableResult
private func insertarJuego(_ nombre: String, in context: ModelContext) -> Game {
  let juego = Game(name: nombre)
  context.insert(juego)
  return juego
}

@Suite("Notas: guardar")
@MainActor
struct SaveNotesTests {

  @Test("Un juego nuevo no tiene notas")
  func sinNotasAlPrincipio() {
    #expect(Game(name: "Nuevo").notes.isEmpty)
  }

  @Test("Guardar una nota la deja escrita")
  func guardar() throws {
    let context = try hacerContexto()
    let viewModel = GameNotesViewModel()
    let juego = insertarJuego("Elden Ring", in: context)

    let guardo = try viewModel.save("Jefe pendiente: Malenia", for: juego, in: context)

    #expect(guardo)
    #expect(juego.notes == "Jefe pendiente: Malenia")

    let leido = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(leido.notes == "Jefe pendiente: Malenia")
  }

  @Test("Guardar lo mismo no cuenta como cambio")
  func mismoTextoNoEsCambio() throws {
    let context = try hacerContexto()
    let viewModel = GameNotesViewModel()
    let juego = insertarJuego("Uno", in: context)
    try viewModel.save("Una nota", for: juego, in: context)

    let guardo = try viewModel.save("Una nota", for: juego, in: context)

    #expect(guardo == false, "Evita escribir en disco y avisar a las vistas sin motivo")
  }

  @Test("Los espacios de los bordes se recortan")
  func recortaBordes() throws {
    let context = try hacerContexto()
    let juego = insertarJuego("Uno", in: context)

    try GameNotesViewModel().save("   Con espacios   ", for: juego, in: context)

    #expect(juego.notes == "Con espacios")
  }

  @Test("Una nota de solo espacios queda vacia")
  func soloEspaciosEsVacia() throws {
    let context = try hacerContexto()
    let juego = insertarJuego("Uno", in: context)

    try GameNotesViewModel().save("      \n\n  ", for: juego, in: context)

    #expect(
      juego.notes.isEmpty,
      "Si no, el juego pareceria tener algo escrito cuando no hay nada"
    )
  }

  @Test("Los saltos de linea de en medio se conservan")
  func conservaSaltosInternos() throws {
    let context = try hacerContexto()
    let juego = insertarJuego("Uno", in: context)

    try GameNotesViewModel().save("Primera linea\nSegunda linea", for: juego, in: context)

    #expect(juego.notes == "Primera linea\nSegunda linea")
  }

  @Test("Se puede reemplazar una nota por otra")
  func reemplazar() throws {
    let context = try hacerContexto()
    let viewModel = GameNotesViewModel()
    let juego = insertarJuego("Uno", in: context)

    try viewModel.save("Primera version", for: juego, in: context)
    try viewModel.save("Segunda version", for: juego, in: context)

    #expect(juego.notes == "Segunda version")
  }

  @Test("Borrar deja las notas vacias sin tocar el juego")
  func borrar() throws {
    let context = try hacerContexto()
    let viewModel = GameNotesViewModel()
    let juego = insertarJuego("Uno", in: context)
    try viewModel.save("Algo escrito", for: juego, in: context)

    try viewModel.clear(for: juego, in: context)

    #expect(juego.notes.isEmpty)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }

  @Test("Guardar notas no toca las horas, el estado ni las colecciones")
  func noAfectaOtrosDatos() throws {
    let context = try hacerContexto()
    let juego = Game(name: "Elden Ring", playtimeHours: 55)
    juego.status = .playing
    context.insert(juego)
    let coleccion = GameCollection(name: "Favoritos")
    context.insert(coleccion)
    coleccion.add(juego)
    try context.save()

    try GameNotesViewModel().save("Una nota", for: juego, in: context)

    #expect(juego.playtimeHours == 55)
    #expect(juego.status == .playing)
    #expect(juego.collections.count == 1)
  }
}

@Suite("Notas: limite de longitud")
struct NotesLimitTests {

  @Test("Un texto normal no llega al limite")
  func textoNormal() {
    #expect(GameNotesViewModel.exceedsLimit("Una nota corta") == false)
  }

  @Test("Un texto muy largo se recorta al guardar")
  func recortaElExceso() {
    let largo = String(repeating: "a", count: GameNotesViewModel.maxLength + 500)

    #expect(GameNotesViewModel.exceedsLimit(largo))
    #expect(GameNotesViewModel.clean(largo).count == GameNotesViewModel.maxLength)
  }

  @Test("Justo en el limite no se recorta")
  func justoEnElLimite() {
    let exacto = String(repeating: "a", count: GameNotesViewModel.maxLength)

    #expect(GameNotesViewModel.exceedsLimit(exacto) == false)
    #expect(GameNotesViewModel.clean(exacto).count == GameNotesViewModel.maxLength)
  }

  @Test("El contador solo aparece cerca del limite")
  func contadorSoloCercaDelLimite() {
    #expect(GameNotesViewModel.shouldShowCounter("corta") == false)

    let cerca = String(repeating: "a", count: GameNotesViewModel.counterThreshold)
    #expect(GameNotesViewModel.shouldShowCounter(cerca))
  }

  @Test("Un texto larguisimo se guarda recortado, sin fallar")
  @MainActor
  func guardaRecortado() throws {
    let context = try hacerContexto()
    let juego = insertarJuego("Uno", in: context)
    let enorme = String(repeating: "x", count: 20_000)

    try GameNotesViewModel().save(enorme, for: juego, in: context)

    #expect(juego.notes.count == GameNotesViewModel.maxLength)
  }
}

@Suite("Notas: sobreviven a todo")
@MainActor
struct NotesSurvivalTests {

  private func dtos() throws -> [SteamGameDTO] {
    try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games
  }

  @Test("Re-sincronizar con Steam no borra las notas")
  func sobrevivenALaSincronizacion() throws {
    let context = try hacerContexto()
    let viewModel = GameNotesViewModel()
    try SteamLibrarySyncer.sync(try dtos(), into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    try viewModel.save("No perder esto", for: juego, in: context)
    let identificador = juego.id

    try SteamLibrarySyncer.sync(try dtos(), into: context)

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == identificador }
    )
    #expect(despues.notes == "No perder esto")
  }

  @Test("Veinte sincronizaciones seguidas tampoco las borran")
  func sobrevivenAMuchasSincronizaciones() throws {
    let context = try hacerContexto()
    try SteamLibrarySyncer.sync(try dtos(), into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    try GameNotesViewModel().save("Sigo aqui", for: juego, in: context)
    let identificador = juego.id

    for _ in 1...20 {
      try SteamLibrarySyncer.sync(try dtos(), into: context)
    }

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == identificador }
    )
    #expect(despues.notes == "Sigo aqui")
  }

  @Test("Las notas sobreviven a cambiar el estado y las colecciones")
  func sobrevivenAOtrasEdiciones() throws {
    let context = try hacerContexto()
    let juego = insertarJuego("Uno", in: context)
    try GameNotesViewModel().save("Mi nota", for: juego, in: context)

    try GameStatusViewModel().setStatus(.finished, for: juego, in: context)
    let coleccion = try CollectionsViewModel().create(name: "Favoritos", in: context)
    try CollectionsViewModel().add([juego], to: coleccion, context: context)
    try TagsViewModel().addTag(named: "coop", to: juego, in: context)

    #expect(juego.notes == "Mi nota")
  }

  @Test("Un fallo de red no borra las notas")
  func sobrevivenAUnFallo() async throws {
    // La prueba es async y usa await directo. Una version anterior bloqueaba
    // con DispatchSemaphore y se colgaba: el semaforo retiene el hilo principal
    // que el Task necesita para avanzar.
    let context = try hacerContexto()
    let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)") ?? .standard

    let exitoso = LibraryViewModel(
      service: StubSteamService(.success(try dtos())),
      defaults: defaults
    )
    await exitoso.sync(into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    try GameNotesViewModel().save("Sobrevive", for: juego, in: context)
    let identificador = juego.id

    let fallido = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.noConnection)),
      defaults: defaults
    )
    await fallido.sync(into: context)

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == identificador }
    )
    #expect(despues.notes == "Sobrevive")
  }
}
