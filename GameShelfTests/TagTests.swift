//
//  TagTests.swift
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

private func etiquetas(_ context: ModelContext) throws -> [GameTag] {
  try context.fetch(FetchDescriptor<GameTag>())
}

@Suite("Etiqueta: normalizacion del nombre")
struct TagNormalizationTests {

  @Test("Los espacios sobrantes se recortan")
  func recortaEspacios() {
    #expect(GameTag.clean("  coop  ") == "coop")
  }

  @Test("Los espacios internos de mas se colapsan")
  func colapsaEspacios() {
    #expect(GameTag.clean("para  el   Deck") == "para el Deck")
  }

  @Test("Para comparar se ignoran mayusculas y tildes")
  func comparacionFlexible() {
    #expect(GameTag.areEquivalent("RPG", "rpg"))
    #expect(GameTag.areEquivalent("Accion", "acción"))
    #expect(GameTag.areEquivalent(" Coop ", "coop"))
    #expect(GameTag.areEquivalent("coop", "co-op") == false)
  }

  @Test("El nombre se guarda como lo escribio el usuario")
  func conservaLaEscritura() {
    // Se compara sin distinguir, pero se muestra tal cual
    #expect(GameTag(name: "RPG").name == "RPG")
    #expect(GameTag(name: "  Metroidvania  ").name == "Metroidvania")
  }
}

@Suite("Etiqueta: crear y asignar")
@MainActor
struct TagCreationTests {

  @Test("Poner una etiqueta la crea y la asigna")
  func crearYAsignar() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Hollow Knight", in: context)

    let etiqueta = try viewModel.addTag(named: "metroidvania", to: juego, in: context)

    #expect(etiqueta.name == "metroidvania")
    #expect(juego.tags.count == 1)
    #expect(try etiquetas(context).count == 1)
  }

  @Test("La misma etiqueta escrita distinto NO crea una segunda")
  func noDuplicaPorMayusculas() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let uno = insertarJuego("Uno", in: context)
    let dos = insertarJuego("Dos", in: context)

    try viewModel.addTag(named: "RPG", to: uno, in: context)
    try viewModel.addTag(named: "rpg", to: dos, in: context)

    #expect(try etiquetas(context).count == 1, "RPG y rpg son la misma etiqueta")
    #expect(try etiquetas(context).first?.gameCount == 2)
  }

  @Test("Las tildes tampoco crean etiquetas distintas")
  func noDuplicaPorTildes() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let uno = insertarJuego("Uno", in: context)
    let dos = insertarJuego("Dos", in: context)

    try viewModel.addTag(named: "accion", to: uno, in: context)
    try viewModel.addTag(named: "acción", to: dos, in: context)

    #expect(try etiquetas(context).count == 1)
  }

  @Test("Ponerle dos veces la misma etiqueta al mismo juego no la repite")
  func noRepiteEnElMismoJuego() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Hollow Knight", in: context)

    try viewModel.addTag(named: "indie", to: juego, in: context)
    try viewModel.addTag(named: "indie", to: juego, in: context)
    try viewModel.addTag(named: "INDIE", to: juego, in: context)

    #expect(juego.tags.count == 1)
  }

  @Test("Un nombre vacio se rechaza")
  func nombreVacio() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Uno", in: context)

    #expect(throws: TagsViewModel.ValidationError.emptyName) {
      try viewModel.addTag(named: "   ", to: juego, in: context)
    }
    #expect(try etiquetas(context).isEmpty)
  }

  @Test("Un nombre muy largo se rechaza")
  func nombreMuyLargo() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Uno", in: context)
    let largo = String(repeating: "a", count: GameTag.maxNameLength + 1)

    #expect(throws: TagsViewModel.ValidationError.self) {
      try viewModel.addTag(named: largo, to: juego, in: context)
    }
  }

  @Test("Un juego puede tener varias etiquetas")
  func variasEtiquetas() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Hollow Knight", in: context)

    for nombre in ["metroidvania", "dificil", "indie"] {
      try viewModel.addTag(named: nombre, to: juego, in: context)
    }

    #expect(juego.tags.count == 3)
  }

  @Test("La relacion se ve desde los dos lados")
  func relacionEnAmbosSentidos() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Celeste", in: context)

    let etiqueta = try viewModel.addTag(named: "plataformas", to: juego, in: context)

    #expect(etiqueta.games.count == 1)
    #expect(etiqueta.games.first?.id == juego.id)
    #expect(juego.tags.first?.id == etiqueta.id)
  }
}

@Suite("Etiqueta: quitar y borrar")
@MainActor
struct TagRemovalTests {

  @Test("Quitar una etiqueta que usa otro juego no la borra")
  func quitarConservaSiLaUsanOtros() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let uno = insertarJuego("Uno", in: context)
    let dos = insertarJuego("Dos", in: context)
    let etiqueta = try viewModel.addTag(named: "coop", to: uno, in: context)
    try viewModel.addTag(named: "coop", to: dos, in: context)

    try viewModel.removeTag(etiqueta, from: uno, in: context)

    #expect(uno.tags.isEmpty)
    #expect(dos.tags.count == 1)
    #expect(try etiquetas(context).count == 1, "La sigue usando el otro juego")
  }

  @Test("Quitar la ultima referencia borra la etiqueta")
  func quitarBorraLaHuerfana() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Uno", in: context)
    let etiqueta = try viewModel.addTag(named: "solo-aqui", to: juego, in: context)

    try viewModel.removeTag(etiqueta, from: juego, in: context)

    #expect(
      try etiquetas(context).isEmpty,
      "Una etiqueta sin juegos solo estorbaria en el autocompletado"
    )
  }

  @Test("Borrar una etiqueta la quita de TODOS los juegos")
  func borrarLaQuitaDeTodos() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juegos = (1...3).map { insertarJuego("Juego \($0)", in: context) }
    let etiqueta = try viewModel.addTag(named: "coop", to: juegos[0], in: context)
    try viewModel.addTag(named: "coop", to: juegos[1], in: context)
    try viewModel.addTag(named: "coop", to: juegos[2], in: context)

    try viewModel.delete(etiqueta, in: context)

    #expect(try etiquetas(context).isEmpty)
    #expect(juegos.allSatisfy { $0.tags.isEmpty })
  }

  @Test("Borrar una etiqueta NO borra los juegos")
  func borrarNoborraJuegos() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Importante", in: context)
    let etiqueta = try viewModel.addTag(named: "coop", to: juego, in: context)

    try viewModel.delete(etiqueta, in: context)

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }

  @Test("Borrar un juego no rompe sus etiquetas")
  func borrarJuegoNoRompeEtiquetas() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let uno = insertarJuego("Uno", in: context)
    let dos = insertarJuego("Dos", in: context)
    try viewModel.addTag(named: "coop", to: uno, in: context)
    try viewModel.addTag(named: "coop", to: dos, in: context)

    context.delete(uno)
    try context.save()

    let etiqueta = try #require(try etiquetas(context).first)
    #expect(etiqueta.gameCount == 1)
  }

  @Test("La limpieza borra solo las etiquetas sin juegos")
  func limpiezaDeHuerfanas() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let juego = insertarJuego("Uno", in: context)
    try viewModel.addTag(named: "usada", to: juego, in: context)
    context.insert(GameTag(name: "huerfana-1"))
    context.insert(GameTag(name: "huerfana-2"))
    try context.save()

    let borradas = try viewModel.deleteOrphans(in: context)

    #expect(borradas == 2)
    #expect(try etiquetas(context).map(\.name) == ["usada"])
  }
}

@Suite("Etiqueta: autocompletado")
struct TagSuggestionTests {

  private func hacerEtiquetas(_ pares: [(String, Int)]) -> [GameTag] {
    pares.map { nombre, usos in
      let etiqueta = GameTag(name: nombre)
      etiqueta.games = (0..<usos).map { Game(name: "J\($0)") }
      return etiqueta
    }
  }

  @Test("Sin texto sugiere las mas usadas primero")
  func sinTextoOrdenaPorUso() {
    let todas = hacerEtiquetas([("poco", 1), ("mucho", 10), ("medio", 5)])

    let sugerencias = TagsViewModel.suggestions(for: "", from: todas, excluding: [])

    #expect(sugerencias.map(\.name) == ["mucho", "medio", "poco"])
  }

  @Test("Las que empiezan por lo escrito van antes que las que solo lo contienen")
  func prefijoAntesQueContenido() {
    let todas = hacerEtiquetas([("multijugador", 1), ("coop", 1), ("coop-local", 1)])

    let sugerencias = TagsViewModel.suggestions(for: "coop", from: todas, excluding: [])

    #expect(sugerencias.first?.name == "coop")
    #expect(sugerencias.map(\.name).contains("coop-local"))
  }

  @Test("El autocompletado ignora mayusculas y tildes")
  func busquedaFlexible() {
    let todas = hacerEtiquetas([("Acción", 1)])

    #expect(TagsViewModel.suggestions(for: "accion", from: todas, excluding: []).count == 1)
    #expect(TagsViewModel.suggestions(for: "ACCI", from: todas, excluding: []).count == 1)
  }

  @Test("No se sugieren las que el juego ya tiene")
  func excluyeLasPuestas() {
    let todas = hacerEtiquetas([("coop", 1), ("indie", 1)])

    let sugerencias = TagsViewModel.suggestions(
      for: "", from: todas, excluding: [todas[0]]
    )

    #expect(sugerencias.map(\.name) == ["indie"])
  }

  @Test("Se respeta el limite de sugerencias")
  func respetaElLimite() {
    let todas = hacerEtiquetas((1...20).map { ("etiqueta\($0)", $0) })

    #expect(TagsViewModel.suggestions(for: "", from: todas, excluding: [], limit: 5).count == 5)
  }

  @Test("Sin coincidencias no sugiere nada")
  func sinCoincidencias() {
    let todas = hacerEtiquetas([("coop", 1)])

    #expect(TagsViewModel.suggestions(for: "zzz", from: todas, excluding: []).isEmpty)
  }

  @Test("Solo se ofrece crear cuando la etiqueta no existe")
  func ofreceCrearSoloSiEsNueva() {
    let todas = hacerEtiquetas([("coop", 1)])

    #expect(TagsViewModel.wouldCreateNew("roguelike", among: todas))
    #expect(TagsViewModel.wouldCreateNew("coop", among: todas) == false)
    #expect(TagsViewModel.wouldCreateNew("COOP", among: todas) == false, "Es la misma")
    #expect(TagsViewModel.wouldCreateNew("   ", among: todas) == false, "Vacia no cuenta")
  }
}

@Suite("Etiquetas y sincronizacion")
@MainActor
struct TagSyncTests {

  @Test("Re-sincronizar con Steam no borra las etiquetas")
  func sincronizarConservaEtiquetas() throws {
    let context = try hacerContexto()
    let viewModel = TagsViewModel()
    let dtos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(dtos, into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    try viewModel.addTag(named: "pendiente de DLC", to: juego, in: context)
    let identificador = juego.id

    try SteamLibrarySyncer.sync(dtos, into: context)

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == identificador }
    )
    #expect(despues.tags.count == 1)
    #expect(despues.tags.first?.name == "pendiente de DLC")
  }
}
