//
//  GameFilterTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

// MARK: - Apoyo

@MainActor
private func juego(
  _ nombre: String,
  store tienda: Store? = .steam,
  status estado: PlayStatus = .backlog,
  horas: Double = 0,
  lastPlayed: Date? = nil,
  releaseDate: Date? = nil,
  addedAt: Date? = nil
) -> Game {
  let juego = Game(name: nombre, releaseDate: releaseDate, playtimeHours: horas)
  juego.status = estado
  if let tienda {
    juego.storeEntries = [
      StoreEntry(store: tienda, storeGameID: nombre, lastPlayedAt: lastPlayed)
    ]
  }
  if let addedAt { juego.addedAt = addedAt }
  return juego
}

private func nombres(_ juegos: [Game]) -> [String] {
  juegos.map(\.name)
}

// MARK: - Filtros de a uno

@Suite("Filtro: por tienda")
@MainActor
struct StoreFilterTests {

  @Test("Sin tiendas marcadas no filtra nada")
  func sinMarcar() {
    let biblioteca = [juego("A", store: .steam), juego("B", store: .psn)]

    #expect(GameFilter().apply(to: biblioteca).count == 2)
  }

  @Test("Filtra por una tienda")
  func unaTienda() {
    let biblioteca = [juego("A", store: .steam), juego("B", store: .psn)]
    var filtro = GameFilter()
    filtro.stores = [.steam]

    #expect(nombres(filtro.apply(to: biblioteca)) == ["A"])
  }

  @Test("Marcar dos tiendas muestra las dos, no la interseccion")
  func dosTiendasEsO() {
    let biblioteca = [
      juego("A", store: .steam),
      juego("B", store: .psn),
      juego("C", store: .epic)
    ]
    var filtro = GameFilter()
    filtro.stores = [.steam, .psn]

    #expect(
      filtro.apply(to: biblioteca).count == 2,
      "Dentro de una categoria las opciones se suman"
    )
  }

  @Test("Un juego en dos tiendas aparece filtrando por cualquiera de ellas")
  func juegoEnVariasTiendas() {
    let multi = juego("Multi", store: .steam)
    multi.storeEntries.append(StoreEntry(store: .psn, storeGameID: "psn"))
    var filtro = GameFilter()
    filtro.stores = [.psn]

    #expect(filtro.apply(to: [multi]).count == 1)
  }

  @Test("Un juego sin tiendas no pasa el filtro de tienda")
  func juegoSinTiendas() {
    var filtro = GameFilter()
    filtro.stores = [.steam]

    #expect(filtro.apply(to: [juego("Suelto", store: nil)]).isEmpty)
  }
}

@Suite("Filtro: por estado")
@MainActor
struct PlayStatusFilterTests {

  @Test("Filtra por un estado")
  func unEstado() {
    let biblioteca = [
      juego("A", status: .playing),
      juego("B", status: .backlog),
      juego("C", status: .finished)
    ]
    var filtro = GameFilter()
    filtro.statuses = [.playing]

    #expect(nombres(filtro.apply(to: biblioteca)) == ["A"])
  }

  @Test("Marcar dos estados muestra los dos")
  func dosEstados() {
    let biblioteca = [
      juego("A", status: .playing),
      juego("B", status: .backlog),
      juego("C", status: .finished)
    ]
    var filtro = GameFilter()
    filtro.statuses = [.playing, .finished]

    #expect(filtro.apply(to: biblioteca).count == 2)
  }
}

@Suite("Filtro: por coleccion y etiqueta")
@MainActor
struct CollectionTagFilterTests {

  @Test("Filtra por coleccion")
  func porColeccion() {
    let dentro = juego("Dentro")
    let fuera = juego("Fuera")
    let coleccion = GameCollection(name: "Favoritos")
    coleccion.add(dentro)

    var filtro = GameFilter()
    filtro.collectionIDs = [coleccion.id]

    #expect(nombres(filtro.apply(to: [dentro, fuera])) == ["Dentro"])
  }

  @Test("Filtra por etiqueta")
  func porEtiqueta() {
    let conEtiqueta = juego("Con")
    let sinEtiqueta = juego("Sin")
    let etiqueta = GameTag(name: "coop")
    conEtiqueta.tags = [etiqueta]

    var filtro = GameFilter()
    filtro.tagIDs = [etiqueta.id]

    #expect(nombres(filtro.apply(to: [conEtiqueta, sinEtiqueta])) == ["Con"])
  }

  @Test("Filtrar por una coleccion que no existe no devuelve nada")
  func coleccionInexistente() {
    var filtro = GameFilter()
    filtro.collectionIDs = [UUID()]

    #expect(filtro.apply(to: [juego("A")]).isEmpty)
  }
}

// MARK: - Combinaciones

@Suite("Filtro: combinar varios")
@MainActor
struct CombinedFilterTests {

  @Test("Entre categorias se aplica Y")
  func categoriasSeSuman() {
    let biblioteca = [
      juego("Steam jugando", store: .steam, status: .playing),
      juego("Steam pendiente", store: .steam, status: .backlog),
      juego("PSN jugando", store: .psn, status: .playing)
    ]
    var filtro = GameFilter()
    filtro.stores = [.steam]
    filtro.statuses = [.playing]

    #expect(
      nombres(filtro.apply(to: biblioteca)) == ["Steam jugando"],
      "Debe cumplir tienda Y estado, no cualquiera de los dos"
    )
  }

  @Test("Tres categorias a la vez")
  func tresCategorias() {
    let elegido = juego("Elegido", store: .steam, status: .playing)
    let coleccion = GameCollection(name: "Favoritos")
    coleccion.add(elegido)
    let otro = juego("Otro", store: .steam, status: .playing)

    var filtro = GameFilter()
    filtro.stores = [.steam]
    filtro.statuses = [.playing]
    filtro.collectionIDs = [coleccion.id]

    #expect(nombres(filtro.apply(to: [elegido, otro])) == ["Elegido"])
  }

  @Test("Una combinacion imposible devuelve lista vacia")
  func combinacionImposible() {
    let biblioteca = [juego("A", store: .steam, status: .playing)]
    var filtro = GameFilter()
    filtro.stores = [.psn]
    filtro.statuses = [.playing]

    #expect(filtro.apply(to: biblioteca).isEmpty)
  }

  @Test("El contador suma todos los criterios marcados")
  func contadorDeFiltros() {
    var filtro = GameFilter()
    #expect(filtro.isActive == false)
    #expect(filtro.activeCount == 0)

    filtro.stores = [.steam, .psn]
    filtro.statuses = [.playing]

    #expect(filtro.isActive)
    #expect(filtro.activeCount == 3)
  }

  @Test("Limpiar deja el filtro sin nada")
  func limpiar() {
    var filtro = GameFilter()
    filtro.stores = [.steam]
    filtro.statuses = [.playing]
    filtro.tagIDs = [UUID()]

    filtro.clear()

    #expect(filtro == GameFilter.none)
    #expect(filtro.isActive == false)
  }
}
