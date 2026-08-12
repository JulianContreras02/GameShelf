package com.gameshelf.domain

import androidx.annotation.StringRes
import com.gameshelf.R
import kotlinx.serialization.Serializable

/**
 * Cuantos trofeos hay de cada tipo.
 *
 * Se guarda como un valor y no como cuatro campos sueltos en [StoreEntry]
 * porque los cuatro van siempre juntos: sumarlos, compararlos o mostrarlos por
 * separado no tiene sentido.
 *
 * Es `@Serializable` porque Room lo persiste como una sola columna JSON, que
 * es el equivalente al valor embebido que guardaba SwiftData.
 */
@Serializable
data class TrophyCounts(
  val bronze: Int = 0,
  val silver: Int = 0,
  val gold: Int = 0,
  val platinum: Int = 0,
) {
  val total: Int get() = bronze + silver + gold + platinum

  val isEmpty: Boolean get() = total == 0

  /** Cuantos hay de un tipo concreto. */
  fun count(kind: TrophyKind): Int = when (kind) {
    TrophyKind.BRONZE -> bronze
    TrophyKind.SILVER -> silver
    TrophyKind.GOLD -> gold
    TrophyKind.PLATINUM -> platinum
  }
}

/**
 * El desglose de trofeos de un juego: cuantos tiene, cuantos llevas y que
 * porcentaje representa eso.
 *
 * Los tres van juntos porque salen de la **misma** lista de trofeos. Un juego
 * puede tener dos (la de PS4 y la de PS5), y mezclar el porcentaje de una con
 * los conteos de la otra ensenaria dos numeros que se contradicen.
 */
data class TrophyBreakdown(
  /** Cuantos se consiguieron. */
  val earned: TrophyCounts,
  /** Cuantos tiene el juego en total. */
  val defined: TrophyCounts,
  /** Porcentaje conseguido, tal como lo reporta la tienda. `null` si no lo dice. */
  val progress: Int?,
)

/**
 * Los tipos de trofeo de PlayStation.
 *
 * El orden es el de la propia consola: de mas comun a mas dificil, con el
 * platino al final porque solo se consigue al tener todos los demas.
 */
enum class TrophyKind(val id: String, @StringRes val displayNameRes: Int) {
  BRONZE("bronze", R.string.trophy_bronze),
  SILVER("silver", R.string.trophy_silver),
  GOLD("gold", R.string.trophy_gold),
  PLATINUM("platinum", R.string.trophy_platinum);

  /**
   * Que hay que hacer para conseguirlo, cuando no es obvio.
   *
   * Solo el platino la lleva: los otros tres se entienden solos.
   */
  @get:StringRes
  val explanationRes: Int?
    get() = when (this) {
      PLATINUM -> R.string.trophy_platinum_explanation
      BRONZE, SILVER, GOLD -> null
    }
}
