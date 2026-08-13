package com.gameshelf.ui.accounts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.secrets.SteamCredentialsStore
import com.gameshelf.data.steam.FallbackNames
import com.gameshelf.data.steam.SteamAuthError
import com.gameshelf.data.steam.SteamAuthService
import com.gameshelf.data.steam.SteamAuthenticating
import com.gameshelf.data.steam.SteamServicing
import com.gameshelf.data.sync.SteamLibrarySyncer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * La conexion con la cuenta de Steam: conectar, desconectar y traer la
 * biblioteca.
 *
 * Es el tercer hermano de [PSNAccountViewModel] y [EpicAccountViewModel], con
 * una diferencia que se nota en lo que **no** tiene: no hay renovacion de
 * tokens ni fecha de reconexion, porque la API key de Steam no caduca. Lo que
 * si comparte es lo importante: las credenciales se guardan cifradas y la
 * pantalla no las vuelve a mostrar.
 */
class SteamAccountViewModel(
  private val auth: SteamAuthenticating = SteamAuthService(),
  private val credentials: SteamCredentialsStore,
  private val library: SteamServicing,
  private val store: GameStore,
  private val names: FallbackNames = FallbackNames.Default,
) : ViewModel() {

  /** En que punto esta la conexion. */
  sealed interface State {
    data object Desconectado : State
    data object Trabajando : State
    data object Conectado : State

    /** Fallo al conectar: clave mala, perfil que no existe o red. */
    data class Fallo(val error: Throwable) : State

    val isWorking: Boolean get() = this is Trabajando
    val isConnected: Boolean get() = this is Conectado
  }

  private val _state = MutableStateFlow<State>(State.Desconectado)
  val state: StateFlow<State> = _state.asStateFlow()

  /** Nombre visible de la cuenta conectada. Solo para mostrarlo. */
  private val _personaName = MutableStateFlow<String?>(null)
  val personaName: StateFlow<String?> = _personaName.asStateFlow()

  init {
    cargarEstadoGuardado()
  }

  // --- Conectar ------------------------------------------------------------

  /**
   * Comprueba lo que el usuario escribio y, si sirve, lo guarda.
   *
   * No se guarda nada antes de que Steam confirme que la clave y el perfil son
   * validos: dejar credenciales rotas guardadas haria que la app pareciera
   * conectada y fallara despues, al sincronizar, lejos de donde esta el error.
   */
  fun connect(apiKey: String, perfil: String) {
    if (_state.value.isWorking) return
    _state.value = State.Trabajando

    viewModelScope.launch {
      try {
        val credenciales = auth.signIn(apiKey, perfil)
        credentials.save(credenciales)
        _personaName.value = credenciales.personaName
        _state.value = State.Conectado
      } catch (e: Throwable) {
        _state.value = State.Fallo(e)
      }
    }
  }

  fun disconnect() {
    credentials.clear()
    _personaName.value = null
    _state.value = State.Desconectado
  }

  // --- Biblioteca ----------------------------------------------------------

  sealed interface LibraryState {
    data object Idle : LibraryState
    data object Syncing : LibraryState
    data class Succeeded(val created: Int, val updated: Int) : LibraryState
    data class Failed(val error: Throwable) : LibraryState

    val isSyncing: Boolean get() = this is Syncing
  }

  private val _libraryState = MutableStateFlow<LibraryState>(LibraryState.Idle)
  val libraryState: StateFlow<LibraryState> = _libraryState.asStateFlow()

  /** Trae los juegos de Steam y los guarda. No propaga errores. */
  fun syncLibrary() {
    if (_libraryState.value.isSyncing) return
    _libraryState.value = LibraryState.Syncing

    viewModelScope.launch {
      try {
        val juegos = library.fetchOwnedGames()
        val resultado = SteamLibrarySyncer.sync(juegos, store, names)
        _libraryState.value = LibraryState.Succeeded(resultado.created, resultado.updated)
      } catch (e: Throwable) {
        // Si lo que fallo fue la credencial, la cuenta deja de estar conectada:
        // el usuario pudo revocar la clave desde la web de Steam.
        if (e is SteamAuthError && e.necesitaReconectar) _state.value = State.Fallo(e)
        _libraryState.value = LibraryState.Failed(e)
      }
    }
  }

  // --- Guardado ------------------------------------------------------------

  private fun cargarEstadoGuardado() {
    val guardadas = runCatching { credentials.credentials() }.getOrNull() ?: run {
      _state.value = State.Desconectado
      return
    }

    _personaName.value = guardadas.personaName
    _state.value = State.Conectado
  }
}
