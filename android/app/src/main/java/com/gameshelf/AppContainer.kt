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
import com.gameshelf.data.secrets.SecureStore
import com.gameshelf.data.secrets.SecureStoring
import com.gameshelf.data.steam.FallbackNames
import com.gameshelf.data.steam.SteamService
import com.gameshelf.data.steam.SteamServicing
import com.gameshelf.data.steam.SteamWishlistService
import com.gameshelf.data.steam.SteamWishlistServicing
import com.gameshelf.ui.accounts.EpicAccountViewModel
import com.gameshelf.ui.accounts.PSNAccountViewModel
import com.gameshelf.ui.collections.CollectionsViewModel
import com.gameshelf.ui.common.AppPreferences
import com.gameshelf.ui.detail.GameNotesViewModel
import com.gameshelf.ui.detail.GameStatusViewModel
import com.gameshelf.ui.library.LibraryViewModel
import com.gameshelf.ui.library.UnavailableSteamService
import com.gameshelf.ui.tags.TagsViewModel
import com.gameshelf.ui.wishlist.UnavailableWishlistService
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

  /**
   * Servicio de Steam, o uno que solo sabe fallar con el motivo original.
   *
   * Ese segundo caso es lo que permite que la pantalla explique que falta la
   * clave en vez de quedarse en blanco.
   */
  private val steamService: SteamServicing by lazy {
    runCatching { SteamService.live(httpClient) as SteamServicing }
      .getOrElse { UnavailableSteamService(it) }
  }

  private val wishlistService: SteamWishlistServicing by lazy {
    runCatching { SteamWishlistService.live(httpClient) as SteamWishlistServicing }
      .getOrElse { UnavailableWishlistService(it) }
  }

  /**
   * Los precios son opcionales a proposito: si falta la clave de
   * IsThereAnyDeal, la lista de deseos sigue funcionando sin ellos.
   */
  private val itadService: ITADServicing? by lazy {
    runCatching { ITADService.live(httpClient) }.getOrNull()
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
  }
}

/**
 * Atajo con tipos para pedirle un ViewModel a la fabrica del contenedor.
 *
 * Evita repetir el `viewModel(factory = ...)` en cada pantalla.
 */
inline fun <reified T : ViewModel> AppContainer.factoryFor(): ViewModelProvider.Factory =
  viewModelFactory
