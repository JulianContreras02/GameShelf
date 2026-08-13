package com.gameshelf.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

/**
 * La paleta propia de GameShelf.
 *
 * Solo se usa donde el sistema **no** ofrece color dinamico, o sea en Android
 * 11 y anteriores. Donde si lo ofrece, gana el del usuario: es su fondo de
 * pantalla y sus ajustes de contraste, y sustituirlos por una paleta nuestra
 * seria decidir por el.
 *
 * Antes ese caso caia en `lightColorScheme()` y `darkColorScheme()` sin
 * argumentos, que son el morado de muestra de Material. Funcionaba, pero hacia
 * que la app se viera como una plantilla sin terminar en los telefonos que
 * justamente no pueden personalizarla.
 *
 * Los tonos salen de un indigo como color base. Estan escritos a mano en vez de
 * generados en tiempo de ejecucion porque generar una paleta necesita la
 * libreria de armonizacion, y para dos esquemas fijos es mas dependencia que
 * beneficio.
 */
val EsquemaClaro = lightColorScheme(
  primary = Color(0xFF4A55C7),
  onPrimary = Color(0xFFFFFFFF),
  primaryContainer = Color(0xFFDFE0FF),
  onPrimaryContainer = Color(0xFF00105C),

  secondary = Color(0xFF5B5D72),
  onSecondary = Color(0xFFFFFFFF),
  secondaryContainer = Color(0xFFE0E1F9),
  onSecondaryContainer = Color(0xFF181A2C),

  tertiary = Color(0xFF77536D),
  onTertiary = Color(0xFFFFFFFF),
  tertiaryContainer = Color(0xFFFFD7F1),
  onTertiaryContainer = Color(0xFF2D1228),

  error = Color(0xFFBA1A1A),
  onError = Color(0xFFFFFFFF),
  errorContainer = Color(0xFFFFDAD6),
  onErrorContainer = Color(0xFF410002),

  background = Color(0xFFFBF8FF),
  onBackground = Color(0xFF1B1B21),
  surface = Color(0xFFFBF8FF),
  onSurface = Color(0xFF1B1B21),
  surfaceVariant = Color(0xFFE3E1EC),
  onSurfaceVariant = Color(0xFF46464F),

  // Los niveles de contenedor son los que dan la profundidad de las listas sin
  // usar sombras. Material 3 los prefiere a la elevacion justamente porque una
  // sombra sobre fondo oscuro no se ve.
  surfaceContainerLowest = Color(0xFFFFFFFF),
  surfaceContainerLow = Color(0xFFF5F2FA),
  surfaceContainer = Color(0xFFEFEDF4),
  surfaceContainerHigh = Color(0xFFEAE7EF),
  surfaceContainerHighest = Color(0xFFE4E1E9),

  outline = Color(0xFF777680),
  outlineVariant = Color(0xFFC7C5D0),
  inverseSurface = Color(0xFF303036),
  inverseOnSurface = Color(0xFFF3EFF7),
  inversePrimary = Color(0xFFBEC2FF),
  scrim = Color(0xFF000000),
)

val EsquemaOscuro = darkColorScheme(
  primary = Color(0xFFBEC2FF),
  onPrimary = Color(0xFF1B2597),
  primaryContainer = Color(0xFF333CAF),
  onPrimaryContainer = Color(0xFFDFE0FF),

  secondary = Color(0xFFC4C5DD),
  onSecondary = Color(0xFF2D2F42),
  secondaryContainer = Color(0xFF434559),
  onSecondaryContainer = Color(0xFFE0E1F9),

  tertiary = Color(0xFFE6BAD7),
  onTertiary = Color(0xFF44263D),
  tertiaryContainer = Color(0xFF5D3C55),
  onTertiaryContainer = Color(0xFFFFD7F1),

  error = Color(0xFFFFB4AB),
  onError = Color(0xFF690005),
  errorContainer = Color(0xFF93000A),
  onErrorContainer = Color(0xFFFFDAD6),

  background = Color(0xFF131318),
  onBackground = Color(0xFFE4E1E9),
  surface = Color(0xFF131318),
  onSurface = Color(0xFFE4E1E9),
  surfaceVariant = Color(0xFF46464F),
  onSurfaceVariant = Color(0xFFC7C5D0),

  surfaceContainerLowest = Color(0xFF0E0E13),
  surfaceContainerLow = Color(0xFF1B1B21),
  surfaceContainer = Color(0xFF1F1F25),
  surfaceContainerHigh = Color(0xFF2A2930),
  surfaceContainerHighest = Color(0xFF35343B),

  outline = Color(0xFF91909A),
  outlineVariant = Color(0xFF46464F),
  inverseSurface = Color(0xFFE4E1E9),
  inverseOnSurface = Color(0xFF303036),
  inversePrimary = Color(0xFF4A55C7),
  scrim = Color(0xFF000000),
)
