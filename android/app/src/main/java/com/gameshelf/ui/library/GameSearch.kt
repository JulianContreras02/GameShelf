package com.gameshelf.ui.library

import com.gameshelf.domain.Game
import com.gameshelf.domain.NameOrder
import com.gameshelf.domain.containsNormalized
import com.gameshelf.domain.hasPrefixNormalized
import com.gameshelf.domain.normalizedForSearch

/**
 * Busca juegos por nombre.
 *
 * Es un objeto sin estado y con funciones puras a proposito: la busqueda es la
 * clase de logica que hay que poder probar sin levantar una pantalla ni una
 * base de datos.
 */
object GameSearch {

  /**
   * Filtra los juegos que coinciden con lo buscado.
   *
   * Una busqueda vacia (o de solo espacios) devuelve **todos**: escribir y
   * borrar no puede dejar la biblioteca en blanco.
   *
   * Los resultados se ordenan por relevancia:
   * 1. Los que empiezan por lo buscado ("hollow" antes que "Bloodstained: Hollow")
   * 2. Los que solo lo contienen
   *
   * Dentro de cada grupo, por nombre.
   */
  fun filter(juegos: List<Game>, query: String): List<Game> {
    val buscado = query.normalizedForSearch
    if (buscado.isEmpty()) return juegos

    val coincidencias = juegos.filter { matches(it, buscado) }
    val (empiezan, contienen) = coincidencias.partition { it.name.hasPrefixNormalized(buscado) }

    val porNombre = NameOrder.byName()
    return empiezan.sortedWith(porNombre) + contienen.sortedWith(porNombre)
  }

  /**
   * Si un juego coincide con lo buscado.
   *
   * Compara solo el nombre. Filtrar por tienda, estado, coleccion o etiqueta
   * es cosa de [GameFilter], para no tener dos formas distintas de acotar la
   * lista haciendo lo mismo.
   */
  fun matches(juego: Game, query: String): Boolean = juego.name.containsNormalized(query)
}
