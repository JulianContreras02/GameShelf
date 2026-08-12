package com.gameshelf.domain.format

import android.content.Context
import com.gameshelf.R
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Convierte la fecha de la ultima partida en texto para mostrar.
 *
 * Va aparte de las vistas porque decide cosas: cuando decir "hoy", cuando
 * pasar a "hace 3 dias" y cuando mostrar la fecha completa. Eso es logica y
 * lleva pruebas.
 */
object LastPlayedFormatter {

  /**
   * Texto para la ficha de un juego.
   *
   * - `null` da "Nunca"
   * - Hoy o ayer se dicen con palabras
   * - Hasta 30 dias, en dias
   * - Mas atras, la fecha
   *
   * Se compara contra [referencia] y no contra el reloj del sistema: asi la
   * funcion es predecible y se puede probar.
   */
  fun text(
    context: Context,
    date: Instant?,
    referencia: Instant = Instant.now(),
    zone: ZoneId = ZoneId.systemDefault(),
    locale: Locale = Locale.getDefault(),
  ): String {
    if (date == null) return context.getString(R.string.last_played_never)

    // Se comparan dias de calendario, no intervalos de 24 horas: jugar anoche
    // y mirar la ficha esta manana tiene que decir "Ayer", no "Hoy".
    val dias = ChronoUnit.DAYS.between(
      LocalDate.ofInstant(date, zone),
      LocalDate.ofInstant(referencia, zone),
    )

    // Fechas futuras: puede pasar si el reloj del equipo esta desajustado.
    // Mejor decir "Hoy" que "hace -2 dias".
    if (dias <= 0L) return context.getString(R.string.last_played_today)
    if (dias == 1L) return context.getString(R.string.last_played_yesterday)

    if (dias <= 30L) {
      return context.resources.getQuantityString(
        R.plurals.last_played_days_ago, dias.toInt(), dias.toInt(),
      )
    }

    val formatter = DateTimeFormatter
      .ofLocalizedDate(FormatStyle.MEDIUM)
      .withLocale(locale)
      .withZone(zone)
    return formatter.format(date)
  }
}
