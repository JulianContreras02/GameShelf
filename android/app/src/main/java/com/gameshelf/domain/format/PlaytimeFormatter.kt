package com.gameshelf.domain.format

import android.content.Context
import com.gameshelf.R
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.roundToInt

/**
 * Convierte horas jugadas en texto para mostrar.
 *
 * Es logica y no presentacion, por eso vive aparte de las vistas y tiene
 * pruebas: "0.0 h" para un juego sin tocar, o "1404.5 h" sin separador de
 * miles, se leen mal.
 */
object PlaytimeFormatter {

  /**
   * Texto corto para una lista.
   *
   * - Menos de 1 minuto: "Sin jugar"
   * - Menos de 1 hora: "45 min"
   * - Menos de 10 horas: "1,5 h"
   * - Mas: "1.404 h", redondeado y con separador de miles
   */
  fun short(context: Context, hours: Double, locale: Locale = Locale.getDefault()): String {
    val sinJugar = context.getString(R.string.playtime_unplayed)
    if (hours <= 0) return sinJugar

    val minutos = hours * 60
    if (minutos < 1) return sinJugar

    if (hours < 1) {
      return context.getString(R.string.playtime_minutes_short, minutos.roundToInt())
    }

    val formatter = NumberFormat.getNumberInstance(locale).apply {
      // Por defecto se usa redondeo bancario (1404.5 -> 1404, al par mas
      // cercano). Se fija el redondeo normal para que el resultado sea
      // predecible y no dependa del valor que toque. Mismo motivo que en iOS.
      roundingMode = RoundingMode.HALF_UP
      if (hours < 10) {
        minimumFractionDigits = 1
        maximumFractionDigits = 1
      } else {
        maximumFractionDigits = 0
      }
    }

    return context.getString(R.string.playtime_hours_short, formatter.format(hours))
  }

  /**
   * Texto para leer en voz alta con TalkBack.
   *
   * Lo que se lee mal de "1.404 h" es la abreviatura, no el numero: el lector
   * dice "hache". Esto dice "1.404 horas jugadas", que se lee entero.
   *
   * El separador de miles se deja: quitarlo obligaria a pasar el numero como
   * texto, y entonces los plurales del recurso ya no podrian elegir la forma
   * correcta.
   */
  fun accessible(context: Context, hours: Double): String {
    if (hours <= 0) return context.getString(R.string.playtime_unplayed)

    val minutos = (hours * 60).roundToInt()
    if (minutos < 60) {
      return context.resources.getQuantityString(
        R.plurals.playtime_minutes_accessible, minutos, minutos,
      )
    }

    val horasEnteras = hours.roundToInt()
    return context.resources.getQuantityString(
      R.plurals.playtime_hours_accessible, horasEnteras, horasEnteras,
    )
  }
}
