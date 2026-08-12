package com.gameshelf.ui.accounts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.data.epic.EpicAuthError
import com.gameshelf.data.epic.EpicAuthService
import com.gameshelf.data.epic.EpicAuthenticating
import com.gameshelf.data.epic.EpicCredentials
import com.gameshelf.data.epic.EpicLibraryService
import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.OkHttpNetworkClient
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.secrets.SecureStoring
import com.gameshelf.data.sync.EpicLibrarySyncer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * La conexion con la cuenta de Epic: conectar, renovar y desconectar.
 *
 * Es el gemelo de [PSNAccountViewModel] y guarda las credenciales igual de
 * cifradas, por la misma razon: el codigo de Epic da acceso completo a la
 * cuenta, y su propia pagina lo advierte.
 */
class EpicAccountViewModel(
  private val service: EpicAuthenticating = EpicAuthService(),
  private val secure: SecureStoring,
  private val store: GameStore,
  private val client: HttpClient = OkHttpNetworkClient(),
) : ViewModel() {

  /** En que punto esta la conexion. */
  sealed interface State {
    data object Desconectado : State
    data object Trabajando : State
    data object Conectado : State

    /** Hay credenciales guardadas pero ya no sirven. */
    data class NecesitaCodigoNuevo(val error: Throwable) : State

    /** Fallo por otra cosa, por ejemplo la red. */
    data class Fallo(val error: Throwable) : State

    val isWorking: Boolean get() = this is Trabajando
    val isConnected: Boolean get() = this is Conectado
  }

  private val _state = MutableStateFlow<State>(State.Desconectado)
  val state: StateFlow<State> = _state.asStateFlow()

  private val _expiresAt = MutableStateFlow<Instant?>(null)
  val expiresAt: StateFlow<Instant?> = _expiresAt.asStateFlow()

  /** Cuando habra que volver a generar el codigo. Epic si manda este dato. */
  private val _reconnectBy = MutableStateFlow<Instant?>(null)
  val reconnectBy: StateFlow<Instant?> = _reconnectBy.asStateFlow()

  /** Nombre visible de la cuenta conectada. Solo para mostrarlo. */
  private val _displayName = MutableStateFlow<String?>(null)
  val displayName: StateFlow<String?> = _displayName.asStateFlow()

  init {
    cargarEstadoGuardado()
  }

  // --- Conectar ------------------------------------------------------------

  fun connect(authorizationCode: String) {
    if (_state.value.isWorking) return
    _state.value = State.Trabajando

    viewModelScope.launch {
      try {
        guardar(service.signIn(authorizationCode))
        _state.value = State.Conectado
      } catch (e: Throwable) {
        _state.value = estado(e)
      }
    }
  }

  /**
   * Devuelve un token de acceso vigente, renovandolo si hace falta.
   *
   * @throws EpicAuthError si no hay credenciales o si ya no se pueden renovar.
   */
  suspend fun validAccessToken(ahora: Instant = Instant.now()): String {
    val guardadas = credencialesGuardadas() ?: run {
      _state.value = State.Desconectado
      throw EpicAuthError.SinCredenciales
    }

    if (!guardadas.isExpired(ahora)) {
      _state.value = State.Conectado
      return guardadas.accessToken
    }

    try {
      val renovadas = service.refresh(guardadas.refreshToken)
      guardar(renovadas)
      _state.value = State.Conectado
      return renovadas.accessToken
    } catch (e: Throwable) {
      _state.value = estado(e)
      throw e
    }
  }

  fun disconnect() {
    listOf(ACCESS_TOKEN, REFRESH_TOKEN, EXPIRES_AT, REFRESH_EXPIRES_AT, ACCOUNT_ID, DISPLAY_NAME)
      .forEach(secure::remove)
    _expiresAt.value = null
    _reconnectBy.value = null
    _displayName.value = null
    _state.value = State.Desconectado
  }

  // --- Biblioteca ----------------------------------------------------------

  sealed interface LibraryState {
    data object Idle : LibraryState
    data object Syncing : LibraryState
    data class Succeeded(val created: Int, val updated: Int, val merged: Int) : LibraryState
    data class Failed(val error: Throwable) : LibraryState

    val isSyncing: Boolean get() = this is Syncing
  }

  private val _libraryState = MutableStateFlow<LibraryState>(LibraryState.Idle)
  val libraryState: StateFlow<LibraryState> = _libraryState.asStateFlow()

  /** Trae los juegos de Epic y los guarda. No propaga errores. */
  fun syncLibrary() {
    if (_libraryState.value.isSyncing) return
    _libraryState.value = LibraryState.Syncing

    val servicio = EpicLibraryService(
      client = client,
      accessToken = { validAccessToken() },
      accountID = { secure.string(ACCOUNT_ID) },
    )

    viewModelScope.launch {
      try {
        val juegos = servicio.fetchOwnedGames()
        val resultado = EpicLibrarySyncer.sync(juegos, store)
        _libraryState.value = LibraryState.Succeeded(
          resultado.created, resultado.updated, resultado.merged,
        )
      } catch (e: Throwable) {
        if (e is EpicAuthError) _state.value = estado(e)
        _libraryState.value = LibraryState.Failed(e)
      }
    }
  }

  // --- Guardado ------------------------------------------------------------

  private fun cargarEstadoGuardado() {
    val credenciales = runCatching { credencialesGuardadas() }.getOrNull() ?: run {
      _state.value = State.Desconectado
      return
    }

    _expiresAt.value = credenciales.expiresAt
    _reconnectBy.value = credenciales.refreshExpiresAt
    _displayName.value = credenciales.displayName
    _state.value = State.Conectado
  }

  private fun credencialesGuardadas(): EpicCredentials? {
    val access = secure.string(ACCESS_TOKEN) ?: return null
    val refresh = secure.string(REFRESH_TOKEN) ?: return null
    val vence = secure.string(EXPIRES_AT)?.toLongOrNull() ?: return null

    return EpicCredentials(
      accessToken = access,
      refreshToken = refresh,
      expiresAt = Instant.ofEpochMilli(vence),
      refreshExpiresAt = secure.string(REFRESH_EXPIRES_AT)?.toLongOrNull()
        ?.let(Instant::ofEpochMilli),
      accountID = secure.string(ACCOUNT_ID),
      displayName = secure.string(DISPLAY_NAME),
    )
  }

  private fun guardar(credenciales: EpicCredentials) {
    secure.set(credenciales.accessToken, ACCESS_TOKEN)
    secure.set(credenciales.refreshToken, REFRESH_TOKEN)
    secure.set(credenciales.expiresAt.toEpochMilli().toString(), EXPIRES_AT)
    _expiresAt.value = credenciales.expiresAt

    credenciales.refreshExpiresAt?.let { vence ->
      secure.set(vence.toEpochMilli().toString(), REFRESH_EXPIRES_AT)
      _reconnectBy.value = vence
    }

    // El id de cuenta hace falta para pedir los tiempos jugados, y el refresco
    // no siempre lo repite: se conserva el que ya se conocia.
    credenciales.accountID?.let { secure.set(it, ACCOUNT_ID) }
    credenciales.displayName?.let {
      secure.set(it, DISPLAY_NAME)
      _displayName.value = it
    }
  }

  private fun estado(error: Throwable): State = when {
    error is EpicAuthError && error.necesitaCodigoNuevo -> State.NecesitaCodigoNuevo(error)
    else -> State.Fallo(error)
  }

  private companion object {
    const val ACCESS_TOKEN = "epic.accessToken"
    const val REFRESH_TOKEN = "epic.refreshToken"
    const val EXPIRES_AT = "epic.expiresAt"
    const val REFRESH_EXPIRES_AT = "epic.refreshExpiresAt"
    const val ACCOUNT_ID = "epic.accountID"
    const val DISPLAY_NAME = "epic.displayName"
  }
}
