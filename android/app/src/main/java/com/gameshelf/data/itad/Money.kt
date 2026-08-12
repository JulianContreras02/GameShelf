package com.gameshelf.data.itad

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

/**
 * Un importe con su moneda.
 *
 * Lleva la moneda pegada al numero a proposito. La API devuelve la moneda que
 * use la tienda en el pais que se le pida, y no siempre es la que uno
 * esperaria: para Colombia responde en **USD**, porque Steam y las demas
 * tiendas facturan en dolares aca. Guardar solo el numero y asumir la moneda
 * seria mostrar precios equivocados.
 */
data class Money(
  /** El valor, ya en unidades enteras de la moneda (19.99, no 1999). */
  val amount: BigDecimal,
  /** Codigo ISO 4217: "USD", "EUR", "COP"... */
  val currency: String,
) {
  /**
   * El precio como se le muestra al usuario.
   *
   * El simbolo y la separacion de miles salen del idioma del sistema, pero la
   * moneda es la que dijo la tienda: un usuario en Colombia viendo un precio
   * en dolares tiene que ver "US$19.99", no "$19.99" a secas, que se leeria
   * como pesos.
   */
  fun formatted(locale: Locale = Locale.getDefault()): String {
    val formato = NumberFormat.getCurrencyInstance(locale)
    runCatching { Currency.getInstance(currency) }.getOrNull()?.let { formato.currency = it }
    return formato.format(amount)
  }

  /**
   * Cuanto mas barato es este importe que otro, en porcentaje entero.
   *
   * Devuelve `null` si las monedas no coinciden: restar dolares a euros no
   * significa nada, y es mejor no mostrar nada que mostrar un numero falso.
   */
  fun discount(from: Money): Int? {
    if (currency != from.currency || from.amount <= BigDecimal.ZERO) return null
    val proporcion = (from.amount - amount).divide(from.amount, 6, RoundingMode.HALF_UP)
    return (proporcion * BigDecimal(100)).setScale(0, RoundingMode.HALF_UP).toInt()
  }

  companion object {
    /**
     * Crea el importe a partir de los centavos que manda la API.
     *
     * Se usa `amountInt` y no `amount` porque el segundo llega como numero de
     * coma flotante: 19.99 se convierte en 19.989999999999998. Con los
     * centavos la cuenta es exacta.
     */
    fun fromMinorUnits(minorUnits: Int, currency: String): Money =
      Money(BigDecimal(minorUnits).divide(BigDecimal(100)), currency)
  }
}
