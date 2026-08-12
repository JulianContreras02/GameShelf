package com.gameshelf.ui.detail

import androidx.lifecycle.ViewModel
import com.gameshelf.data.repository.GameStore
import com.gameshelf.domain.Game

/**
 * Guarda las notas personales de un juego.
 *
 * Las notas son el dato mas irrecuperable de la app: un juego borrado se
 * vuelve a sincronizar, pero lo que escribio el usuario no. Por eso el
 * guardado es automatico y esta cubierto por pruebas.
 */
class GameNotesViewModel(private val store: GameStore) : ViewModel() {

  /**
   * Guarda las notas si cambiaron.
   *
   * Recorta los espacios de los bordes: una nota que solo tiene espacios es
   * una nota vacia, y guardarla haria que el juego pareciera tener algo
   * escrito.
   *
   * @return `true` si de verdad se guardo algo distinto.
   */
  suspend fun save(texto: String, juego: Game): Boolean {
    val limpio = clean(texto)
    if (limpio == juego.notes) return false

    store.setNotes(juego.id, limpio)
    return true
  }

  /** Borra las notas de un juego. */
  suspend fun clear(juego: Game) {
    if (juego.notes.isEmpty()) return
    store.setNotes(juego.id, "")
  }

  companion object {
    /**
     * Limite del texto.
     *
     * No es una restriccion del almacenamiento: es para que un pegado
     * accidental de miles de lineas no vuelva lenta la ficha del juego.
     */
    const val MAX_LENGTH = 5_000

    /** A partir de cuantos caracteres se muestra el contador. */
    const val COUNTER_THRESHOLD = 4_500

    /**
     * Deja el texto como se va a guardar.
     *
     * Recorta los bordes y corta si pasa del limite. Los saltos de linea de en
     * medio se conservan: son parte de lo que escribio el usuario.
     */
    fun clean(texto: String): String = texto.trim().take(MAX_LENGTH)

    /** Si el texto se va a recortar al guardar. */
    fun exceedsLimit(texto: String): Boolean = texto.trim().length > MAX_LENGTH

    /** Si conviene mostrar el contador de caracteres. */
    fun shouldShowCounter(texto: String): Boolean = texto.length >= COUNTER_THRESHOLD
  }
}
