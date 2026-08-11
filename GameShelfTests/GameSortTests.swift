//
//  GameSortTests.swift
//  GameShelfTests
//
//  Separado de GameFilterTests para no pasar el limite de tamaño de archivo.
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

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

// MARK: - Ordenamiento

@Suite("Orden de la biblioteca")
@MainActor
struct SortOrderTests {

  @Test("Por nombre, de la A a la Z")
  func porNombre() {
    let biblioteca = [juego("Zelda"), juego("Alan Wake"), juego("Celeste")]

    #expect(
      nombres(GameSortOrder.nameAscending.sort(biblioteca))
        == ["Alan Wake", "Celeste", "Zelda"]
    )
  }

  @Test("Por horas, de mas a menos")
  func masJugados() {
    let biblioteca = [juego("Poco", horas: 1), juego("Mucho", horas: 100)]

    #expect(nombres(GameSortOrder.playtimeDescending.sort(biblioteca)) == ["Mucho", "Poco"])
  }

  @Test("Por horas, de menos a mas")
  func menosJugados() {
    let biblioteca = [juego("Mucho", horas: 100), juego("Poco", horas: 1)]

    #expect(nombres(GameSortOrder.playtimeAscending.sort(biblioteca)) == ["Poco", "Mucho"])
  }

  @Test("Con las mismas horas se desempata por nombre")
  func desempatePorNombre() {
    let biblioteca = [juego("Zeta", horas: 5), juego("Alfa", horas: 5)]

    #expect(
      nombres(GameSortOrder.playtimeDescending.sort(biblioteca)) == ["Alfa", "Zeta"],
      "Sin desempate el orden seria impredecible"
    )
  }

  @Test("Por ultima partida, de mas reciente a mas antigua")
  func ultimaPartida() {
    let viejo = Date(timeIntervalSince1970: 1_600_000_000)
    let nuevo = Date(timeIntervalSince1970: 1_700_000_000)
    let biblioteca = [
      juego("Viejo", lastPlayed: viejo),
      juego("Nuevo", lastPlayed: nuevo)
    ]

    #expect(
      nombres(GameSortOrder.lastPlayedDescending.sort(biblioteca)) == ["Nuevo", "Viejo"]
    )
  }

  @Test("Los juegos sin fecha van al final, no al principio")
  func sinFechaAlFinal() {
    let biblioteca = [
      juego("Nunca jugado", lastPlayed: nil),
      juego("Jugado", lastPlayed: Date(timeIntervalSince1970: 1_700_000_000))
    ]

    #expect(
      nombres(GameSortOrder.lastPlayedDescending.sort(biblioteca))
        == ["Jugado", "Nunca jugado"],
      "Un juego sin fecha no es el mas antiguo: es uno del que no se sabe"
    )
  }

  @Test("Entre los que no tienen fecha se ordena por nombre")
  func sinFechaOrdenadosPorNombre() {
    let biblioteca = [juego("Zeta"), juego("Alfa")]

    #expect(
      nombres(GameSortOrder.lastPlayedDescending.sort(biblioteca)) == ["Alfa", "Zeta"]
    )
  }

  @Test("Por fecha de agregado, de mas reciente a mas antiguo")
  func agregadosHacePoco() {
    let biblioteca = [
      juego("Primero", addedAt: Date(timeIntervalSince1970: 1_000)),
      juego("Ultimo", addedAt: Date(timeIntervalSince1970: 9_000))
    ]

    #expect(nombres(GameSortOrder.recentlyAdded.sort(biblioteca)) == ["Ultimo", "Primero"])
  }

  @Test("Ordenar una lista vacia no rompe")
  func listaVacia() {
    for orden in GameSortOrder.allCases {
      #expect(orden.sort([]).isEmpty)
    }
  }

  @Test("Todos los ordenes devuelven la misma cantidad de juegos")
  func noPierdeJuegos() {
    let biblioteca = [
      juego("A", horas: 5, lastPlayed: Date()),
      juego("B", horas: 0),
      juego("C", horas: 10, releaseDate: Date())
    ]

    for orden in GameSortOrder.allCases {
      #expect(orden.sort(biblioteca).count == 3, "\(orden) perdio juegos")
    }
  }

  @Test("Solo la fecha de lanzamiento avisa que no hay datos")
  func avisoDeDatoAusente() {
    // Steam no manda la fecha de lanzamiento en GetOwnedGames
    #expect(GameSortOrder.releaseDateDescending.unavailableNote != nil)

    let conDatos = GameSortOrder.allCases.filter { $0 != .releaseDateDescending }
    #expect(conDatos.allSatisfy { $0.unavailableNote == nil })
  }

  @Test("Todos los ordenes tienen nombre y simbolo")
  func presentacionCompleta() {
    for orden in GameSortOrder.allCases {
      #expect(orden.displayName.isEmpty == false)
      #expect(orden.symbolName.isEmpty == false)
    }
  }
}

// MARK: - Todo junto

@Suite("Consulta completa: buscar, filtrar y ordenar")
@MainActor
struct GameQueryTests {

  private func biblioteca() -> [Game] {
    [
      juego("ARK: Survival Evolved", store: .steam, status: .backlog, horas: 0),
      juego("ARK: Survival Of The Fittest", store: .steam, status: .playing, horas: 3),
      juego("Dark Souls", store: .psn, status: .finished, horas: 60),
      juego("Sparking ZERO", store: .steam, status: .backlog, horas: 8)
    ]
  }

  @Test("Sin nada puesto devuelve todo, ordenado por nombre")
  func sinNadaPuesto() {
    let resultado = GameQuery().apply(to: biblioteca())

    #expect(resultado.count == 4)
    #expect(resultado.first?.name == "ARK: Survival Evolved")
  }

  @Test("La busqueda y el filtro se combinan")
  func busquedaMasFiltro() {
    var consulta = GameQuery(search: "ark")
    consulta.filter.statuses = [.playing]

    let resultado = consulta.apply(to: biblioteca())

    #expect(nombres(resultado) == ["ARK: Survival Of The Fittest"])
  }

  @Test("El orden elegido gana sobre el de relevancia de la busqueda")
  func ordenGanaARelevancia() {
    // "ark" coincide con los dos ARK (empiezan) y con Dark y Sparking (contienen)
    let consulta = GameQuery(search: "ark", sort: .playtimeDescending)

    let resultado = consulta.apply(to: biblioteca())

    #expect(
      resultado.first?.name == "Dark Souls",
      "Si el usuario pidio 'mas jugados', eso manda tambien dentro de la busqueda"
    )
  }

  @Test("Filtrar y ordenar a la vez")
  func filtrarYOrdenar() {
    var consulta = GameQuery(sort: .playtimeDescending)
    consulta.filter.stores = [.steam]

    let resultado = consulta.apply(to: biblioteca())

    #expect(nombres(resultado) == [
      "Sparking ZERO",
      "ARK: Survival Of The Fittest",
      "ARK: Survival Evolved"
    ])
  }

  @Test("isNarrowing avisa si la lista esta recortada")
  func avisaSiEstaRecortada() {
    #expect(GameQuery().isNarrowing == false)
    #expect(GameQuery(search: "ark").isNarrowing)
    #expect(GameQuery(search: "   ").isNarrowing == false, "Espacios no cuentan")

    var conFiltro = GameQuery()
    conFiltro.filter.stores = [.steam]
    #expect(conFiltro.isNarrowing)
  }

  @Test("Una combinacion sin resultados devuelve lista vacia, no falla")
  func sinResultados() {
    var consulta = GameQuery(search: "zzz")
    consulta.filter.stores = [.epic]

    #expect(consulta.apply(to: biblioteca()).isEmpty)
  }
}

// MARK: - Preferencia de orden

@Suite("La preferencia de orden se recuerda")
@MainActor
struct LibraryPreferencesTests {

  private func defaultsAislados() -> UserDefaults {
    UserDefaults(suiteName: "test.\(UUID().uuidString)") ?? .standard
  }

  @Test("Sin nada guardado se usa el orden por defecto")
  func valorPorDefecto() {
    let preferencias = LibraryPreferences(defaults: defaultsAislados())

    #expect(preferencias.sortOrder == .nameAscending)
  }

  @Test("El orden elegido sobrevive al cierre de la app")
  func persisteEntreSesiones() {
    let defaults = defaultsAislados()

    let primera = LibraryPreferences(defaults: defaults)
    primera.sortOrder = .playtimeDescending

    // Simula abrir la app otra vez
    let segunda = LibraryPreferences(defaults: defaults)

    #expect(segunda.sortOrder == .playtimeDescending)
  }

  @Test("Se pueden guardar todos los ordenes")
  func todosSeGuardan() {
    for orden in GameSortOrder.allCases {
      let defaults = defaultsAislados()
      LibraryPreferences(defaults: defaults).sortOrder = orden

      #expect(LibraryPreferences(defaults: defaults).sortOrder == orden)
    }
  }

  @Test("Un valor guardado que ya no existe vuelve al por defecto")
  func valorDesconocido() {
    let defaults = defaultsAislados()
    defaults.set("ordenQueYaNoExiste", forKey: "library.sortOrder")

    #expect(
      LibraryPreferences(defaults: defaults).sortOrder == .nameAscending,
      "Quitar un caso del enum no puede dejar la app sin poder arrancar"
    )
  }
}
