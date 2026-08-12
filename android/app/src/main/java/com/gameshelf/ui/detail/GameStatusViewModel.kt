package com.gameshelf.ui.detail

import androidx.lifecycle.ViewModel
import com.gameshelf.data.repository.GameStore
import com.gameshelf.domain.Game
import com.gameshelf.domain.NameOrder
import com.gameshelf.domain.PlayStatus

/**
 * Cambia el estado de progreso de los juegos y cuenta cuantos hay en cada uno.
 *
 * El estado es un dato **del usuario**: no viene de Steam y ninguna
 * sincronizacion lo puede sobrescribir.
 */
class GameStatusViewModel(private val store: GameStore) : ViewModel() {

  /**
   * Pone un estado nuevo a un juego.
   *
   * Si ya lo tenia, no guarda: evita escrituras y notificaciones inutiles a
   * las vistas.
   *
   * @return `true` si de verdad cambio.
   */
  suspend fun setStatus(estado: PlayStatus, juego: Game): Boolean {
    if (juego.status == estado) return false
    store.setStatus(juego.id, estado)
    return true
  }

  /**
   * Pone el mismo estado a varios juegos de una vez.
   *
   * @return Cuantos cambiaron de verdad.
   */
  suspend fun setStatus(estado: PlayStatus, juegos: List<Game>): Int {
    val porCambiar = juegos.filter { it.status != estado }
    porCambiar.forEach { store.setStatus(it.id, estado) }
    return porCambiar.size
  }

  companion object {
    /**
     * Cuantos juegos hay en cada estado.
     *
     * Devuelve **todos** los estados, incluso los que estan en cero: asi la
     * pantalla no cambia de tamano segun lo que haya.
     */
    fun counts(juegos: List<Game>): Map<PlayStatus, Int> {
      val resultado = PlayStatus.entries.associateWith { 0 }.toMutableMap()
      juegos.forEach { juego -> resultado[juego.status] = (resultado[juego.status] ?: 0) + 1 }
      return resultado
    }

    /** Juegos de un estado, ordenados por nombre. */
    fun games(juegos: List<Game>, estado: PlayStatus): List<Game> =
      juegos.filter { it.status == estado }.sortedWith(NameOrder.byName())
  }
}
