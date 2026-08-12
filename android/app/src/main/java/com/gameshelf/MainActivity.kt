package com.gameshelf

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import com.gameshelf.ui.root.RootScreen
import com.gameshelf.ui.theme.GameShelfTheme

/**
 * El contenedor de la app, disponible para cualquier pantalla.
 *
 * Es el equivalente de lo que en iOS hacia `.modelContainer(...)` sobre la
 * escena: una dependencia que esta en todo el arbol sin tener que pasarla
 * pantalla por pantalla.
 */
val LocalAppContainer = staticCompositionLocalOf<AppContainer> {
  error("Falta LocalAppContainer: envuelve el contenido en un CompositionLocalProvider")
}

class MainActivity : ComponentActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()

    val container = AppContainer(this)

    setContent {
      GameShelfTheme {
        CompositionLocalProvider(LocalAppContainer provides container) {
          RootScreen()
        }
      }
    }
  }
}
