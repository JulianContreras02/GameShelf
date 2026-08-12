package com.gameshelf.ui.library

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.steam.FallbackNames
import com.gameshelf.data.steam.SteamGameDTO
import com.gameshelf.data.steam.SteamServicing
import com.gameshelf.data.sync.SteamLibrarySyncer
import com.gameshelf.domain.Game
import com.gameshelf.domain.PlayStatus
import com.gameshelf.ui.common.AppPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.UUID

/**
 * Orquesta la biblioteca: la sincronizacion con Steam y lo que se ve en
 * pantalla.
 *
 * Es donde mas se separa el puerto de la version de iOS, y por una razon
 * concreta. Alla el ViewModel **no** entregaba los juegos: de eso se encargaba
 * `@Query`, que refresca la vista sola cuando cambia SwiftData. Compose no
 * tiene ese equivalente, asi que la lista sale de un `Flow` de Room expuesto
 * aca. El resto del reparto de responsabilidades se mantiene: lo que puede
 * fallar (llamar al servicio, guardar, traducir errores) sigue estando en esta
 * clase y sigue siendo lo que se prueba.
 *
 * Ver `docs/decisiones/001-arquitectura.md`.
 */
class LibraryViewModel(
  private val service: SteamServicing,
  private val store: GameStore,
  private val prefs: AppPreferences,
  private val names: FallbackNames = FallbackNames.Default,
) : ViewModel() {

  /**
   * En que punto esta la sincronizacion.
   *
   * Transiciones posibles:
   * ```
   * Idle ─────────► Syncing ──┬──► Succeeded ──► Syncing ──► ...
   *                           └──► Failed ─────► Syncing ──► ...
   * ```
   * Nunca se pasa de `Syncing` a `Syncing`: las llamadas mientras hay una en
   * curso se ignoran.
   */
  sealed interface State {
    /** Todavia no se ha intentado nada en esta sesion. */
    data object Idle : State

    /** Pidiendo datos a Steam. */
    data object Syncing : State

    /** Termino bien. */
    data class Succeeded(val created: Int, val updated: Int) : State

    /** Fallo. El error se traduce a texto en la vista. */
    data class Failed(val error: Throwable) : State

    val isSyncing: Boolean get() = this is Syncing

    /** Si ya se intento sincronizar al menos una vez en esta sesion. */
    val hasAttempted: Boolean get() = this !is Idle
  }

  private val _state = MutableStateFlow<State>(State.Idle)
  val state: StateFlow<State> = _state.asStateFlow()

  /**
   * Cuando termino la ultima sincronizacion correcta.
   *
   * Se guarda entre sesiones para poder decirle al usuario que tan viejos son
   * los datos que esta viendo cuando la red falla.
   */
  private val _lastSyncedAt = MutableStateFlow(prefs.librarySyncedAt)
  val lastSyncedAt: StateFlow<Instant?> = _lastSyncedAt.asStateFlow()

  /**
   * Si la ultima sincronizacion correcta no trajo ningun juego.
   *
   * Sirve para distinguir "todavia no has sincronizado" de "sincronizamos y
   * Steam no devolvio nada", que para el usuario son problemas distintos.
   */
  private val _lastSyncReturnedNoGames = MutableStateFlow(false)
  val lastSyncReturnedNoGames: StateFlow<Boolean> = _lastSyncReturnedNoGames.asStateFlow()

  // --- Lo que se ve --------------------------------------------------------

  private val _query = MutableStateFlow(GameQuery(sort = prefs.librarySortOrder))
  val query: StateFlow<GameQuery> = _query.asStateFlow()

  /** Todos los juegos guardados, tal cual salen de la base. */
  val allGames: StateFlow<List<Game>> = store.observeGames()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  /** Los juegos ya buscados, filtrados y ordenados. */
  val games: StateFlow<List<Game>> = combine(allGames, _query) { juegos, consulta ->
    consulta.apply(juegos)
  }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  val collections = store.observeCollections()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  val tags = store.observeTags()
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  fun setSearch(texto: String) {
    _query.value = _query.value.copy(search = texto)
  }

  fun setFilter(filtro: GameFilter) {
    _query.value = _query.value.copy(filter = filtro)
  }

  fun setSort(orden: GameSortOrder) {
    prefs.librarySortOrder = orden
    _query.value = _query.value.copy(sort = orden)
  }

  fun clearFilters() {
    _query.value = _query.value.copy(filter = GameFilter.NONE)
  }

  // --- Sincronizacion ------------------------------------------------------

  /**
   * Sincroniza solo si nunca se ha hecho.
   *
   * Se llama al abrir la pantalla: la primera vez trae la biblioteca sola, y
   * despues no molesta en cada arranque. Para forzarla esta [sync].
   */
  fun syncIfNeeded() {
    if (_lastSyncedAt.value != null || _state.value.hasAttempted) return
    sync()
  }

  /**
   * Trae la biblioteca de Steam y la guarda.
   *
   * No propaga errores: los guarda en [state] para que la vista los muestre.
   * Un fallo **no borra** lo que ya estaba guardado.
   */
  fun sync() {
    if (_state.value.isSyncing) return

    _state.value = State.Syncing

    viewModelScope.launch {
      try {
        val juegos = service.fetchOwnedGames()
        val resultado = SteamLibrarySyncer.sync(juegos, store, names)

        _lastSyncReturnedNoGames.value = juegos.isEmpty()
        registrarSincronizacion(Instant.now())
        _state.value = State.Succeeded(resultado.created, resultado.updated)
      } catch (e: Throwable) {
        _state.value = State.Failed(e)
      }
    }
  }

  // --- Clasificacion en lote -----------------------------------------------

  /**
   * Marca como pendientes los juegos con 0 horas que el usuario no clasifico.
   *
   * @return Cuantos se cambiaron.
   */
  suspend fun markCandidatesAsBacklog(): Int {
    val candidatos = LibraryInsights.candidatesForBacklog(allGames.value)
    candidatos.forEach { store.setStatus(it.id, PlayStatus.BACKLOG) }
    return candidatos.size
  }

  fun setStatus(gameId: UUID, status: PlayStatus) {
    viewModelScope.launch { store.setStatus(gameId, status) }
  }

  private fun registrarSincronizacion(fecha: Instant) {
    _lastSyncedAt.value = fecha
    prefs.librarySyncedAt = fecha
  }
}

/**
 * Servicio que solo sabe fallar, con el motivo original.
 *
 * Se usa cuando no se pudieron leer las credenciales: asi la app arranca y
 * explica el problema en vez de caerse.
 */
class UnavailableSteamService(private val error: Throwable) : SteamServicing {
  override suspend fun fetchOwnedGames(): List<SteamGameDTO> = throw error
}
