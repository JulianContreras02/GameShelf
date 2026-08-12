package com.gameshelf.ui.collections

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError
import com.gameshelf.data.repository.GameStore
import com.gameshelf.domain.CollectionColor
import com.gameshelf.domain.CollectionSymbol
import com.gameshelf.domain.Game
import com.gameshelf.domain.GameCollection
import com.gameshelf.domain.normalizedForSearch
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Crea, edita, borra y reordena colecciones.
 *
 * Aca vive lo que puede salir mal: validar el nombre y mantener el orden
 * coherente. Ver `docs/decisiones/001-arquitectura.md`.
 */
class CollectionsViewModel(private val store: GameStore) : ViewModel() {

  /** Por que se rechazo un nombre. */
  sealed class ValidationError : Exception(), UserFacingError {
    data object EmptyName : ValidationError()
    data class DuplicateName(val nombre: String) : ValidationError()
    data class TooLong(val max: Int) : ValidationError()

    override fun message(context: Context): String = when (this) {
      EmptyName -> context.getString(R.string.collection_error_empty_name)
      is DuplicateName -> context.getString(R.string.collection_error_duplicate, nombre)
      is TooLong -> context.getString(R.string.collection_error_too_long, max)
    }
  }

  val collections = store.observeCollections()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  val games = store.observeGames()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  fun observeCollection(id: UUID) = store.observeCollection(id)

  // --- Crear ---------------------------------------------------------------

  /**
   * Crea una coleccion al final de la lista.
   *
   * @throws ValidationError si el nombre esta vacio, repetido o es muy largo.
   */
  suspend fun create(
    name: String,
    symbol: CollectionSymbol = GameCollection.DEFAULT_SYMBOL,
    color: CollectionColor = CollectionColor.DEFAULT,
  ): GameCollection {
    val limpio = validar(name)

    val coleccion = GameCollection(
      name = limpio,
      symbol = symbol,
      color = color,
      sortOrder = store.nextCollectionSortOrder(),
    )
    store.saveCollection(coleccion)
    return coleccion
  }

  // --- Editar --------------------------------------------------------------

  /**
   * Cambia el nombre.
   *
   * Un nombre repetido se permite si es el de la propia coleccion (renombrar
   * sin cambiar nada).
   */
  suspend fun rename(coleccion: GameCollection, nuevoNombre: String) {
    val limpio = validar(nuevoNombre, ignorando = coleccion.id)
    store.saveCollection(coleccion.copy(name = limpio))
  }

  /** Cambia simbolo y color. No hay nada que validar aca. */
  suspend fun updateAppearance(
    coleccion: GameCollection,
    symbol: CollectionSymbol,
    color: CollectionColor,
  ) {
    store.saveCollection(coleccion.copy(symbol = symbol, color = color))
  }

  // --- Borrar --------------------------------------------------------------

  /**
   * Borra la coleccion.
   *
   * Los juegos que contenia **no se borran**: solo se deshace la agrupacion.
   * Lo garantiza el cascade de la tabla puente, que no toca la de juegos.
   */
  suspend fun delete(coleccion: GameCollection) {
    store.deleteCollection(coleccion.id)
    renumerar()
  }

  // --- Asignar juegos ------------------------------------------------------

  /**
   * Mete o saca un juego de una coleccion, segun donde este.
   *
   * @return `true` si quedo dentro, `false` si quedo fuera.
   */
  suspend fun toggle(juego: Game, coleccion: GameCollection): Boolean {
    val estaba = juego.collections.any { it.id == coleccion.id }
    if (estaba) {
      store.unlink(juego.id, coleccion.id)
    } else {
      store.link(juego.id, coleccion.id)
    }
    return !estaba
  }

  /**
   * Agrega varios juegos a una coleccion de una sola vez.
   *
   * Los que ya estaban no se duplican ni se cuentan.
   *
   * @return Cuantos se agregaron de verdad.
   */
  suspend fun add(juegos: List<Game>, coleccion: GameCollection): Int {
    val nuevos = juegos.filterNot { juego -> juego.collections.any { it.id == coleccion.id } }
    nuevos.forEach { store.link(it.id, coleccion.id) }
    return nuevos.size
  }

  /**
   * Quita varios juegos de una coleccion. Los juegos no se borran.
   *
   * @return Cuantos se quitaron de verdad.
   */
  suspend fun remove(juegos: List<Game>, coleccion: GameCollection): Int {
    val presentes = juegos.filter { juego -> juego.collections.any { it.id == coleccion.id } }
    presentes.forEach { store.unlink(it.id, coleccion.id) }
    return presentes.size
  }

  // --- Reordenar -----------------------------------------------------------

  /**
   * Mueve una coleccion dentro de la lista y reescribe el orden de todas.
   *
   * En iOS la firma imitaba `onMove` de SwiftUI, que entrega un `IndexSet` y
   * un destino calculado **antes** de sacar los elementos. En Compose el
   * arrastre entrega dos indices directos, asi que la funcion es la version
   * simple de lo mismo y desaparece el ajuste que alla era facil de equivocar.
   */
  fun move(colecciones: List<GameCollection>, desde: Int, hasta: Int) {
    if (desde == hasta) return
    if (desde !in colecciones.indices || hasta !in colecciones.indices) return

    val reordenadas = colecciones.toMutableList().apply { add(hasta, removeAt(desde)) }

    viewModelScope.launch {
      store.saveCollections(reordenadas.mapIndexed { indice, c -> c.copy(sortOrder = indice) })
    }
  }

  // --- Apoyo ---------------------------------------------------------------

  /**
   * Limpia y comprueba un nombre.
   *
   * @param ignorando Coleccion que no cuenta al buscar repetidos, para poder
   *   guardar una sin cambiarle el nombre.
   */
  private suspend fun validar(nombre: String, ignorando: UUID? = null): String {
    val limpio = nombre.trim()

    if (limpio.isEmpty()) throw ValidationError.EmptyName
    if (limpio.length > MAX_NAME_LENGTH) throw ValidationError.TooLong(MAX_NAME_LENGTH)

    // La comparacion ignora mayusculas y tildes, la misma regla que usan la
    // busqueda y las etiquetas.
    val buscado = limpio.normalizedForSearch
    val repetido = store.allCollections().any {
      it.id != ignorando && it.name.normalizedForSearch == buscado
    }
    if (repetido) throw ValidationError.DuplicateName(limpio)

    return limpio
  }

  /**
   * Deja el orden en 0, 1, 2... sin huecos.
   *
   * Despues de borrar quedan saltos, y aunque no se noten en pantalla,
   * arrastrando se vuelven inconsistentes.
   */
  private suspend fun renumerar() {
    val ordenadas = store.allCollections().sortedBy { it.sortOrder }
    store.saveCollections(ordenadas.mapIndexed { indice, c -> c.copy(sortOrder = indice) })
  }

  companion object {
    /**
     * Limite del nombre. Uno muy largo se recorta en pantalla y no se
     * distingue de otro parecido.
     */
    const val MAX_NAME_LENGTH = 40

    /**
     * Simbolos entre los que elegir.
     *
     * En iOS era una lista curada de SF Symbols porque un selector con todos
     * seria inmanejable. Aca el conjunto ya viene cerrado por el propio enum,
     * por el motivo que explica [CollectionSymbol].
     */
    val availableSymbols: List<CollectionSymbol> = CollectionSymbol.entries
  }
}
