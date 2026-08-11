//
//  LibraryStateMachineTests.swift
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

/// UserDefaults aislado por prueba, para no ensuciar los del sistema ni que una
/// prueba afecte a otra.
private func defaultsAislados() -> UserDefaults {
  let suite = "test.\(UUID().uuidString)"
  return UserDefaults(suiteName: suite) ?? .standard
}

@Suite("Maquina de estados de la biblioteca")
@MainActor
struct LibraryStateMachineTests {

  @Test("Arranca en idle, sin haber intentado nada")
  func estadoInicial() {
    let viewModel = LibraryViewModel(
      service: StubSteamService(.success([])),
      defaults: defaultsAislados()
    )

    #expect(viewModel.state == .idle)
    #expect(viewModel.state.hasAttempted == false)
    #expect(viewModel.lastSyncedAt == nil)
  }

  @Test("idle -> syncing -> succeeded")
  func caminoFeliz() async throws {
    let context = try hacerContexto()
    let viewModel = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaultsAislados()
    )

    await viewModel.sync(into: context)

    #expect(viewModel.state == .succeeded(created: 5, updated: 0))
    #expect(viewModel.state.hasAttempted)
    #expect(viewModel.lastSyncedAt != nil)
  }

  @Test("idle -> syncing -> failed")
  func caminoConFallo() async throws {
    let context = try hacerContexto()
    let viewModel = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.noConnection)),
      defaults: defaultsAislados()
    )

    await viewModel.sync(into: context)

    guard case .failed = viewModel.state else {
      Issue.record("Se esperaba failed, llego \(viewModel.state)")
      return
    }
    #expect(viewModel.state.hasAttempted)
    #expect(viewModel.lastSyncedAt == nil, "Un fallo no marca sincronizacion")
  }

  @Test("failed -> syncing -> succeeded: se puede recuperar de un fallo")
  func recuperacionDespuesDeFallo() async throws {
    let context = try hacerContexto()

    let fallido = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.noConnection)),
      defaults: defaultsAislados()
    )
    await fallido.sync(into: context)
    guard case .failed = fallido.state else {
      Issue.record("Se esperaba failed")
      return
    }

    // Reintento con un servicio que ya funciona
    let exitoso = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaultsAislados()
    )
    await exitoso.sync(into: context)

    #expect(exitoso.state == .succeeded(created: 5, updated: 0))
  }

  @Test("Una segunda llamada mientras hay una en curso se ignora")
  func noSincronizaDosVecesALaVez() async throws {
    let context = try hacerContexto()
    // El retardo es lo que hace significativa la prueba: sin el, el doble no
    // suspende, la primera llamada termina antes de que arranque la segunda y
    // nunca llegan a solaparse.
    let service = StubSteamService(.success(try juegosDeEjemplo()), delay: .milliseconds(200))
    let viewModel = LibraryViewModel(service: service, defaults: defaultsAislados())

    async let primera: Void = viewModel.sync(into: context)
    async let segunda: Void = viewModel.sync(into: context)
    _ = await (primera, segunda)

    #expect(
      service.callCount == 1,
      "La segunda llamada debe descartarse mientras la primera esta en curso"
    )
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 5)
  }
}

@Suite("Primera sincronizacion automatica")
@MainActor
struct FirstSyncTests {

  @Test("Si nunca se sincronizo, syncIfNeeded si sincroniza")
  func primeraVezSincroniza() async throws {
    let context = try hacerContexto()
    let service = StubSteamService(.success(try juegosDeEjemplo()))
    let viewModel = LibraryViewModel(service: service, defaults: defaultsAislados())

    await viewModel.syncIfNeeded(into: context)

    #expect(service.callCount == 1)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 5)
  }

  @Test("Si ya se sincronizo antes, no vuelve a hacerlo al abrir")
  func noRepiteEnCadaArranque() async throws {
    let context = try hacerContexto()
    let defaults = defaultsAislados()

    let primera = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaults
    )
    await primera.sync(into: context)

    // Simula abrir la app otra vez: mismo almacenamiento, ViewModel nuevo
    let service = StubSteamService(.success(try juegosDeEjemplo()))
    let segunda = LibraryViewModel(service: service, defaults: defaults)
    await segunda.syncIfNeeded(into: context)

    #expect(service.callCount == 0, "No debe sincronizar sola en cada arranque")
  }

  @Test("La fecha de la ultima sincronizacion sobrevive al cierre de la app")
  func fechaPersiste() async throws {
    let context = try hacerContexto()
    let defaults = defaultsAislados()

    let primera = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaults
    )
    await primera.sync(into: context)
    let fecha = primera.lastSyncedAt

    let segunda = LibraryViewModel(
      service: StubSteamService(.success([])),
      defaults: defaults
    )

    #expect(segunda.lastSyncedAt == fecha)
  }

  @Test("Sincronizar a mano si funciona aunque ya se haya sincronizado antes")
  func sincronizacionManualSiempreFunciona() async throws {
    let context = try hacerContexto()
    let defaults = defaultsAislados()

    let primera = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaults
    )
    await primera.sync(into: context)

    let service = StubSteamService(.success(try juegosDeEjemplo()))
    let segunda = LibraryViewModel(service: service, defaults: defaults)
    await segunda.sync(into: context)

    #expect(service.callCount == 1, "El boton de sincronizar no depende de la marca")
  }
}

@Suite("Biblioteca vacia frente a perfil privado")
@MainActor
struct EmptyLibraryTests {

  @Test("Si Steam devuelve cero juegos, queda registrado")
  func steamDevolvioNada() async throws {
    let context = try hacerContexto()
    let viewModel = LibraryViewModel(
      service: StubSteamService(.success([])),
      defaults: defaultsAislados()
    )

    await viewModel.sync(into: context)

    #expect(viewModel.state == .succeeded(created: 0, updated: 0))
    #expect(
      viewModel.lastSyncReturnedNoGames,
      "Hay que poder distinguirlo de 'todavia no sincronizaste'"
    )
  }

  @Test("Si Steam devuelve juegos, no se marca como vacia")
  func steamDevolvioJuegos() async throws {
    let context = try hacerContexto()
    let viewModel = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaultsAislados()
    )

    await viewModel.sync(into: context)

    #expect(viewModel.lastSyncReturnedNoGames == false)
  }

  @Test("Un fallo no marca la biblioteca como vacia")
  func falloNoMarcaVacia() async throws {
    let context = try hacerContexto()
    let viewModel = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.noConnection)),
      defaults: defaultsAislados()
    )

    await viewModel.sync(into: context)

    #expect(viewModel.lastSyncReturnedNoGames == false)
  }
}

@Suite("Los datos guardados sobreviven a un fallo de red")
@MainActor
struct OfflineResilienceTests {

  @Test("Un fallo despues de una sincronizacion buena no borra nada")
  func falloConservaLosJuegos() async throws {
    let context = try hacerContexto()
    let defaults = defaultsAislados()

    let exitoso = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaults
    )
    await exitoso.sync(into: context)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 5)

    let fallido = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.noConnection)),
      defaults: defaults
    )
    await fallido.sync(into: context)

    #expect(
      try context.fetch(FetchDescriptor<Game>()).count == 5,
      "Sin red, el usuario debe seguir viendo su biblioteca"
    )
  }

  @Test("Tras un fallo se conserva la fecha de la ultima sincronizacion buena")
  func conservaLaFechaAnterior() async throws {
    let context = try hacerContexto()
    let defaults = defaultsAislados()

    let exitoso = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaults
    )
    await exitoso.sync(into: context)
    let fechaBuena = try #require(exitoso.lastSyncedAt)

    let fallido = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.noConnection)),
      defaults: defaults
    )
    await fallido.sync(into: context)

    #expect(
      fallido.lastSyncedAt == fechaBuena,
      "Hay que poder decirle al usuario que tan viejos son los datos que ve"
    )
  }

  @Test("Las notas del usuario sobreviven a un fallo de red")
  func notasSobrevivenAlFallo() async throws {
    let context = try hacerContexto()
    let defaults = defaultsAislados()

    let exitoso = LibraryViewModel(
      service: StubSteamService(.success(try juegosDeEjemplo())),
      defaults: defaults
    )
    await exitoso.sync(into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    juego.notes = "No perder esto"
    try context.save()

    let fallido = LibraryViewModel(
      service: StubSteamService(.failure(NetworkError.httpError(statusCode: 500))),
      defaults: defaults
    )
    await fallido.sync(into: context)

    let despues = try #require(
      try context.fetch(FetchDescriptor<Game>()).first { $0.id == juego.id }
    )
    #expect(despues.notes == "No perder esto")
  }
}
