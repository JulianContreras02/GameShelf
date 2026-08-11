//
//  GameSearchTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

private func juegos(_ nombres: [String]) -> [Game] {
  nombres.map { Game(name: $0) }
}

private func nombres(_ resultado: [Game]) -> [String] {
  resultado.map(\.name)
}

@Suite("Busqueda: coincidencias basicas")
struct SearchBasicsTests {

  @Test("Encuentra por una parte del nombre")
  func encuentraPorSubcadena() {
    let biblioteca = juegos(["Hollow Knight", "Celeste", "Hades"])

    #expect(nombres(GameSearch.filter(biblioteca, query: "hollow")) == ["Hollow Knight"])
    #expect(nombres(GameSearch.filter(biblioteca, query: "knight")) == ["Hollow Knight"])
  }

  @Test("Encuentra por una parte en medio de una palabra")
  func encuentraEnMedio() {
    let biblioteca = juegos(["Stardew Valley"])

    #expect(GameSearch.filter(biblioteca, query: "ardew").count == 1)
  }

  @Test("Devuelve varios cuando varios coinciden")
  func variosResultados() {
    let biblioteca = juegos([
      "ARK: Survival Evolved",
      "ARK: Survival Of The Fittest",
      "Celeste"
    ])

    #expect(GameSearch.filter(biblioteca, query: "ark").count == 2)
  }

  @Test("Sin coincidencias devuelve lista vacia")
  func sinCoincidencias() {
    #expect(GameSearch.filter(juegos(["Celeste"]), query: "zzzz").isEmpty)
  }
}

@Suite("Busqueda: mayusculas y tildes")
struct SearchNormalizationTests {

  @Test("Las mayusculas no importan", arguments: ["hollow", "HOLLOW", "HoLLoW"])
  func ignoraMayusculas(consulta: String) {
    let biblioteca = juegos(["Hollow Knight"])

    #expect(GameSearch.filter(biblioteca, query: consulta).count == 1)
  }

  @Test("Las tildes no importan al escribir la busqueda")
  func buscaSinTildes() {
    let biblioteca = juegos(["Rayman Legends: Edición Especial"])

    #expect(GameSearch.filter(biblioteca, query: "edicion").count == 1)
    #expect(GameSearch.filter(biblioteca, query: "edición").count == 1)
  }

  @Test("Las tildes tampoco importan en el nombre del juego")
  func encuentraNombresConTilde() {
    let biblioteca = juegos(["Accion Directa", "Acción Indirecta"])

    #expect(GameSearch.filter(biblioteca, query: "accion").count == 2)
    #expect(GameSearch.filter(biblioteca, query: "acción").count == 2)
  }

  @Test("Escribir sin la ñ tambien encuentra el juego")
  func laEnieSeEncuentraSinTilde() {
    let biblioteca = juegos(["El Niño"])

    // `.diacriticInsensitive` trata la ñ como una n con tilde, asi que "nino"
    // encuentra "Niño". Conviene tenerlo presente: en español la ñ es una letra
    // aparte, pero para buscar es mas util que funcione escribiendola sin tilde.
    #expect(GameSearch.filter(biblioteca, query: "nino").count == 1)
    #expect(GameSearch.filter(biblioteca, query: "niño").count == 1)
  }
}

@Suite("Busqueda: casos borde")
struct SearchEdgeCaseTests {

  @Test("Una busqueda vacia devuelve todos")
  func busquedaVacia() {
    let biblioteca = juegos(["Uno", "Dos", "Tres"])

    #expect(GameSearch.filter(biblioteca, query: "").count == 3)
  }

  @Test("Una busqueda de solo espacios devuelve todos")
  func soloEspacios() {
    let biblioteca = juegos(["Uno", "Dos"])

    #expect(
      GameSearch.filter(biblioteca, query: "    ").count == 2,
      "Borrar lo escrito no puede dejar la biblioteca en blanco"
    )
  }

  @Test("Los espacios sobrantes alrededor no afectan")
  func recortaEspacios() {
    let biblioteca = juegos(["Hollow Knight"])

    #expect(GameSearch.filter(biblioteca, query: "  hollow  ").count == 1)
  }

  @Test("Buscar en una biblioteca vacia no rompe")
  func bibliotecaVacia() {
    #expect(GameSearch.filter([], query: "algo").isEmpty)
    #expect(GameSearch.filter([], query: "").isEmpty)
  }

  @Test("Los signos de puntuacion se buscan tal cual")
  func puntuacion() {
    let biblioteca = juegos(["ARK: Survival Evolved"])

    #expect(GameSearch.filter(biblioteca, query: "ark:").count == 1)
    #expect(GameSearch.filter(biblioteca, query: ":").count == 1)
  }
}

@Suite("Busqueda: orden de los resultados")
struct SearchRankingTests {

  @Test("Los que empiezan por lo buscado van primero")
  func prefijoPrimero() {
    let biblioteca = juegos(["Bloodstained: Hollow", "Hollow Knight"])

    let resultado = GameSearch.filter(biblioteca, query: "hollow")

    #expect(
      nombres(resultado) == ["Hollow Knight", "Bloodstained: Hollow"],
      "Lo que empieza por la busqueda es lo que se esta buscando casi siempre"
    )
  }

  @Test("Dentro de cada grupo se ordena por nombre")
  func ordenAlfabeticoDentroDelGrupo() {
    let biblioteca = juegos(["Ark Zulu", "Ark Alpha", "Ark Beta"])

    let resultado = GameSearch.filter(biblioteca, query: "ark")

    #expect(nombres(resultado) == ["Ark Alpha", "Ark Beta", "Ark Zulu"])
  }

  @Test("Sin busqueda se respeta el orden que venia")
  func sinBusquedaNoReordena() {
    let biblioteca = juegos(["Zeta", "Alfa"])

    #expect(
      nombres(GameSearch.filter(biblioteca, query: "")) == ["Zeta", "Alfa"],
      "El orden lo decide quien llama, no la busqueda"
    )
  }

  @Test("El orden combina ambos criterios")
  func ordenCombinado() {
    let biblioteca = juegos([
      "Zelda: Ark",       // contiene
      "Ark Zulu",         // empieza
      "Battle Ark",       // contiene
      "Ark Alpha"         // empieza
    ])

    let resultado = GameSearch.filter(biblioteca, query: "ark")

    #expect(nombres(resultado) == ["Ark Alpha", "Ark Zulu", "Battle Ark", "Zelda: Ark"])
  }
}

@Suite("Busqueda: coincidencia de un solo juego")
struct SearchMatchTests {

  @Test("matches dice si un juego coincide")
  func coincideOno() {
    let juego = Game(name: "Hollow Knight")

    #expect(GameSearch.matches(juego, query: "hollow"))
    #expect(GameSearch.matches(juego, query: "KNIGHT"))
    #expect(GameSearch.matches(juego, query: "celeste") == false)
  }

  @Test("Con una consulta vacia coincide cualquier juego")
  func consultaVaciaCoincide() {
    #expect(GameSearch.matches(Game(name: "Lo que sea"), query: ""))
  }
}

@Suite("Normalizacion de texto")
struct StringNormalizationTests {

  @Test("Quita mayusculas, tildes y espacios de los bordes")
  func normaliza() {
    #expect("  Acción  ".normalizedForSearch == "accion")
    #expect("RPG".normalizedForSearch == "rpg")
  }

  @Test("containsNormalized ignora mayusculas y tildes")
  func contiene() {
    #expect("Edición Especial".containsNormalized("edicion"))
    #expect("Edición Especial".containsNormalized("ESPECIAL"))
    #expect("Edición Especial".containsNormalized("otra") == false)
  }

  @Test("hasPrefixNormalized compara solo el principio")
  func prefijo() {
    #expect("Hollow Knight".hasPrefixNormalized("hollow"))
    #expect("Hollow Knight".hasPrefixNormalized("knight") == false)
  }

  @Test("Una busqueda vacia coincide con todo")
  func vacioCoincide() {
    #expect("Lo que sea".containsNormalized(""))
    #expect("Lo que sea".hasPrefixNormalized("   "))
  }
}
