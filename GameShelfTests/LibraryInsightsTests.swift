//
//  LibraryInsightsTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@MainActor
private func juego(
  _ nombre: String,
  horas: Double = 0,
  recientes: Double = 0,
  status estado: PlayStatus = .backlog
) -> Game {
  let juego = Game(name: nombre, playtimeHours: horas)
  juego.status = estado
  juego.storeEntries = [
    StoreEntry(
      store: .steam,
      storeGameID: nombre,
      playtimeHours: horas,
      recentPlaytimeHours: recientes
    )
  ]
  return juego
}

private func nombres(_ juegos: [Game]) -> [String] {
  juegos.map(\.name)
}

@Suite("Analisis: resumen")
@MainActor
struct InsightsSummaryTests {

  @Test("Una biblioteca vacia da todo en cero, sin dividir por cero")
  func bibliotecaVacia() {
    let resumen = LibraryInsights.summary(for: [])

    #expect(resumen.isEmpty)
    #expect(resumen.totalGames == 0)
    #expect(resumen.totalHours == 0)
    #expect(resumen.unplayedFraction == 0, "No puede ser NaN")
    #expect(resumen.averageHoursPerPlayedGame == 0)
  }

  @Test("Con un solo juego los numeros cuadran")
  func unSoloJuego() {
    let resumen = LibraryInsights.summary(for: [juego("Uno", horas: 10)])

    #expect(resumen.totalGames == 1)
    #expect(resumen.totalHours == 10)
    #expect(resumen.unplayedCount == 0)
    #expect(resumen.averageHoursPerPlayedGame == 10)
  }

  @Test("Con todos en cero horas no se divide por cero")
  func todosEnCero() {
    let biblioteca = [juego("A"), juego("B"), juego("C")]

    let resumen = LibraryInsights.summary(for: biblioteca)

    #expect(resumen.unplayedCount == 3)
    #expect(resumen.unplayedFraction == 1.0, "El 100% esta sin jugar")
    #expect(
      resumen.averageHoursPerPlayedGame == 0,
      "Sin juegos jugados el promedio es 0, no NaN"
    )
  }

  @Test("Cuenta bien jugados, sin jugar y apenas probados")
  func cuentaCategorias() {
    let biblioteca = [
      juego("Sin jugar 1"),
      juego("Sin jugar 2"),
      juego("Apenas", horas: 0.5),
      juego("Jugado", horas: 50)
    ]

    let resumen = LibraryInsights.summary(for: biblioteca)

    #expect(resumen.totalGames == 4)
    #expect(resumen.unplayedCount == 2)
    #expect(resumen.barelyTriedCount == 1)
    #expect(resumen.totalHours == 50.5)
  }

  @Test("El porcentaje sin jugar se calcula bien")
  func porcentajeSinJugar() {
    let biblioteca = [juego("A"), juego("B"), juego("C", horas: 5), juego("D", horas: 5)]

    #expect(LibraryInsights.summary(for: biblioteca).unplayedFraction == 0.5)
  }

  @Test("El promedio ignora los juegos sin jugar")
  func promedioIgnoraLosNoJugados() {
    let biblioteca = [juego("Sin jugar"), juego("Uno", horas: 10), juego("Dos", horas: 20)]

    #expect(
      LibraryInsights.summary(for: biblioteca).averageHoursPerPlayedGame == 15,
      "30 h entre 2 jugados, no entre 3 totales"
    )
  }

  @Test("Cuenta los jugados hace poco")
  func cuentaRecientes() {
    let biblioteca = [
      juego("Reciente", horas: 20, recientes: 3),
      juego("Viejo", horas: 20)
    ]

    #expect(LibraryInsights.summary(for: biblioteca).recentlyPlayedCount == 1)
  }
}

@Suite("Analisis: secciones automaticas")
@MainActor
struct InsightsSectionTests {

  private func biblioteca() -> [Game] {
    [
      juego("Nunca A"),
      juego("Nunca B"),
      juego("Apenas", horas: 0.4),
      juego("Medio", horas: 20),
      juego("Mucho", horas: 200, recientes: 5)
    ]
  }

  @Test("Nunca jugados son los de cero horas, en orden alfabetico")
  func nuncaJugados() {
    let seccion = LibraryInsights.section(of: .neverPlayed, for: biblioteca())

    #expect(nombres(seccion.games) == ["Nunca A", "Nunca B"])
  }

  @Test("Apenas probados son los de menos de una hora, pero jugados")
  func apenasProbados() {
    let seccion = LibraryInsights.section(of: .barelyTried, for: biblioteca())

    #expect(
      nombres(seccion.games) == ["Apenas"],
      "Los de 0 h no cuentan: esos son 'nunca jugados'"
    )
  }

  @Test("Justo en una hora ya no es 'apenas probado'")
  func limiteDeApenasProbado() {
    let biblioteca = [juego("Justo", horas: 1), juego("Casi", horas: 0.99)]

    let seccion = LibraryInsights.section(of: .barelyTried, for: biblioteca)

    #expect(nombres(seccion.games) == ["Casi"])
  }

  @Test("Los mas jugados van de mas a menos horas")
  func masJugados() {
    let seccion = LibraryInsights.section(of: .mostPlayed, for: biblioteca())

    #expect(nombres(seccion.games) == ["Mucho", "Medio", "Apenas"])
  }

  @Test("Jugados hace poco usa las horas recientes, no las totales")
  func jugadosHacePoco() {
    let biblioteca = [
      juego("Muchas horas totales", horas: 500),
      juego("Poco total pero reciente", horas: 3, recientes: 2)
    ]

    let seccion = LibraryInsights.section(of: .recentlyPlayed, for: biblioteca)

    #expect(nombres(seccion.games) == ["Poco total pero reciente"])
  }

  @Test("Las secciones vacias no se muestran")
  func seccionesVaciasSeOmiten() {
    // Todos jugados: no deberia salir "Nunca jugados"
    let biblioteca = [juego("A", horas: 10), juego("B", horas: 20)]

    let clases = LibraryInsights.sections(for: biblioteca).map(\.kind)

    #expect(clases.contains(.mostPlayed))
    #expect(clases.contains(.neverPlayed) == false)
  }

  @Test("Con la biblioteca vacia no hay ninguna seccion")
  func sinSeccionesSiNoHayJuegos() {
    #expect(LibraryInsights.sections(for: []).isEmpty)
  }

  @Test("Se respeta el limite y se avisa cuantos quedan fuera")
  func limiteYResto() {
    let biblioteca = (1...25).map { juego("Juego \($0)", horas: Double($0)) }

    let seccion = LibraryInsights.section(of: .mostPlayed, for: biblioteca, limit: 10)

    #expect(seccion.games.count == 10)
    #expect(seccion.totalCount == 25)
    #expect(seccion.hasMore)
  }

  @Test("Si caben todos, no dice que hay mas")
  func sinResto() {
    let seccion = LibraryInsights.section(
      of: .mostPlayed,
      for: [juego("A", horas: 1)],
      limit: 10
    )

    #expect(seccion.hasMore == false)
  }

  @Test("Todas las clases tienen titulo, explicacion y simbolo")
  func presentacionCompleta() {
    for clase in LibraryInsights.SectionKind.allCases {
      #expect(clase.title.isEmpty == false)
      #expect(clase.explanation.isEmpty == false)
      #expect(clase.symbolName.isEmpty == false)
    }
  }
}

@Suite("Analisis: reparto del tiempo")
@MainActor
struct InsightsConcentrationTests {

  @Test("Sin horas registradas da todo en cero")
  func sinHoras() {
    let reparto = LibraryInsights.concentration(for: [juego("A"), juego("B")])

    #expect(reparto == LibraryInsights.Concentration())
    #expect(reparto.topGameShare == 0, "No puede ser NaN")
  }

  @Test("Con la biblioteca vacia tampoco falla")
  func bibliotecaVacia() {
    #expect(LibraryInsights.concentration(for: []).gamesForHalfTheTime == 0)
  }

  @Test("Con un solo juego, ese concentra todo")
  func unSoloJuego() {
    let reparto = LibraryInsights.concentration(for: [juego("Unico", horas: 100)])

    #expect(reparto.gamesForHalfTheTime == 1)
    #expect(reparto.topGameShare == 1.0)
    #expect(reparto.topFiveShare == 1.0)
  }

  @Test("Cuenta cuantos juegos hacen la mitad del tiempo")
  func mitadDelTiempo() {
    // 100 de 200 totales: el primero solo ya es la mitad
    let biblioteca = [
      juego("Grande", horas: 100),
      juego("A", horas: 25),
      juego("B", horas: 25),
      juego("C", horas: 25),
      juego("D", horas: 25)
    ]

    let reparto = LibraryInsights.concentration(for: biblioteca)

    #expect(reparto.gamesForHalfTheTime == 1)
    #expect(reparto.topGameShare == 0.5)
  }

  @Test("Con el tiempo repartido por igual hacen falta mas juegos")
  func repartoParejo() {
    let biblioteca = (1...10).map { juego("J\($0)", horas: 10) }

    let reparto = LibraryInsights.concentration(for: biblioteca)

    #expect(reparto.gamesForHalfTheTime == 5)
    #expect(abs(reparto.topGameShare - 0.1) < 0.001)
  }

  @Test("Los juegos sin horas no cuentan en el reparto")
  func ignoraLosNoJugados() {
    let biblioteca = [juego("Jugado", horas: 100)] + (1...50).map { juego("Sin jugar \($0)") }

    let reparto = LibraryInsights.concentration(for: biblioteca)

    #expect(reparto.topGameShare == 1.0, "El unico con horas se lleva todo el tiempo")
  }
}

@Suite("Analisis: sugerencia de pendientes")
@MainActor
struct InsightsSuggestionTests {

  @Test("Propone los de cero horas que no estan marcados")
  func candidatos() {
    let biblioteca = [
      juego("Sin marcar", status: .wishlist),
      juego("Ya pendiente", status: .backlog),
      juego("Jugado", horas: 10, status: .playing)
    ]

    let propuestos = LibraryInsights.candidatesForBacklog(in: biblioteca)

    #expect(nombres(propuestos) == ["Sin marcar"])
  }

  @Test("No toca los que el usuario clasifico a mano con horas")
  func respetaLaDecisionDelUsuario() {
    // Terminado en consola: 0 h en Steam pero el usuario lo marco a proposito
    let enConsola = juego("Terminado en consola", status: .finished)

    let propuestos = LibraryInsights.candidatesForBacklog(in: [enConsola])

    #expect(
      nombres(propuestos) == ["Terminado en consola"],
      "Se propone, pero la confirmacion es del usuario: no se cambia solo"
    )
  }

  @Test("Sin candidatos devuelve lista vacia")
  func sinCandidatos() {
    let biblioteca = [juego("Ya pendiente"), juego("Jugado", horas: 5, status: .playing)]

    #expect(LibraryInsights.candidatesForBacklog(in: biblioteca).isEmpty)
  }

  @Test("Con la biblioteca vacia no propone nada")
  func bibliotecaVacia() {
    #expect(LibraryInsights.candidatesForBacklog(in: []).isEmpty)
  }
}

@Suite("Analisis: las horas recientes se guardan")
@MainActor
struct RecentPlaytimePersistenceTests {

  private func hacerContexto() throws -> ModelContext {
    let schema = Schema([Game.self, StoreEntry.self, GameCollection.self, GameTag.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return ModelContext(try ModelContainer(for: schema, configurations: [config]))
  }

  @Test("Sincronizar guarda las horas de las ultimas dos semanas")
  func seGuardanAlSincronizar() throws {
    let context = try hacerContexto()
    let dtos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(dtos, into: context)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    let reciente = try #require(juegos.first { $0.isRecentlyPlayed })

    // En el fixture solo un juego trae playtime_2weeks: 320 minutos
    #expect(abs(reciente.recentPlaytimeHours - 5.3333) < 0.001)
    #expect(juegos.filter(\.isRecentlyPlayed).count == 1)
  }

  @Test("Re-sincronizar actualiza las horas recientes")
  func seActualizan() throws {
    let context = try hacerContexto()
    let dtos = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_owned_games")
      .response.games

    try SteamLibrarySyncer.sync(dtos, into: context)
    try SteamLibrarySyncer.sync(dtos, into: context)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.filter(\.isRecentlyPlayed).count == 1, "No debe duplicarse ni acumularse")
  }
}
