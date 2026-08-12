package com.gameshelf.ui.accounts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.OkHttpNetworkClient
import com.gameshelf.data.psn.PSNAuthError
import com.gameshelf.data.psn.PSNAuthService
import com.gameshelf.data.psn.PSNAuthenticating
import com.gameshelf.data.psn.PSNCredentials
import com.gameshelf.data.psn.PSNLibraryService
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.secrets.SecureStoring
import com.gameshelf.data.sync.PSNLibrarySyncer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * La conexion con la cuenta de PlayStation: conectar, renovar y desconectar.
 *
 * Guarda las credenciales cifradas, nunca en las preferencias normales: el
 * token de acceso vale por la cuenta entera de Sony, y un `SharedPreferences`
 * corriente es un XML en claro dentro del contenedor de la app. Es la misma
 * razon por la que en iOS iban al Keychain.
 */
class PSNAccountViewModel(
  private val service: PSNAuthenticating = PSNAuthService(),
  private val secure: SecureStoring,
  private val store: GameStore,
  private val client: HttpClient = OkHttpNetworkClient(),
) : ViewModel() {

  /** En que punto esta la conexion. */
  sealed interface State {
    /** Nunca se ha conectado, o se desconecto. */
    data object Desconectado : State

    /** Canjeando el codigo o renovando. */
    data object Trabajando : State

    /** Conectado y con token vigente. */
    data object Conectado : State

    /** Hay credenciales guardadas pero ya no sirven. */
    data class NecesitaTokenNuevo(val error: Throwable) : State

    /** Fallo por otra cosa, por ejemplo la red. */
    data class Fallo(val error: Throwable) : State

    val isWorking: Boolean get() = this is Trabajando
    val isConnected: Boolean get() = this is Conectado
  }

  private val _state = MutableStateFlow<State>(State.Desconectado)
  val state: StateFlow<State> = _state.asStateFlow()

  /**
   * Cuando caduca el token de acceso actual.
   *
   * Es un dato tecnico: dura una hora y la app lo renueva sola. No es lo que
   * hay que ponerle delante al usuario.
   */
  private val _expiresAt = MutableStateFlow<Instant?>(null)
  val expiresAt: StateFlow<Instant?> = _expiresAt.asStateFlow()

  /**
   * Cuando habra que volver a copiar el codigo, si Sony lo dijo.
   *
   * **Esta si es la fecha que importa.** Hasta entonces no hay que hacer nada.
   */
  private val _reconnectBy = MutableStateFlow<Instant?>(null)
  val reconnectBy: StateFlow<Instant?> = _reconnectBy.asStateFlow()

  init {
    cargarEstadoGuardado()
  }

  // --- Conectar ------------------------------------------------------------

  /**
   * Canjea el codigo que el usuario pego y guarda las credenciales.
   *
   * No propaga errores: los deja en [state] para que la vista los muestre.
   */
  fun connect(npsso: String) {
    if (_state.value.isWorking) return
    _state.value = State.Trabajando

    viewModelScope.launch {
      try {
        guardar(service.signIn(npsso))
        _state.value = State.Conectado
      } catch (e: Throwable) {
        _state.value = estado(e)
      }
    }
  }

  /**
   * Devuelve un token de acceso vigente, renovandolo si hace falta.
   *
   * Es lo que usan las llamadas a la API de PSN. Renueva sola mientras el
   * refresh token siga sirviendo; cuando deja de servir, el estado pasa a
   * [State.NecesitaTokenNuevo] y hay que pedirle al usuario un NPSSO nuevo.
   *
   * @throws PSNAuthError si no hay credenciales o si ya no se pueden renovar.
   */
  suspend fun validAccessToken(ahora: Instant = Instant.now()): String {
    val guardadas = credencialesGuardadas() ?: run {
      _state.value = State.Desconectado
      throw PSNAuthError.SinCredenciales
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

  /** Borra las credenciales guardadas. */
  fun disconnect() {
    listOf(ACCESS_TOKEN, REFRESH_TOKEN, EXPIRES_AT, REFRESH_EXPIRES_AT).forEach(secure::remove)
    _expiresAt.value = null
    _reconnectBy.value = null
    _state.value = State.Desconectado
  }

  // --- Biblioteca ----------------------------------------------------------

  /** En que punto esta la sincronizacion de la biblioteca de PSN. */
  sealed interface LibraryState {
    data object Idle : LibraryState
    data object Syncing : LibraryState
    data class Succeeded(val created: Int, val updated: Int, val merged: Int) : LibraryState
    data class Failed(val error: Throwable) : LibraryState

    val isSyncing: Boolean get() = this is Syncing
  }

  private val _libraryState = MutableStateFlow<LibraryState>(LibraryState.Idle)
  val libraryState: StateFlow<LibraryState> = _libraryState.asStateFlow()

  /**
   * Trae los juegos de PlayStation y los guarda.
   *
   * No propaga errores: los deja en [libraryState]. Si la sesion caduco, el
   * estado de la cuenta pasa a pedir un codigo nuevo, que es lo unico que lo
   * arregla.
   */
  fun syncLibrary() {
    if (_libraryState.value.isSyncing) return
    _libraryState.value = LibraryState.Syncing

    val servicio = PSNLibraryService(client) { validAccessToken() }

    viewModelScope.launch {
      try {
        val juegos = servicio.fetchPlayedGames()
        val resultado = PSNLibrarySyncer.sync(juegos, store)
        _libraryState.value = LibraryState.Succeeded(
          resultado.created, resultado.updated, resultado.merged,
        )
      } catch (e: Throwable) {
        if (e is PSNAuthError) _state.value = estado(e)
        _libraryState.value = LibraryState.Failed(e)
      }
    }
  }

  // --- Guardado ------------------------------------------------------------

  /** Lee lo guardado al arrancar, para saber si mostrar "conectado". */
  private fun cargarEstadoGuardado() {
    val credenciales = runCatching { credencialesGuardadas() }.getOrNull() ?: run {
      _state.value = State.Desconectado
      return
    }

    _expiresAt.value = credenciales.expiresAt
    _reconnectBy.value = credenciales.refreshExpiresAt

    // Un token de acceso vencido no es problema: se renueva solo en la primera
    // peticion. Se muestra como conectado porque, de cara al usuario, lo esta.
    _state.value = State.Conectado
  }

  private fun credencialesGuardadas(): PSNCredentials? {
    val access = secure.string(ACCESS_TOKEN) ?: return null
    val refresh = secure.string(REFRESH_TOKEN) ?: return null
    val vence = secure.string(EXPIRES_AT)?.toLongOrNull() ?: return null

    return PSNCredentials(
      accessToken = access,
      refreshToken = refresh,
      expiresAt = Instant.ofEpochMilli(vence),
      refreshExpiresAt = secure.string(REFRESH_EXPIRES_AT)?.toLongOrNull()
        ?.let(Instant::ofEpochMilli),
    )
  }

  private fun guardar(credenciales: PSNCredentials) {
    secure.set(credenciales.accessToken, ACCESS_TOKEN)
    secure.set(credenciales.refreshToken, REFRESH_TOKEN)
    secure.set(credenciales.expiresAt.toEpochMilli().toString(), EXPIRES_AT)
    _expiresAt.value = credenciales.expiresAt

    // Renovar no siempre trae fecha nueva de refresco: si no viene, se
    // conserva la que ya se conocia en vez de borrarla.
    credenciales.refreshExpiresAt?.let { vence ->
      secure.set(vence.toEpochMilli().toString(), REFRESH_EXPIRES_AT)
      _reconnectBy.value = vence
    }
  }

  /**
   * Traduce un error al estado que corresponde.
   *
   * La distincion importa: si hace falta un token nuevo, la pantalla tiene que
   * mostrar las instrucciones otra vez; si fue la red, basta con reintentar.
   */
  private fun estado(error: Throwable): State = when {
    error is PSNAuthError && error.necesitaTokenNuevo -> State.NecesitaTokenNuevo(error)
    else -> State.Fallo(error)
  }

  private companion object {
    const val ACCESS_TOKEN = "psn.accessToken"
    const val REFRESH_TOKEN = "psn.refreshToken"
    const val EXPIRES_AT = "psn.expiresAt"
    const val REFRESH_EXPIRES_AT = "psn.refreshExpiresAt"
  }
}
