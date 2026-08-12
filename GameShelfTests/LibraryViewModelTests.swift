//
//  LibraryViewModelTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

private func hacerContexto() throws -> ModelContext {
  let schema = Schema([Game.self, StoreEntry.self])
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}

private func juegosDeEjemplo() throws -> [SteamGameDTO] {
  try Fixture
    .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
    .response.games
}

/// UserDefaults aislado por instancia: si las pruebas comparten los del
/// sistema, la fecha que escribe una hace fallar el estado inicial de otra.
@MainActor
private func hacerViewModel(_ behavior: StubSteamService.Behavior) -> LibraryViewModel {
  LibraryViewModel(
    service: StubSteamService(behavior),
    defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)") ?? .standard
  )
}

@Suite("LibraryViewModel - sincronizacion")
@MainActor
struct LibraryViewModelTests {

  @Test("Arranca sin hacer nada")
  func estadoInicial() {
    let viewModel = hacerViewModel(.success([]))

    #expect(viewModel.state == .idle)
    #expect(viewModel.lastSyncedAt == nil)
  }

  @Test("Una sincronizacion correcta guarda los juegos y reporta cuantos")
  func sincronizacionCorrecta() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.success(try juegosDeEjemplo()))

    await viewModel.sync(into: context)

    #expect(viewModel.state == .succeeded(created: 5, updated: 0))
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 5)
    #expect(viewModel.lastSyncedAt != nil)
  }

  @Test("Sincronizar dos veces actualiza en vez de duplicar")
  func segundaSincronizacion() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.success(try juegosDeEjemplo()))

    await viewModel.sync(into: context)
    await viewModel.sync(into: context)

    #expect(viewModel.state == .succeeded(created: 0, updated: 5))
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 5)
  }

  @Test("Sin conexion muestra un mensaje con su sugerencia, no un crash")
  func errorDeRed() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.failure(NetworkError.noConnection))

    await viewModel.sync(into: context)

    guard case .failed(let mensaje, let sugerencia) = viewModel.state else {
      Issue.record("Se esperaba estado failed, llego \(viewModel.state)")
      return
    }
    #expect(mensaje.contains("conexion"))
    #expect(sugerencia?.isEmpty == false)
    #expect(viewModel.lastSyncedAt == nil, "Un fallo no cuenta como sincronizacion")
  }

  @Test("Una API key rechazada sugiere revisar la clave")
  func errorDeCredenciales() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.failure(NetworkError.httpError(statusCode: 401)))

    await viewModel.sync(into: context)

    guard case .failed(_, let sugerencia) = viewModel.state else {
      Issue.record("Se esperaba estado failed")
      return
    }
    #expect(sugerencia?.contains("API key") == true)
  }

  @Test("Si faltan las claves, lo dice en vez de fallar en la red")
  func faltanCredenciales() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.failure(AppSecrets.MissingSecretError(key: .steamAPIKey)))

    await viewModel.sync(into: context)

    guard case .failed(let mensaje, let sugerencia) = viewModel.state else {
      Issue.record("Se esperaba estado failed")
      return
    }
    #expect(mensaje.contains("STEAM_API_KEY"))
    #expect(sugerencia?.contains("Secrets.xcconfig") == true)
  }

  @Test("Un fallo no borra los juegos que ya estaban guardados")
  func falloConservaLoGuardado() async throws {
    let context = try hacerContexto()

    let exitoso = hacerViewModel(.success(try juegosDeEjemplo()))
    await exitoso.sync(into: context)

    let fallido = hacerViewModel(.failure(NetworkError.noConnection))
    await fallido.sync(into: context)

    #expect(
      try context.fetch(FetchDescriptor<Game>()).count == 5,
      "Un error de red no puede vaciar la biblioteca"
    )
  }

  @Test("Una biblioteca vacia no es un error")
  func bibliotecaVacia() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.success([]))

    await viewModel.sync(into: context)

    #expect(viewModel.state == .succeeded(created: 0, updated: 0))
  }

  @Test("Las notas del usuario sobreviven a una sincronizacion desde la vista")
  func notasSobreviven() async throws {
    let context = try hacerContexto()
    let viewModel = hacerViewModel(.success(try juegosDeEjemplo()))

    await viewModel.sync(into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    juego.notes = "Mi nota"
    juego.status = .playing
    try context.save()

    await viewModel.sync(into: context)

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == juego.id }
    )
    #expect(despues.notes == "Mi nota")
    #expect(despues.status == .playing)
  }
}

@Suite("Formato de horas jugadas")
struct PlaytimeFormatterTests {

  @Test("Un juego sin tocar no dice 0 h")
  func sinJugar() {
    #expect(PlaytimeFormatter.short(hours: 0, bundle: IdiomaDePrueba.espanol) == "Sin jugar")
  }

  @Test("Menos de una hora se muestra en minutos")
  func enMinutos() {
    #expect(PlaytimeFormatter.short(hours: 0.75, bundle: IdiomaDePrueba.espanol) == "45 min")
    #expect(PlaytimeFormatter.short(hours: 0.5, bundle: IdiomaDePrueba.espanol) == "30 min")
  }

  @Test("Pocas horas conservan un decimal")
  func conDecimal() {
    let texto = PlaytimeFormatter.short(hours: 1.5, locale: Locale(identifier: "en_US"))
    #expect(texto == "1.5 h")
  }

  @Test("Muchas horas se redondean y llevan separador de miles")
  func muchasHoras() {
    let texto = PlaytimeFormatter.short(hours: 1404.5, locale: Locale(identifier: "en_US"))
    #expect(texto == "1,405 h", "1404.5 h sin separador se lee mal")
  }

  @Test("VoiceOver lee las horas en palabras, no el numero formateado")
  func textoAccesible() {
    #expect(PlaytimeFormatter.accessible(hours: 0, bundle: IdiomaDePrueba.espanol) == "Sin jugar")
    // La concordancia del singular se prueba en LocalizationPluralTests, que
    // fija el idioma; aca solo interesa que el numero y la unidad sean los
    // correctos.
    #expect(PlaytimeFormatter.accessible(hours: 1, bundle: IdiomaDePrueba.espanol) == "1 hora jugada")
    #expect(PlaytimeFormatter.accessible(hours: 2, bundle: IdiomaDePrueba.espanol) == "2 horas jugadas")
    #expect(PlaytimeFormatter.accessible(hours: 0.5, bundle: IdiomaDePrueba.espanol) == "30 minutos jugados")
    // Lo que se leia mal de "1.404 h" era la abreviatura, no el numero: el
    // separador de miles VoiceOver lo dice bien ("mil cuatrocientos cinco").
    let mucho = PlaytimeFormatter.accessible(hours: 1404.5, bundle: IdiomaDePrueba.espanol)
    #expect(mucho.hasSuffix(" horas jugadas"))
    #expect(!mucho.hasSuffix(" h"))
  }
}
