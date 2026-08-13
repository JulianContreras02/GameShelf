package com.gameshelf.ui.accounts

import androidx.lifecycle.ViewModel
import com.gameshelf.data.secrets.ITADKeyStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * La clave de IsThereAnyDeal, que solo habilita los precios.
 *
 * Es mucho mas simple que las otras tres cuentas y no comparte su ViewModel a
 * proposito: no hay nada que comprobar contra un servidor al guardarla. ITAD no
 * tiene un endpoint que diga "esta clave sirve", asi que verificarla obligaria
 * a consultar precios de un juego cualquiera solo para ver si responde. Se
 * guarda tal cual, y si no sirve la lista de deseos se muestra sin precios,
 * que es como se ve tambien cuando no hay clave.
 */
class ITADKeyViewModel(
  private val store: ITADKeyStore,
) : ViewModel() {

  /** Si hay una clave guardada. Nunca se expone la clave en si. */
  private val _hasKey = MutableStateFlow(false)
  val hasKey: StateFlow<Boolean> = _hasKey.asStateFlow()

  init {
    _hasKey.value = !store.key().isNullOrBlank()
  }

  fun save(clave: String) {
    if (clave.isBlank()) return
    store.save(clave)
    _hasKey.value = true
  }

  fun clear() {
    store.clear()
    _hasKey.value = false
  }
}
