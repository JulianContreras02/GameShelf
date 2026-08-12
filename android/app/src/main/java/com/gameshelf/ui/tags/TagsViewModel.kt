package com.gameshelf.ui.tags

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError
import com.gameshelf.data.repository.GameStore
import com.gameshelf.domain.Game
import com.gameshelf.domain.GameTag
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn

/**
 * Crea, asigna y borra etiquetas.
 *
 * Lo importante que resuelve: que escribir "RPG" en un juego y "rpg" en otro
 * no cree dos etiquetas distintas.
 */
class TagsViewModel(private val store: GameStore) : ViewModel() {

  sealed class ValidationError : Exception(), UserFacingError {
    data object EmptyName : ValidationError()
    data class TooLong(val max: Int) : ValidationError()

    override fun message(context: Context): String = when (this) {
      EmptyName -> context.getString(R.string.tag_error_empty)
      is TooLong -> context.getString(R.string.tag_error_too_long, max)
    }
  }

  val tags = store.observeTags()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  // --- Crear y asignar -----------------------------------------------------

  /**
   * Devuelve la etiqueta con ese nombre, y la crea si no existe.
   *
   * La comparacion ignora mayusculas y tildes, asi que "RPG" encuentra una
   * "rpg" que ya existiera y **no** crea una segunda.
   *
   * @throws ValidationError si el nombre esta vacio o es muy largo.
   */
  suspend fun findOrCreate(nombre: String): GameTag {
    val limpio = validar(nombre)

    store.allTags().firstOrNull { GameTag.areEquivalent(it.name, limpio) }?.let { return it }

    val nueva = GameTag.create(limpio)
    store.saveTag(nueva)
    return nueva
  }

  /**
   * Le pone una etiqueta a un juego, creandola si hace falta.
   *
   * Si el juego ya la tenia, no hace nada.
   *
   * @return La etiqueta, exista o recien creada.
   */
  suspend fun addTag(nombre: String, juego: Game): GameTag {
    val etiqueta = findOrCreate(nombre)
    if (juego.tags.none { it.id == etiqueta.id }) {
      store.linkTag(juego.id, etiqueta.id)
    }
    return etiqueta
  }

  // --- Quitar --------------------------------------------------------------

  /**
   * Le quita una etiqueta a un juego.
   *
   * Si con eso la etiqueta se queda sin ningun juego, se borra: una etiqueta
   * que no usa nadie solo estorbaria en el autocompletado.
   */
  suspend fun removeTag(etiqueta: GameTag, juego: Game) {
    store.unlinkTag(juego.id, etiqueta.id)
    store.deleteOrphanTags()
  }

  /**
   * Borra una etiqueta y la quita de todos los juegos que la tuvieran.
   *
   * Los juegos no se borran: el cascade solo alcanza a la tabla puente.
   */
  suspend fun delete(etiqueta: GameTag) = store.deleteTag(etiqueta.id)

  /** Borra las etiquetas que no usa ningun juego. */
  suspend fun deleteOrphans() = store.deleteOrphanTags()

  // --- Autocompletado ------------------------------------------------------

  /**
   * Etiquetas que se pueden sugerir mientras se escribe.
   *
   * @param texto Lo que lleva escrito el usuario. Vacio devuelve las mas usadas.
   * @param juego Sus etiquetas se excluyen: no tiene sentido sugerir una que
   *   ya tiene puesta.
   */
  suspend fun suggestions(texto: String, juego: Game?, limite: Int = 8): List<GameTag> =
    suggestions(texto, store.allTags(), juego?.tags ?: emptyList(), limite)

  private suspend fun validar(nombre: String): String {
    val limpio = GameTag.clean(nombre)

    if (limpio.isEmpty()) throw ValidationError.EmptyName
    if (limpio.length > GameTag.MAX_NAME_LENGTH) {
      throw ValidationError.TooLong(GameTag.MAX_NAME_LENGTH)
    }
    return limpio
  }

  companion object {
    /**
     * Version pura del autocompletado, para poder probarla sin base de datos.
     *
     * Ordena poniendo primero las que **empiezan** por lo escrito, y despues
     * las que solo lo contienen. Dentro de cada grupo, las mas usadas primero.
     */
    fun suggestions(
      texto: String,
      todas: List<GameTag>,
      puestas: List<GameTag>,
      limite: Int = 8,
    ): List<GameTag> {
      val buscado = GameTag.normalize(texto)
      val idsPuestas = puestas.map { it.id }.toSet()
      val candidatas = todas.filterNot { it.id in idsPuestas }

      val ordenar: (List<GameTag>) -> List<GameTag> = { grupo ->
        grupo.sortedWith(
          compareByDescending<GameTag> { it.gameCount }.thenBy { it.normalized },
        )
      }

      if (buscado.isEmpty()) return ordenar(candidatas).take(limite)

      val empiezan = candidatas.filter { it.normalized.startsWith(buscado) }
      val contienen = candidatas.filter {
        !it.normalized.startsWith(buscado) && it.normalized.contains(buscado)
      }

      return (ordenar(empiezan) + ordenar(contienen)).take(limite)
    }

    /**
     * Si el texto escrito daria una etiqueta nueva.
     *
     * Sirve para mostrar "Crear …" solo cuando de verdad no existe.
     */
    fun wouldCreateNew(texto: String, todas: List<GameTag>): Boolean {
      val limpio = GameTag.clean(texto)
      if (limpio.isEmpty()) return false
      return todas.none { GameTag.areEquivalent(it.name, limpio) }
    }
  }
}
