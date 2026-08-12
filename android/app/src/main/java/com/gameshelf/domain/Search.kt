package com.gameshelf.domain

import java.text.Normalizer

/**
 * Forma del texto para comparar y buscar: sin espacios sobrantes, sin
 * mayusculas y sin tildes.
 *
 * Es lo que hace que "accion" encuentre "Acción" y que "RPG" y "rpg" sean lo
 * mismo. Vive aca y no en cada tipo para que la busqueda y las etiquetas usen
 * exactamente la misma regla.
 *
 * En iOS esto era `folding(options: [.caseInsensitive, .diacriticInsensitive])`.
 * El equivalente en la JVM es descomponer a NFD y quitar los diacriticos: la
 * "ó" pasa a ser "o" + tilde combinante, y se borra la segunda mitad.
 */
val String.normalizedForSearch: String
  get() {
    val descompuesto = Normalizer.normalize(trim(), Normalizer.Form.NFD)
    return DIACRITICOS.replace(descompuesto, "").lowercase()
  }

/** Si el texto contiene lo buscado, ignorando mayusculas y tildes. */
fun String.containsNormalized(buscado: String): Boolean {
  val normalizado = buscado.normalizedForSearch
  if (normalizado.isEmpty()) return true
  return normalizedForSearch.contains(normalizado)
}

/** Si el texto empieza por lo buscado, ignorando mayusculas y tildes. */
fun String.hasPrefixNormalized(buscado: String): Boolean {
  val normalizado = buscado.normalizedForSearch
  if (normalizado.isEmpty()) return true
  return normalizedForSearch.startsWith(normalizado)
}

/** Marcas diacriticas combinantes que deja la descomposicion NFD. */
private val DIACRITICOS = Regex("\\p{InCombiningDiacriticalMarks}+")
