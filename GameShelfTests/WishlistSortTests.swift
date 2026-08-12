//
//  WishlistSortTests.swift
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

/// Precios de prueba con el descuento que se quiera.
private func precios(
  appID: Int,
  precio: Int,
  regular: Int,
  minimo: Int? = nil,
  moneda: String = "USD"
) -> GamePrices {
  GamePrices(
    itadID: "id-\(appID)",
    best: GameDeal(
      shopName: "Steam",
      price: Money(minorUnits: precio, currency: moneda),
      regular: Money(minorUnits: regular, currency: moneda),
      url: nil
    ),
    historicalLow: minimo.map { Money(minorUnits: $0, currency: moneda) }
  )
}

@MainActor
@Suite("Wishlist: orden por precio")
struct WishlistSortTests {

  /// Crea juegos de Steam con appids 1, 2, 3...
  private func juegos(_ nombres: [String], in context: ModelContext) throws -> [Game] {
    let lista = nombres.enumerated().map { indice, nombre -> SteamWishlistGame in
      .ejemplo(
        appID: indice + 1,
        name: nombre,
        addedAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + indice))
      )
    }
    try SteamWishlistSyncer.sync(lista, into: context)
    return try context.fetch(FetchDescriptor<Game>())
  }

  @Test("Por mayor descuento pone la rebaja mas grande primero")
  func porDescuento() throws {
    let context = try hacerContexto()
    let lista = try juegos(["Poco", "Mucho", "Nada"], in: context)

    let tabla = [
      1: precios(appID: 1, precio: 1800, regular: 2000),  // 10%
      2: precios(appID: 2, precio: 500, regular: 2000),   // 75%
      3: precios(appID: 3, precio: 2000, regular: 2000)   // 0%
    ]

    let ordenados = WishlistSortOrder.mayorDescuento.sort(lista, precios: tabla)

    #expect(ordenados.map(\.name) == ["Mucho", "Poco", "Nada"])
  }

  @Test("Por precio mas bajo ordena por lo que cuesta, no por el descuento")
  func porPrecio() throws {
    let context = try hacerContexto()
    let lista = try juegos(["Caro", "Barato"], in: context)

    // El caro tiene mejor descuento, pero sigue costando mas.
    let tabla = [
      1: precios(appID: 1, precio: 3000, regular: 9000),  // 67%
      2: precios(appID: 2, precio: 900, regular: 1000)    // 10%
    ]

    let ordenados = WishlistSortOrder.precioMasBajo.sort(lista, precios: tabla)

    #expect(ordenados.map(\.name) == ["Barato", "Caro"])
  }

  @Test("Los juegos sin precio van al final, ordenados por nombre")
  func sinPrecio() throws {
    let context = try hacerContexto()
    let lista = try juegos(["Zelda", "Con oferta", "Abzu"], in: context)

    // Solo el segundo tiene precio: los otros dos no los conoce ITAD, o no
    // han salido todavia.
    let tabla = [2: precios(appID: 2, precio: 500, regular: 2000)]

    let ordenados = WishlistSortOrder.mayorDescuento.sort(lista, precios: tabla)

    #expect(ordenados.first?.name == "Con oferta")
    #expect(ordenados.dropFirst().map(\.name) == ["Abzu", "Zelda"], "Los sin precio, alfabeticos")
  }

  @Test("Sin ningun precio cargado no se pierde ningun juego")
  func sinPreciosCargados() throws {
    let context = try hacerContexto()
    let lista = try juegos(["Uno", "Dos", "Tres"], in: context)

    for orden in WishlistSortOrder.allCases {
      let ordenados = orden.sort(lista, precios: [:])
      #expect(ordenados.count == 3, "El orden \(orden) perdio juegos")
      #expect(Set(ordenados.map(\.name)) == ["Uno", "Dos", "Tres"])
    }
  }

  @Test("El orden por fecha no necesita precios y los otros si")
  func necesitanPrecios() {
    #expect(!WishlistSortOrder.deseadoHacePoco.needsPrices)
    #expect(WishlistSortOrder.mayorDescuento.needsPrices)
    #expect(WishlistSortOrder.precioMasBajo.needsPrices)
  }

  @Test("Por deseado hace poco pone lo mas reciente primero")
  func porFecha() throws {
    let context = try hacerContexto()
    let lista = try juegos(["Viejo", "Nuevo"], in: context)

    let ordenados = WishlistSortOrder.deseadoHacePoco.sort(lista, precios: [:])

    #expect(ordenados.map(\.name) == ["Nuevo", "Viejo"])
  }

  @Test("Todos los ordenes tienen nombre y simbolo")
  func textos() {
    for orden in WishlistSortOrder.allCases {
      #expect(!orden.displayName.isEmpty)
      #expect(!orden.symbolName.isEmpty)
    }
  }
}

@MainActor
@Suite("Wishlist: preferencia de orden")
struct WishlistPreferencesTests {

  private func defaults() -> UserDefaults {
    UserDefaults(suiteName: "wishlist.orden.\(UUID().uuidString)") ?? .standard
  }

  @Test("El orden elegido se recuerda")
  func seRecuerda() {
    let almacen = defaults()

    let primera = WishlistPreferences(defaults: almacen)
    #expect(primera.sortOrder == .deseadoHacePoco)
    primera.sortOrder = .mayorDescuento

    let segunda = WishlistPreferences(defaults: almacen)
    #expect(segunda.sortOrder == .mayorDescuento)
  }

  @Test("Un valor guardado que ya no existe vuelve al de por defecto")
  func valorInvalido() {
    let almacen = defaults()
    almacen.set("unOrdenQueSeBorro", forKey: "wishlist.sortOrder")

    #expect(WishlistPreferences(defaults: almacen).sortOrder == .default)
  }
}
