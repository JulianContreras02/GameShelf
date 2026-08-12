package com.gameshelf.domain

import java.time.Instant
import java.util.UUID

/**
 * Un juego de la biblioteca, independiente de la tienda de donde venga.
 *
 * Un mismo juego puede estar en varias tiendas a la vez: esa relacion vive en
 * [storeEntries]. Esa separacion es la que despues permite detectar que un
 * juego lo tienes en Steam y en Epic sin duplicarlo en la biblioteca.
 *
 * Los campos personales ([status], [notes]) no se sobrescriben al
 * re-sincronizar con una tienda.
 *
 * A diferencia de la clase `@Model` de SwiftData, esto es un valor inmutable.
 * Donde iOS mutaba el objeto y dejaba que el contexto guardara, aca los
 * mappers devuelven una copia y el repositorio la escribe. El comportamiento
 * observable es el mismo y ademas se puede comparar con `==` en las pruebas.
 *
 * Ojo con [collections] y [tags]: las instancias que llegan ahi vienen con su
 * propia lista de juegos **vacia**. Es a proposito, para cortar el ciclo
 * juego -> coleccion -> juego. Si necesitas los juegos de una coleccion,
 * pidesela al repositorio.
 */
data class Game(
  /** Identificador propio de la app, estable aunque cambien los ids de tienda. */
  val id: UUID = UUID.randomUUID(),

  val name: String = "",

  /** URL de la caratula, como texto. */
  val coverImageURL: String? = null,

  val releaseDate: Instant? = null,

  /** Horas jugadas acumuladas, sumando todas las tiendas. */
  val playtimeHours: Double = 0.0,

  /** Notas personales del usuario. */
  val notes: String = "",

  val status: PlayStatus = PlayStatus.BACKLOG,

  /** Cuando se creo el registro en la app. */
  val addedAt: Instant = Instant.now(),

  /** En que tiendas esta este juego. */
  val storeEntries: List<StoreEntry> = emptyList(),

  /** Colecciones del usuario a las que pertenece. */
  val collections: List<GameCollection> = emptyList(),

  /** Etiquetas libres del usuario. */
  val tags: List<GameTag> = emptyList(),
) {

  /** Tiendas en las que esta el juego, sin repetir. */
  val stores: List<Store>
    get() = storeEntries.map { it.store }.distinct().sortedBy { it.id }

  /** Si el juego esta disponible en una tienda concreta. */
  fun isAvailable(on: Store): Boolean = storeEntries.any { it.store == on }

  /**
   * La ultima vez que se jugo, mirando todas las tiendas.
   *
   * `null` si no se ha jugado en ninguna.
   */
  val lastPlayedAt: Instant?
    get() = storeEntries.mapNotNull { it.lastPlayedAt }.maxOrNull()

  /**
   * Si el juego nunca se ha jugado, segun las horas que reportan las tiendas.
   *
   * Es distinto de [status]: esto es un dato de la tienda, y aquello una
   * decision del usuario. Pueden no coincidir, por ejemplo si lo jugaste en
   * consola y lo marcaste como terminado.
   */
  val isUnplayed: Boolean get() = playtimeHours <= 0

  /**
   * Cuando se agrego a la lista de deseos de alguna tienda.
   *
   * Si esta en varias, la fecha mas antigua: es cuando empezaste a quererlo.
   */
  val wishlistedAt: Instant?
    get() = storeEntries.mapNotNull { it.wishlistedAt }.minOrNull()

  /**
   * Si el juego todavia no ha salido, segun alguna tienda o segun su fecha.
   *
   * Se miran las dos cosas porque Steam no siempre manda fecha: a veces solo
   * dice "Proximamente".
   */
  fun isComingSoon(now: Instant = Instant.now()): Boolean {
    if (storeEntries.any { it.comingSoon }) return true
    return releaseDate?.isAfter(now) == true
  }

  /**
   * Porcentaje de trofeos conseguidos, si alguna tienda lo lleva.
   *
   * Si esta en varias, el mas alto: es el progreso que el usuario reconoce
   * como suyo.
   */
  val trophyProgress: Int?
    get() = storeEntries.mapNotNull { it.trophyProgress }.maxOrNull()

  /**
   * Desglose de trofeos, si alguna tienda lo lleva.
   *
   * Se toma el de la entrada con mas progreso: si un juego esta en PS4 y en
   * PS5 con dos listas, la que interesa es la mas avanzada.
   *
   * El porcentaje viaja junto con los conteos y **no** se lee de
   * [trophyProgress]: aquel mira todas las entradas y este solo las que tienen
   * desglose, asi que pueden salir de listas distintas. Pasa con una entrada
   * guardada antes de que se guardaran los conteos, que tiene porcentaje pero
   * no desglose. Si la ficha mezclara los dos, ensenaria un "90%" encima de un
   * "15 / 38" de otra lista.
   */
  val trophyBreakdown: TrophyBreakdown?
    get() {
      val conTrofeos = storeEntries
        .filter { it.definedTrophies?.isEmpty == false }
        .maxByOrNull { it.trophyProgress ?: 0 }
        ?: return null

      val definidos = conTrofeos.definedTrophies ?: return null
      return TrophyBreakdown(
        earned = conTrofeos.earnedTrophies ?: TrophyCounts(),
        defined = definidos,
        progress = conTrofeos.trophyProgress,
      )
    }

  /**
   * El appid de Steam, si el juego viene de ahi.
   *
   * Hace falta para consultar precios: IsThereAnyDeal identifica los juegos
   * por el id de la tienda, no por el nuestro.
   */
  val steamAppID: Int?
    get() = storeEntries.firstOrNull { it.store == Store.STEAM }?.storeGameID?.toIntOrNull()

  /**
   * Si alguna tienda lo tiene en su lista de deseos.
   *
   * Ojo: no es lo mismo que `status == WISHLIST`. Esto es un dato de la tienda
   * y aquello una decision tuya, y pueden no coincidir.
   */
  val isWishlistedInStore: Boolean get() = wishlistedAt != null

  /** Horas jugadas en las ultimas dos semanas, sumando todas las tiendas. */
  val recentPlaytimeHours: Double
    get() = storeEntries.sumOf { it.recentPlaytimeHours }

  /** Si el juego se toco en las ultimas dos semanas. */
  val isRecentlyPlayed: Boolean get() = recentPlaytimeHours > 0

  /**
   * Enlace a la ficha del juego en una tienda.
   *
   * Si esta en varias, prefiere la que se indique; si no, la primera que tenga
   * enlace.
   */
  fun storeLink(preferring: Store? = null): String? {
    val candidatas = storeEntries.filter { !it.storeURL.isNullOrEmpty() }
    val elegida = preferring?.let { p -> candidatas.firstOrNull { it.store == p } }
      ?: candidatas.firstOrNull()
    return elegida?.storeURL
  }
}
