package com.gameshelf.ui.library

import androidx.annotation.StringRes
import com.gameshelf.R
import com.gameshelf.domain.Game
import com.gameshelf.domain.NameOrder
import com.gameshelf.domain.PlayStatus

/**
 * Clasifica la biblioteca sola, a partir de lo que ya sabe la app.
 *
 * Complementa el estado manual en vez de reemplazarlo: con 118 juegos,
 * marcarlos uno a uno no escala, pero las horas que reporta Steam ya dicen
 * mucho.
 *
 * Es un objeto sin estado, con funciones puras: la clasificacion se prueba sin
 * levantar pantalla ni base de datos.
 */
object LibraryInsights {

  /** Por debajo de cuantas horas se considera que un juego solo se "probo". */
  const val BARELY_TRIED_THRESHOLD = 1.0

  /** Cuantos juegos se muestran en cada seccion destacada. */
  const val SECTION_LIMIT = 10

  // --- Resumen -------------------------------------------------------------

  /** Numeros generales de la biblioteca. */
  data class Summary(
    val totalGames: Int = 0,
    val totalHours: Double = 0.0,
    val unplayedCount: Int = 0,
    val barelyTriedCount: Int = 0,
    val recentlyPlayedCount: Int = 0,
  ) {
    /**
     * Que parte de la biblioteca nunca se toco, de 0 a 1.
     *
     * Con la biblioteca vacia devuelve 0 y no un valor invalido: nadie tiene
     * "0% sin jugar" de cero juegos, pero es mejor que dividir por cero.
     */
    val unplayedFraction: Double
      get() = if (totalGames > 0) unplayedCount.toDouble() / totalGames else 0.0

    /**
     * Horas promedio por juego jugado.
     *
     * Se calcula sobre los que si se jugaron: incluir los de 0 h hundiria el
     * promedio y no diria nada util.
     */
    val averageHoursPerPlayedGame: Double
      get() {
        val jugados = totalGames - unplayedCount
        return if (jugados > 0) totalHours / jugados else 0.0
      }

    val isEmpty: Boolean get() = totalGames == 0
  }

  /** Calcula el resumen. */
  fun summary(juegos: List<Game>): Summary {
    var horas = 0.0
    var sinJugar = 0
    var apenasProbados = 0
    var recientes = 0

    juegos.forEach { juego ->
      horas += juego.playtimeHours

      if (juego.isUnplayed) {
        sinJugar++
      } else if (juego.playtimeHours < BARELY_TRIED_THRESHOLD) {
        apenasProbados++
      }

      if (juego.isRecentlyPlayed) recientes++
    }

    return Summary(
      totalGames = juegos.size,
      totalHours = horas,
      unplayedCount = sinJugar,
      barelyTriedCount = apenasProbados,
      recentlyPlayedCount = recientes,
    )
  }

  // --- Secciones automaticas -----------------------------------------------

  /** Que clase de grupo automatico es. */
  enum class SectionKind(
    val id: String,
    @StringRes val titleRes: Int,
    @StringRes val explanationRes: Int,
    val icon: SectionIcon,
  ) {
    RECENTLY_PLAYED(
      "recentlyPlayed",
      R.string.section_recently_played,
      R.string.section_recently_played_explanation,
      SectionIcon.FLAME,
    ),
    MOST_PLAYED(
      "mostPlayed",
      R.string.section_most_played,
      R.string.section_most_played_explanation,
      SectionIcon.TROPHY,
    ),
    BARELY_TRIED(
      "barelyTried",
      R.string.section_barely_tried,
      R.string.section_barely_tried_explanation,
      SectionIcon.HOURGLASS,
    ),
    NEVER_PLAYED(
      "neverPlayed",
      R.string.section_never_played,
      R.string.section_never_played_explanation,
      SectionIcon.BOX,
    ),
  }

  /** Un grupo de juegos que la app arma sola. */
  data class Section(
    val kind: SectionKind,
    val games: List<Game>,
    /** Cuantos hay en total, aunque solo se muestren los primeros. */
    val totalCount: Int,
  ) {
    val id: String get() = kind.id
    val isEmpty: Boolean get() = games.isEmpty()

    /** Si hay mas de los que se estan mostrando. */
    val hasMore: Boolean get() = totalCount > games.size
  }

  /** Arma todas las secciones, dejando fuera las que quedarian vacias. */
  fun sections(juegos: List<Game>, limit: Int = SECTION_LIMIT): List<Section> =
    SectionKind.entries.map { section(it, juegos, limit) }.filter { !it.isEmpty }

  /** Arma una seccion concreta. */
  fun section(kind: SectionKind, juegos: List<Game>, limit: Int = SECTION_LIMIT): Section {
    val coincidencias = games(kind, juegos)
    return Section(kind, coincidencias.take(limit), coincidencias.size)
  }

  /** Todos los juegos de una categoria, ya ordenados. */
  fun games(kind: SectionKind, juegos: List<Game>): List<Game> = when (kind) {
    SectionKind.RECENTLY_PLAYED ->
      juegos.filter { it.isRecentlyPlayed }.sortedByDescending { it.recentPlaytimeHours }

    SectionKind.MOST_PLAYED ->
      juegos.filter { !it.isUnplayed }.sortedByDescending { it.playtimeHours }

    SectionKind.BARELY_TRIED ->
      juegos
        .filter { !it.isUnplayed && it.playtimeHours < BARELY_TRIED_THRESHOLD }
        .sortedBy { it.playtimeHours }

    SectionKind.NEVER_PLAYED ->
      juegos.filter { it.isUnplayed }.sortedWith(NameOrder.byName())
  }

  // --- Distribucion del tiempo ---------------------------------------------

  /** Cuanto del tiempo total concentran unos pocos juegos. */
  data class Concentration(
    /** Cuantos juegos hacen falta para llegar a la mitad de las horas. */
    val gamesForHalfTheTime: Int = 0,
    /** Que parte del tiempo se lleva el juego con mas horas, de 0 a 1. */
    val topGameShare: Double = 0.0,
    /** Que parte del tiempo se llevan los cinco con mas horas, de 0 a 1. */
    val topFiveShare: Double = 0.0,
  )

  /**
   * Calcula como se reparte el tiempo jugado.
   *
   * Sin horas registradas devuelve todo en cero, en vez de dividir por cero.
   */
  fun concentration(juegos: List<Game>): Concentration {
    val horas = juegos.map { it.playtimeHours }.filter { it > 0 }.sortedDescending()
    val total = horas.sum()

    if (total <= 0) return Concentration()

    var acumulado = 0.0
    var paraLaMitad = 0
    for ((indice, valor) in horas.withIndex()) {
      acumulado += valor
      if (acumulado >= total / 2) {
        paraLaMitad = indice + 1
        break
      }
    }

    return Concentration(
      gamesForHalfTheTime = paraLaMitad,
      topGameShare = (horas.firstOrNull() ?: 0.0) / total,
      topFiveShare = horas.take(5).sum() / total,
    )
  }

  // --- Sugerencia ----------------------------------------------------------

  /**
   * Juegos con 0 horas que **no** estan ya marcados como pendientes.
   *
   * Son los candidatos a marcar en lote. Se excluyen los que el usuario ya
   * clasifico a mano: si marco como terminado un juego que jugo en consola,
   * cambiarselo seria pisar su decision.
   */
  fun candidatesForBacklog(juegos: List<Game>): List<Game> =
    juegos
      .filter { it.isUnplayed && it.status != PlayStatus.BACKLOG }
      .sortedWith(NameOrder.byName())
}

/** Icono de cada seccion automatica. */
enum class SectionIcon { FLAME, TROPHY, HOURGLASS, BOX }
