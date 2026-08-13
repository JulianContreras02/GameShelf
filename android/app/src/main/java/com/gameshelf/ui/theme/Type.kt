package com.gameshelf.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * La escala tipografica de la app.
 *
 * Parte de la de Material 3 y la ajusta en dos sitios donde la de serie se
 * queda corta para una app que es, sobre todo, listas de cosas con nombre:
 *
 * - **Los titulares van mas apretados.** El interlineado y el espaciado entre
 *   letras de serie estan pensados para titulares de una linea; los nombres de
 *   juegos ocupan dos a menudo, y con los valores por defecto las dos lineas se
 *   separan tanto que dejan de leerse como una sola cosa.
 * - **Las etiquetas van mas marcadas.** Se usan en los chips de estado y de
 *   tienda, que compiten con la caratula por la atencion. Con el peso de serie
 *   se pierden.
 *
 * No se usa una fuente propia: la del sistema es la que el usuario ya eligio
 * (incluidos sus ajustes de accesibilidad) y meter un archivo de fuente solo
 * para diferenciarse cambiaria eso sin darle nada a cambio.
 */
private val Familia = FontFamily.SansSerif

val GameShelfTypography = Typography(
  displayLarge = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Normal,
    fontSize = 57.sp,
    lineHeight = 64.sp,
    letterSpacing = (-0.25).sp,
  ),
  displayMedium = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Normal,
    fontSize = 45.sp,
    lineHeight = 52.sp,
  ),
  displaySmall = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Normal,
    fontSize = 36.sp,
    lineHeight = 44.sp,
  ),

  // Los titulares de pantalla. Van en semibold: la barra superior grande es lo
  // primero que se mira al entrar y con peso normal se lee floja.
  headlineLarge = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.SemiBold,
    fontSize = 32.sp,
    lineHeight = 40.sp,
    letterSpacing = (-0.5).sp,
  ),
  headlineMedium = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.SemiBold,
    fontSize = 28.sp,
    lineHeight = 36.sp,
    letterSpacing = (-0.25).sp,
  ),
  headlineSmall = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.SemiBold,
    fontSize = 24.sp,
    lineHeight = 32.sp,
  ),

  titleLarge = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.SemiBold,
    fontSize = 22.sp,
    lineHeight = 28.sp,
  ),
  titleMedium = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.SemiBold,
    fontSize = 16.sp,
    lineHeight = 24.sp,
    letterSpacing = 0.1.sp,
  ),
  titleSmall = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Medium,
    fontSize = 14.sp,
    lineHeight = 20.sp,
    letterSpacing = 0.1.sp,
  ),

  bodyLarge = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Normal,
    fontSize = 16.sp,
    lineHeight = 22.sp,
    letterSpacing = 0.15.sp,
  ),
  bodyMedium = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Normal,
    fontSize = 14.sp,
    lineHeight = 20.sp,
    letterSpacing = 0.25.sp,
  ),
  bodySmall = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Normal,
    fontSize = 12.sp,
    lineHeight = 16.sp,
    letterSpacing = 0.4.sp,
  ),

  // Las etiquetas de los chips. Medium en vez de Normal, y algo mas de
  // espaciado, para que un chip de dos palabras se lea de un vistazo.
  labelLarge = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Medium,
    fontSize = 14.sp,
    lineHeight = 20.sp,
    letterSpacing = 0.1.sp,
  ),
  labelMedium = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Medium,
    fontSize = 12.sp,
    lineHeight = 16.sp,
    letterSpacing = 0.5.sp,
  ),
  labelSmall = TextStyle(
    fontFamily = Familia,
    fontWeight = FontWeight.Medium,
    fontSize = 11.sp,
    lineHeight = 16.sp,
    letterSpacing = 0.5.sp,
  ),
)
