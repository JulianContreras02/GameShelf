//
//  GameSearch.swift
//  GameShelf
//

import Foundation

/// Busca juegos por nombre.
///
/// Es un tipo sin estado y con funciones puras a proposito: la busqueda es la
/// clase de logica que hay que poder probar sin levantar una pantalla ni una
/// base de datos.
enum GameSearch {

  /// Filtra los juegos que coinciden con lo buscado.
  ///
  /// Una busqueda vacia (o de solo espacios) devuelve **todos**: escribir y
  /// borrar no puede dejar la biblioteca en blanco.
  ///
  /// Los resultados se ordenan por relevancia:
  /// 1. Los que empiezan por lo buscado ("hollow" antes que "Bloodstained: Hollow")
  /// 2. Los que solo lo contienen
  ///
  /// Dentro de cada grupo, por nombre.
  static func filter(_ juegos: [Game], query consulta: String) -> [Game] {
    let buscado = consulta.normalizedForSearch
    guard !buscado.isEmpty else { return juegos }

    let coincidencias = juegos.filter { matches($0, query: buscado) }

    let empiezan = coincidencias.filter { $0.name.hasPrefixNormalized(buscado) }
    let contienen = coincidencias.filter { !$0.name.hasPrefixNormalized(buscado) }

    return ordenarPorNombre(empiezan) + ordenarPorNombre(contienen)
  }

  /// Si un juego coincide con lo buscado.
  ///
  /// Compara solo el nombre. Filtrar por tienda, estado, coleccion o etiqueta
  /// es cosa del issue #19, para no tener dos formas distintas de acotar la
  /// lista haciendo lo mismo.
  static func matches(_ juego: Game, query consulta: String) -> Bool {
    juego.name.containsNormalized(consulta)
  }

  private static func ordenarPorNombre(_ juegos: [Game]) -> [Game] {
    juegos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
}
