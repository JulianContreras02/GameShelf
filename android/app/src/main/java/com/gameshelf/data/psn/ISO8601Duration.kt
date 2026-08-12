package com.gameshelf.data.psn

/**
 * Lee duraciones en formato ISO 8601, como las que manda PSN.
 *
 * PSN no da el tiempo jugado en minutos sino asi: `PT29H47M44S`. Se parsea a
 * mano y no con `java.time.Duration.parse` porque ese exige la forma `PnDTnHnMnS`
 * con reglas propias y lanza excepcion ante lo que no entiende; aca hace falta
 * distinguir "no se pudo leer" de "cero", y devolver `null` en el primer caso.
 */
object ISO8601Duration {

  /**
   * Convierte una duracion ISO 8601 en segundos.
   *
   * Acepta la forma completa `PnDTnHnMnS` y cualquier subconjunto: `PT0S`,
   * `PT15S`, `PT6M15S`, `PT29H47M44S`, `P2DT3H`.
   *
   * @return `null` si el texto no es una duracion valida. Devolver 0 seria
   *   peor: se confundiria "no se pudo leer" con "no lo has jugado".
   */
  fun seconds(texto: String?): Int? {
    if (texto == null || !texto.startsWith("P")) return null

    // Se parte en la fecha (dias) y la hora (horas, minutos, segundos), que es
    // lo que separa la "T". Sin ella, "M" significaria meses y no minutos.
    val cuerpo = texto.drop(1)
    val corte = cuerpo.indexOf('T')
    val fecha = if (corte >= 0) cuerpo.substring(0, corte) else cuerpo
    val hora = if (corte >= 0) cuerpo.substring(corte + 1) else ""

    // "P" o "PT" a secas no son duraciones utiles: no dicen nada.
    if (fecha.isEmpty() && hora.isEmpty()) return null

    val dias = valor(fecha, 'D') ?: return null
    val horas = valor(hora, 'H') ?: return null
    val minutos = valor(hora, 'M') ?: return null
    val segundos = valor(hora, 'S') ?: return null

    return dias * 86_400 + horas * 3_600 + minutos * 60 + segundos
  }

  /** La misma duracion, en horas. */
  fun hours(texto: String?): Double? = seconds(texto)?.let { it / 3_600.0 }

  /**
   * Lee el numero que precede a [unidad] dentro de [tramo].
   *
   * Devuelve `0` si la unidad no aparece (es valido: `PT15S` no lleva horas) y
   * `null` si aparece con algo que no es un numero, que si es un formato roto.
   */
  private fun valor(tramo: String, unidad: Char): Int? {
    val posicion = tramo.indexOf(unidad)
    if (posicion < 0) return 0

    // Se retrocede mientras haya digitos: lo de antes pertenece a otra unidad.
    var inicio = posicion
    while (inicio > 0 && tramo[inicio - 1].isDigit()) inicio--

    if (inicio == posicion) return null
    return tramo.substring(inicio, posicion).toIntOrNull()
  }
}
