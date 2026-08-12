package com.gameshelf.domain

import java.text.Collator
import java.util.Locale

/**
 * Comparacion de nombres sensible al idioma.
 *
 * Es el equivalente de `localizedStandardCompare` de Foundation, que el
 * proyecto de iOS usa en todos los ordenamientos por nombre. Sin esto, la
 * comparacion seria por punto de codigo y "Ángel" caeria detras de "Zelda".
 *
 * La fuerza `SECONDARY` distingue tildes pero no mayusculas, que es lo que
 * hace Foundation: "angel" y "Angel" quedan juntos, "angel" y "ángel" no se
 * confunden.
 */
object NameOrder {

  fun collator(locale: Locale = Locale.getDefault()): Collator =
    Collator.getInstance(locale).apply { strength = Collator.SECONDARY }

  /** Comparador de juegos por nombre. */
  fun byName(locale: Locale = Locale.getDefault()): Comparator<Game> {
    val collator = collator(locale)
    return Comparator { uno, otro -> collator.compare(uno.name, otro.name) }
  }

  /** Comparador de textos sueltos. */
  fun byText(locale: Locale = Locale.getDefault()): Comparator<String> {
    val collator = collator(locale)
    return Comparator { uno, otro -> collator.compare(uno, otro) }
  }
}
