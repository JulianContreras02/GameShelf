package com.gameshelf.ui.wishlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.data.itad.GamePrices
import com.gameshelf.data.itad.ITADServicing
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.steam.SteamWishlistGame
import com.gameshelf.data.steam.SteamWishlistServicing
import com.gameshelf.data.sync.SteamWishlistSyncer
import com.gameshelf.domain.Game
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.normalizedForSearch
import com.gameshelf.ui.common.AppPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Orquesta la lista de deseos: sincronizarla con Steam, consultar precios y
 * agregar juegos a mano.
 *
 * Sigue la misma idea que `LibraryViewModel`, incluida la razon por la que
 * aca si expone los juegos y en iOS no.
 */
class WishlistViewModel(
  private val service: SteamWishlistServicing,
  private val store: GameStore,
  private val prefs: AppPreferences,
  private val priceService: ITADServicing? = null,
) : ViewModel() {

  /** En que punto esta la sincronizacion. */
  sealed interface State {
    data object Idle : State
    data object Syncing : State

    /** Termino bien. */
    data class Succeeded(val created: Int, val updated: Int, val removed: Int) : State

    /** Fallo. El error se traduce a texto en la vista. */
    data class Failed(val error: Throwable) : State

    val isSyncing: Boolean get() = this is Syncing
    val hasAttempted: Boolean get() = this !is Idle
  }

  /**
   * En que punto esta la consulta de precios.
   *
   * Va aparte del estado de la sincronizacion porque son dos servicios
   * distintos: que IsThereAnyDeal falle no puede impedir ver la lista, que es
   * lo que de verdad importa en esta pantalla.
   */
  sealed interface PricesState {
    data object Idle : PricesState
    data object Loading : PricesState
    data object Loaded : PricesState
    data class Failed(val error: Throwable) : PricesState

    val isLoading: Boolean get() = this is Loading
  }

  private val _state = MutableStateFlow<State>(State.Idle)
  val state: StateFlow<State> = _state.asStateFlow()

  private val _pricesState = MutableStateFlow<PricesState>(PricesState.Idle)
  val pricesState: StateFlow<PricesState> = _pricesState.asStateFlow()

  /**
   * Precios ya consultados, indexados por appid de Steam.
   *
   * Se guardan solo en memoria, no en la base: un precio de hace una semana es
   * peor que no mostrar precio, porque invita a comprar por un descuento que
   * ya se acabo.
   */
  private val _prices = MutableStateFlow<Map<Int, GamePrices>>(emptyMap())
  val prices: StateFlow<Map<Int, GamePrices>> = _prices.asStateFlow()

  private val _lastSyncedAt = MutableStateFlow(prefs.wishlistSyncedAt)
  val lastSyncedAt: StateFlow<Instant?> = _lastSyncedAt.asStateFlow()

  /**
   * Si la ultima sincronizacion correcta no trajo ningun juego.
   *
   * Steam responde igual cuando la lista esta vacia y cuando es privada, asi
   * que esto no significa "es privada": significa "no vino nada", y la vista
   * explica las dos posibilidades.
   */
  private val _lastSyncReturnedNoGames = MutableStateFlow(false)
  val lastSyncReturnedNoGames: StateFlow<Boolean> = _lastSyncReturnedNoGames.asStateFlow()

  private val _sortOrder = MutableStateFlow(prefs.wishlistSortOrder)
  val sortOrder: StateFlow<WishlistSortOrder> = _sortOrder.asStateFlow()

  /**
   * Los juegos de la lista de deseos.
   *
   * Entran por dos caminos: el estado que puso el usuario y la marca que trae
   * la tienda. Son cosas distintas a proposito (ver `StoreEntry.wishlistedAt`)
   * y la pantalla ensena la union de las dos.
   */
  private val wishlistGames: StateFlow<List<Game>> = store.observeGames()
    .map { juegos ->
      juegos.filter { it.status == PlayStatus.WISHLIST || it.isWishlistedInStore }
    }
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  /** Ya ordenados con el criterio elegido. */
  val games: StateFlow<List<Game>> =
    combine(wishlistGames, _sortOrder, _prices) { juegos, orden, precios ->
      orden.sort(juegos, precios)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

  fun setSortOrder(orden: WishlistSortOrder) {
    prefs.wishlistSortOrder = orden
    _sortOrder.value = orden
  }

  // --- Precios -------------------------------------------------------------

  /**
   * Consulta los precios de los juegos que vengan de Steam.
   *
   * No propaga errores: los deja en [pricesState]. Si falla, la lista se
   * muestra igual, solo que sin precios.
   */
  fun loadPrices(juegos: List<Game> = games.value) {
    val servicio = priceService ?: return
    if (_pricesState.value.isLoading) return

    val appIDs = juegos.mapNotNull { it.steamAppID }
    if (appIDs.isEmpty()) {
      _pricesState.value = PricesState.Loaded
      return
    }

    _pricesState.value = PricesState.Loading

    viewModelScope.launch {
      try {
        _prices.value = servicio.prices(appIDs)
        _pricesState.value = PricesState.Loaded
      } catch (e: Throwable) {
        _pricesState.value = PricesState.Failed(e)
      }
    }
  }

  /** El precio de un juego, si ya se consulto. */
  fun prices(juego: Game): GamePrices? = juego.steamAppID?.let { _prices.value[it] }

  /** Cuantos de los juegos dados estan en su minimo historico. */
  fun countAtHistoricalLow(juegos: List<Game>): Int =
    juegos.count { prices(it)?.isAtHistoricalLow == true }

  // --- Sincronizacion ------------------------------------------------------

  /**
   * Trae la lista de deseos de Steam y la guarda.
   *
   * No propaga errores: los deja en [state]. Un fallo **no borra** lo que ya
   * estaba guardado.
   */
  fun sync() {
    if (_state.value.isSyncing) return

    _state.value = State.Syncing

    viewModelScope.launch {
      try {
        val juegos = service.fetchWishlist()

        // Si no vino nada, no se quita nada: puede que la lista sea privada, y
        // vaciar la wishlist del usuario por una respuesta ambigua seria el
        // peor de los errores posibles.
        val resultado = SteamWishlistSyncer.sync(
          juegos,
          store,
          allowRemovals = juegos.isNotEmpty(),
        )

        _lastSyncReturnedNoGames.value = juegos.isEmpty()
        _lastSyncedAt.value = Instant.now()
        prefs.wishlistSyncedAt = _lastSyncedAt.value

        _state.value = State.Succeeded(resultado.created, resultado.updated, resultado.removed)
      } catch (e: Throwable) {
        _state.value = State.Failed(e)
      }
    }
  }

  // --- Agregar a mano ------------------------------------------------------

  /** Por que no se pudo agregar un juego a mano. */
  sealed class ValidationError : Exception() {
    data object EmptyName : ValidationError()
    data class DuplicateName(val nombre: String) : ValidationError()
  }

  /**
   * Agrega un juego a la lista de deseos sin pasar por Steam.
   *
   * Es el respaldo para cuando el endpoint de wishlist se rompa, y tambien
   * sirve para juegos que no estan en Steam.
   *
   * @return El juego creado.
   * @throws ValidationError si el nombre esta vacio o repetido.
   */
  suspend fun addManually(name: String): Game {
    val limpio = name.trim()
    if (limpio.isEmpty()) throw ValidationError.EmptyName

    // La comparacion ignora mayusculas y tildes, la misma regla que usan la
    // busqueda y las etiquetas: agregar "elden ring" teniendo "Elden Ring" no
    // deberia crear un segundo juego.
    val buscado = limpio.normalizedForSearch
    store.allGames().firstOrNull { it.name.normalizedForSearch == buscado }?.let {
      throw ValidationError.DuplicateName(it.name)
    }

    val juego = Game(name = limpio, status = PlayStatus.WISHLIST)
    store.save(juego)
    return juego
  }

  /**
   * Borra un juego agregado a mano.
   *
   * No hace nada con los que vienen de una tienda: ver [canDelete].
   */
  fun delete(juego: Game) {
    if (!canDelete(juego)) return
    viewModelScope.launch { store.delete(juego.id) }
  }

  companion object {
    /**
     * Si un juego se puede quitar de la lista desde la app.
     *
     * Solo los que agregaste a mano. Los que vienen de Steam se quitan en
     * Steam: borrarlos aca no serviria de nada porque la siguiente
     * sincronizacion los traeria de vuelta, y prometer una accion que se
     * deshace sola es peor que no ofrecerla.
     */
    fun canDelete(juego: Game): Boolean = juego.storeEntries.isEmpty()
  }
}

/**
 * Servicio que solo sabe fallar, con el motivo original.
 *
 * Se usa cuando no se pudo leer el SteamID: asi la pantalla abre y explica el
 * problema en vez de caerse.
 */
class UnavailableWishlistService(private val error: Throwable) : SteamWishlistServicing {
  override suspend fun fetchWishlist(): List<SteamWishlistGame> = throw error
}
