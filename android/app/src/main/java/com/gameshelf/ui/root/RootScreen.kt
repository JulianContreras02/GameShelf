package com.gameshelf.ui.root

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.gameshelf.R
import com.gameshelf.ui.accounts.EpicConnectScreen
import com.gameshelf.ui.accounts.PSNConnectScreen
import com.gameshelf.ui.collections.CollectionDetailScreen
import com.gameshelf.ui.collections.CollectionEditorScreen
import com.gameshelf.ui.collections.CollectionsScreen
import com.gameshelf.ui.detail.GameDetailScreen
import com.gameshelf.ui.library.LibraryInsightsScreen
import com.gameshelf.ui.library.LibraryScreen
import com.gameshelf.ui.progress.GameProgressScreen
import com.gameshelf.ui.settings.SettingsScreen
import com.gameshelf.ui.wishlist.WishlistScreen
import java.util.UUID

/**
 * Contenedor principal con las secciones de la app.
 *
 * Se separa de la biblioteca para que agregar secciones (ajustes,
 * estadisticas, lista de deseos) no obligue a tocarla, igual que en iOS.
 *
 * Cada pestana tiene su propio grafo de navegacion anidado: entrar en la ficha
 * de un juego desde la biblioteca y volver no debe perder lo que estabas
 * viendo en colecciones.
 */
@Composable
fun RootScreen() {
  val nav = rememberNavController()
  val entradaActual by nav.currentBackStackEntryAsState()
  val rutaActual = entradaActual?.destination?.route

  Scaffold(
    bottomBar = {
      NavigationBar {
        Seccion.entries.forEach { seccion ->
          NavigationBarItem(
            // Se compara por prefijo y no por igualdad: dentro de la ficha de
            // un juego la pestana de biblioteca tiene que seguir marcada.
            selected = rutaActual?.startsWith(seccion.raizDeRuta) == true,
            onClick = { irA(nav, seccion) },
            icon = { Icon(seccion.icono, contentDescription = null) },
            label = { Text(stringResource(seccion.tituloRes)) },
          )
        }
      }
    },
  ) { relleno ->
    NavHost(
      navController = nav,
      startDestination = Rutas.BIBLIOTECA,
      modifier = Modifier.padding(relleno),
    ) {
      grafoDeBiblioteca(nav)
      grafoDeProgreso(nav)
      grafoDeColecciones(nav)
      grafoDeAjustes(nav)
    }
  }
}

/** Las secciones de la barra inferior. */
private enum class Seccion(
  val raizDeRuta: String,
  val tituloRes: Int,
  val icono: ImageVector,
) {
  BIBLIOTECA(Rutas.BIBLIOTECA, R.string.tab_library, Icons.Default.GridView),
  PROGRESO(Rutas.PROGRESO, R.string.tab_progress, Icons.Default.BarChart),
  COLECCIONES(Rutas.COLECCIONES, R.string.tab_collections, Icons.Default.Folder),
  AJUSTES(Rutas.AJUSTES, R.string.tab_settings, Icons.Default.Settings),
}

/**
 * Cambia de pestana.
 *
 * Se vuelve al inicio del grafo y se guarda el estado de la pestana que se
 * deja, para que al regresar siga donde estaba. `launchSingleTop` evita apilar
 * la misma pantalla al tocar dos veces la pestana ya activa.
 */
private fun irA(nav: NavHostController, seccion: Seccion) {
  nav.navigate(seccion.raizDeRuta) {
    popUpTo(nav.graph.startDestinationId) { saveState = true }
    launchSingleTop = true
    restoreState = true
  }
}

/** Las rutas de la app, en un solo sitio para que no se escriban a mano. */
object Rutas {
  const val BIBLIOTECA = "biblioteca"
  const val PROGRESO = "progreso"
  const val COLECCIONES = "colecciones"
  const val AJUSTES = "ajustes"

  const val DETALLE = "juego"
  const val INSIGHTS = "insights"
  const val DESEOS = "deseos"
  const val COLECCION = "coleccion"
  const val EDITOR_COLECCION = "editor-coleccion"
  const val CONECTAR_PSN = "conectar-psn"
  const val CONECTAR_EPIC = "conectar-epic"

  fun detalle(id: UUID) = "$DETALLE/$id"
  fun coleccion(id: UUID) = "$COLECCION/$id"

  /** El editor sirve para crear y para editar; sin id, crea. */
  fun editorDeColeccion(id: UUID? = null) =
    if (id == null) "$EDITOR_COLECCION/nueva" else "$EDITOR_COLECCION/$id"
}

private fun NavGraphBuilder.grafoDeBiblioteca(nav: NavHostController) {
  composable(Rutas.BIBLIOTECA) {
    LibraryScreen(
      alAbrirJuego = { nav.navigate(Rutas.detalle(it)) },
      alAbrirInsights = { nav.navigate(Rutas.INSIGHTS) },
      alAbrirDeseos = { nav.navigate(Rutas.DESEOS) },
    )
  }
  destinosCompartidos(nav)
}

private fun NavGraphBuilder.grafoDeProgreso(nav: NavHostController) {
  composable(Rutas.PROGRESO) {
    GameProgressScreen(alAbrirJuego = { nav.navigate(Rutas.detalle(it)) })
  }
}

private fun NavGraphBuilder.grafoDeColecciones(nav: NavHostController) {
  composable(Rutas.COLECCIONES) {
    CollectionsScreen(
      alAbrirColeccion = { nav.navigate(Rutas.coleccion(it)) },
      alCrear = { nav.navigate(Rutas.editorDeColeccion()) },
    )
  }

  composable("${Rutas.COLECCION}/{id}") { entrada ->
    val id = entrada.arguments?.getString("id")?.let(UUID::fromString) ?: return@composable
    CollectionDetailScreen(
      collectionId = id,
      alAbrirJuego = { nav.navigate(Rutas.detalle(it)) },
      alEditar = { nav.navigate(Rutas.editorDeColeccion(id)) },
      alVolver = { nav.popBackStack() },
    )
  }

  composable("${Rutas.EDITOR_COLECCION}/{id}") { entrada ->
    val bruto = entrada.arguments?.getString("id")
    val id = if (bruto == "nueva") null else bruto?.let(UUID::fromString)
    CollectionEditorScreen(collectionId = id, alCerrar = { nav.popBackStack() })
  }
}

private fun NavGraphBuilder.grafoDeAjustes(nav: NavHostController) {
  composable(Rutas.AJUSTES) {
    SettingsScreen(
      alConectarPSN = { nav.navigate(Rutas.CONECTAR_PSN) },
      alConectarEpic = { nav.navigate(Rutas.CONECTAR_EPIC) },
      alAbrirDeseos = { nav.navigate(Rutas.DESEOS) },
    )
  }

  composable(Rutas.CONECTAR_PSN) { PSNConnectScreen(alVolver = { nav.popBackStack() }) }
  composable(Rutas.CONECTAR_EPIC) { EpicConnectScreen(alVolver = { nav.popBackStack() }) }
}

/**
 * Pantallas a las que se llega desde mas de una pestana.
 *
 * La ficha de un juego se abre desde la biblioteca, desde progreso, desde una
 * coleccion y desde la lista de deseos: se declara una sola vez.
 */
private fun NavGraphBuilder.destinosCompartidos(nav: NavHostController) {
  composable("${Rutas.DETALLE}/{id}") { entrada ->
    val id = entrada.arguments?.getString("id")?.let(UUID::fromString) ?: return@composable
    GameDetailScreen(gameId = id, alVolver = { nav.popBackStack() })
  }

  composable(Rutas.INSIGHTS) {
    LibraryInsightsScreen(
      alAbrirJuego = { nav.navigate(Rutas.detalle(it)) },
      alVolver = { nav.popBackStack() },
    )
  }

  composable(Rutas.DESEOS) {
    WishlistScreen(
      alAbrirJuego = { nav.navigate(Rutas.detalle(it)) },
      alVolver = { nav.popBackStack() },
    )
  }
}
