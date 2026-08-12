//
//  WishlistViewModelTests.swift
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

/// `UserDefaults` aislado, para que una prueba no se lleve por delante la
/// fecha de sincronizacion de otra ni la del simulador.
@MainActor
private func defaultsDePrueba() -> UserDefaults {
  // `UserDefaults(suiteName:)` solo devuelve nil con nombres reservados, y este
  // no lo es; aun asi se cae de vuelta al estandar en vez de forzar.
  UserDefaults(suiteName: "wishlist.pruebas.\(UUID().uuidString)") ?? .standard
}

@MainActor
@Suite("Wishlist: sincronizacion")
struct WishlistSyncStateTests {

  @Test("Al terminar bien deja el resumen de lo que cambio")
  func exito() async throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(
      service: StubWishlistService(.success([.ejemplo(appID: 1), .ejemplo(appID: 2)])),
      defaults: defaultsDePrueba()
    )

    await viewModel.sync(into: context)

    #expect(viewModel.state == .succeeded(created: 2, updated: 0, removed: 0))
    #expect(viewModel.lastSyncedAt != nil)
    #expect(!viewModel.lastSyncReturnedNoGames)
  }

  @Test("Un fallo de red deja el mensaje y no borra lo guardado")
  func fallo() async throws {
    let context = try hacerContexto()
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1)], into: context)

    let viewModel = WishlistViewModel(
      service: StubWishlistService(.failure(NetworkError.noConnection)),
      defaults: defaultsDePrueba()
    )

    await viewModel.sync(into: context)

    guard case .failed(let mensaje, let sugerencia) = viewModel.state else {
      Issue.record("Se esperaba un fallo, y quedo en \(viewModel.state)")
      return
    }
    #expect(!mensaje.isEmpty)
    #expect(sugerencia?.isEmpty == false, "Un fallo de red si tiene que decir que hacer")

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1, "Un fallo no borra la lista")
  }

  @Test("Una respuesta vacia se marca, y no quita nada de lo guardado")
  func respuestaVacia() async throws {
    let context = try hacerContexto()
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1), .ejemplo(appID: 2)], into: context)

    let viewModel = WishlistViewModel(
      service: StubWishlistService(.success([])),
      defaults: defaultsDePrueba()
    )

    await viewModel.sync(into: context)

    #expect(viewModel.lastSyncReturnedNoGames)
    #expect(viewModel.state == .succeeded(created: 0, updated: 0, removed: 0))

    // Es el caso de la lista privada: Steam responde igual que si estuviera
    // vacia, asi que no se puede tomar por cierta y borrar.
    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.allSatisfy { $0.isWishlistedInStore })
  }

  @Test("Una segunda llamada mientras hay una en curso se ignora")
  func sinSolaparse() async throws {
    let context = try hacerContexto()
    let servicio = StubWishlistService(.success([.ejemplo(appID: 1)]), delay: .milliseconds(50))
    let viewModel = WishlistViewModel(service: servicio, defaults: defaultsDePrueba())

    async let primera: Void = viewModel.sync(into: context)
    async let segunda: Void = viewModel.sync(into: context)
    _ = await (primera, segunda)

    #expect(servicio.callCount == 1)
  }
}

@MainActor
@Suite("Wishlist: agregar a mano")
struct WishlistManualAddTests {

  @Test("Agrega el juego con estado de lista de deseos")
  func agrega() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())

    let juego = try viewModel.addManually(name: "Silksong", in: context)

    #expect(juego.status == .wishlist)
    #expect(juego.name == "Silksong")
    #expect(!juego.isWishlistedInStore, "No viene de Steam, asi que no esta en su lista")
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }

  @Test("Recorta los espacios de los lados")
  func recorta() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())

    let juego = try viewModel.addManually(name: "   Hades   ", in: context)

    #expect(juego.name == "Hades")
  }

  @Test("Un nombre vacio no crea nada")
  func nombreVacio() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())

    #expect(throws: WishlistViewModel.ValidationError.emptyName) {
      try viewModel.addManually(name: "   ", in: context)
    }
    #expect(try context.fetch(FetchDescriptor<Game>()).isEmpty)
  }

  @Test("No deja duplicar un juego que ya tienes")
  func duplicado() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, name: "Elden Ring")], into: context)

    // La comparacion ignora mayusculas y tildes, igual que la busqueda.
    #expect(throws: WishlistViewModel.ValidationError.duplicateName("Elden Ring")) {
      try viewModel.addManually(name: "elden ring", in: context)
    }
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }

  @Test("Un nombre parecido pero distinto si se puede agregar")
  func nombreParecido() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())
    try viewModel.addManually(name: "Hades", in: context)

    try viewModel.addManually(name: "Hades II", in: context)

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 2)
  }

  @Test("Un juego agregado a mano se puede borrar")
  func borraLoAgregadoAMano() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())
    let juego = try viewModel.addManually(name: "Silksong", in: context)

    #expect(WishlistViewModel.canDelete(juego))
    try viewModel.delete(juego, in: context)

    #expect(try context.fetch(FetchDescriptor<Game>()).isEmpty)
  }

  @Test("Un juego que viene de Steam no se borra desde la app")
  func noBorraLosDeSteam() throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(service: StubWishlistService(.success([])), defaults: defaultsDePrueba())
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, name: "Cuphead")], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)

    // Borrarlo no serviria: la siguiente sincronizacion lo traeria de vuelta.
    #expect(!WishlistViewModel.canDelete(juego))
    try viewModel.delete(juego, in: context)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
  }

  @Test("Lo agregado a mano sobrevive a una sincronizacion")
  func sobreviveALaSincronizacion() async throws {
    let context = try hacerContexto()
    let viewModel = WishlistViewModel(
      service: StubWishlistService(.success([.ejemplo(appID: 1, name: "Cuphead")])),
      defaults: defaultsDePrueba()
    )
    try viewModel.addManually(name: "Un juego que no esta en Steam", in: context)

    await viewModel.sync(into: context)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 2)

    let aMano = try #require(juegos.first { $0.name == "Un juego que no esta en Steam" })
    #expect(aMano.status == .wishlist, "No lo toca la sincronizacion: no tiene entrada de Steam")
  }
}
