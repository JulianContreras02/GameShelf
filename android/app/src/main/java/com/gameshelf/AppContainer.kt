package com.gameshelf

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.gameshelf.data.itad.ITADService
import com.gameshelf.data.itad.ITADServicing
import com.gameshelf.data.local.GameShelfDatabase
import com.gameshelf.data.net.OkHttpNetworkClient
import com.gameshelf.data.repository.GameRepository
import com.gameshelf.data.repository.GameStore
import com.gameshelf.data.secrets.ITADKeyStore
import com.gameshelf.data.secrets.SecureStore
import com.gameshelf.data.secrets.SecureStoring
import com.gameshelf.data.secrets.SteamCredentialsStore
import com.gameshelf.data.steam.FallbackNames
import com.gameshelf.data.steam.SteamAuthService
import com.gameshelf.data.steam.SteamService
import com.gameshelf.data.steam.SteamServicing
import com.gameshelf.data.steam.SteamWishlistService
import com.gameshelf.data.steam.SteamWishlistServicing
import com.gameshelf.ui.accounts.EpicAccountViewModel
import com.gameshelf.ui.accounts.ITADKeyViewModel
import com.gameshelf.ui.accounts.PSNAccountViewModel
import com.gameshelf.ui.accounts.SteamAccountViewModel
import com.gameshelf.ui.collections.CollectionsViewModel
import com.gameshelf.ui.common.AppPreferences
import com.gameshelf.ui.detail.GameNotesViewModel
import com.gameshelf.ui.detail.GameStatusViewModel
import com.gameshelf.ui.library.LibraryViewModel
import com.gameshelf.ui.tags.TagsViewModel
import com.gameshelf.ui.wishlist.WishlistViewModel

/**
 * Donde se arma la app: quien depende de quien.
 *
 * Es inyeccion de dependencias a mano, sin libreria. Con este tamano una
 * libreria seria mas ceremonia que ayuda, y asi el grafo entero se lee en una
 * pantalla.
 *
 * El detalle importante son los `runCatching` alrededor de los servicios que
 * necesitan claves: **si falta una clave la app arranca igual** y avisa dentro,
 * en vez de caerse al abrir. Es la misma promesa que hace el README de la
 * version de iOS.
 */
class AppContainer(context: Context) {

  private val app = context.applicationContext

  val database: GameShelfDatabase by lazy { GameShelfDatabase.get(app) }

  val store: GameStore by lazy { GameRepository(database) }

  val preferences: AppPreferences by lazy { AppPreferences.from(app) }

  val secure: SecureStoring by lazy { SecureStore(app) }

  private val httpClient by lazy { OkHttpNetworkClient() }

  /** Los nombres de respaldo si salen de `strings.xml`, no del texto quemado. */
  private val fallbackNames = FallbackNames { appID ->
    app.getString(R.string.steam_fallback_name, appID.toString())
  }

  /** Las credenciales que el usuario dio al conectar cada cuenta. */
  private val steamCredentials by lazy { SteamCredentialsStore(secure) }

  private val itadKey by lazy { ITADKeyStore(secure) }

  /**
   * Los servicios se construyen siempre, incluso sin cuenta conectada.
   *
   * Antes iban envueltos en `runCatching` porque leer una clave que faltaba
   * lanzaba al construirlos, y habia que sustituirlos por un doble que solo
   * sabia fallar. Ya no hace falta: las credenciales se leen en cada llamada,
   * asi que un servicio sin cuenta conectada es un objeto valido que lanza
   * [SteamAuthError.SinCredenciales] cuando se usa.
   *
   * El cambio no es solo de forma. Antes, conectar la cuenta no servia de nada
   * hasta reiniciar la app, porque el servicio ya se habia resuelto al doble
   * inservible.
   */
  private val steamService: SteamServicing by lazy {
    SteamService.live(httpClient, steamCredentials)
  }

  private val wishlistService: SteamWishlistServicing by lazy {
    SteamWishlistService.live(httpClient, steamCredentials)
  }

  /**
   * Los precios son opcionales a proposito: sin la clave de IsThereAnyDeal, la
   * lista de deseos sigue funcionando sin ellos.
   */
  private val itadService: ITADServicing by lazy {
    ITADService.live(httpClient, itadKey)
  }

  /** La fabrica que Compose usa para construir cada ViewModel. */
  val viewModelFactory: ViewModelProvider.Factory = viewModelFactory {
    initializer { LibraryViewModel(steamService, store, preferences, fallbackNames) }
    initializer { WishlistViewModel(wishlistService, store, preferences, itadService) }
    initializer { CollectionsViewModel(store) }
    initializer { TagsViewModel(store) }
    initializer { GameNotesViewModel(store) }
    initializer { GameStatusViewModel(store) }
    initializer { PSNAccountViewModel(secure = secure, store = store, client = httpClient) }
    initializer { EpicAccountViewModel(secure = secure, store = store, client = httpClient) }
    initializer {
      SteamAccountViewModel(
        auth = SteamAuthService(httpClient),
        credentials = steamCredentials,
        library = steamService,
        store = store,
        names = fallbackNames,
      )
    }
    initializer { ITADKeyViewModel(itadKey) }
  }
}

/**
 * Atajo con tipos para pedirle un ViewModel a la fabrica del contenedor.
 *
 * Evita repetir el `viewModel(factory = ...)` en cada pantalla.
 */
inline fun <reified T : ViewModel> AppContainer.factoryFor(): ViewModelProvider.Factory =
  viewModelFactory
