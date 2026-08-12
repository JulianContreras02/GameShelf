package com.gameshelf

import com.gameshelf.data.net.GameShelfJson
import kotlinx.serialization.DeserializationStrategy

/**
 * Carga las respuestas de ejemplo guardadas en `src/test/resources/fixtures`.
 *
 * Son **los mismos archivos** que usa la suite de iOS, copiados sin tocar: si
 * las dos versiones se prueban contra las mismas respuestas reales, un cambio
 * de formato en una API rompe las dos a la vez y no una sola.
 */
object Fixture {

  fun text(nombre: String): String =
    checkNotNull(javaClass.classLoader?.getResourceAsStream("fixtures/$nombre.json")) {
      "Falta el fixture $nombre.json"
    }.bufferedReader().use { it.readText() }

  fun <T> decode(nombre: String, serializer: DeserializationStrategy<T>): T =
    GameShelfJson.decodeFromString(serializer, text(nombre))
}
