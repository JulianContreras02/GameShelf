package com.gameshelf.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import com.gameshelf.domain.CollectionColor

/**
 * El tema de la app.
 *
 * Usa color dinamico donde el sistema lo ofrece (Android 12 y posteriores),
 * que es el equivalente mas cercano a lo que hacia la version de iOS al apoyarse
 * en los colores del sistema: el resultado se adapta solo a claro y oscuro y
 * respeta los ajustes de contraste del usuario.
 *
 * Donde no lo ofrece cae en la paleta propia de [EsquemaClaro] y
 * [EsquemaOscuro], no en la de muestra de Material.
 */
@Composable
fun GameShelfTheme(
  darkTheme: Boolean = isSystemInDarkTheme(),
  dynamicColor: Boolean = true,
  content: @Composable () -> Unit,
) {
  val context = LocalContext.current

  val colorScheme = when {
    dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
      if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)

    darkTheme -> EsquemaOscuro
    else -> EsquemaClaro
  }

  MaterialTheme(
    colorScheme = colorScheme,
    typography = GameShelfTypography,
    shapes = GameShelfShapes,
    content = content,
  )
}

/**
 * Traduccion del color de dominio al color de pantalla.
 *
 * Vive aparte del modelo para que [CollectionColor] no dependa de Compose:
 * asi se puede probar sin levantar interfaz. Es el mismo reparto que en iOS,
 * donde la extension `CollectionColor+SwiftUI` hacia exactamente esto.
 *
 * Los tonos estan elegidos para leerse sobre fondo claro y oscuro; no se usan
 * los colores puros porque el amarillo y el turquesa saturados desaparecen
 * sobre blanco.
 */
val CollectionColor.composeColor: Color
  get() = when (this) {
    CollectionColor.BLUE -> Color(0xFF1F6FEB)
    CollectionColor.GREEN -> Color(0xFF2DA44E)
    CollectionColor.ORANGE -> Color(0xFFE36209)
    CollectionColor.PINK -> Color(0xFFDB61A2)
    CollectionColor.PURPLE -> Color(0xFF8250DF)
    CollectionColor.RED -> Color(0xFFCF222E)
    CollectionColor.TEAL -> Color(0xFF0F8B8D)
    CollectionColor.YELLOW -> Color(0xFFBF8700)
    CollectionColor.GRAY -> Color(0xFF6E7781)
  }
