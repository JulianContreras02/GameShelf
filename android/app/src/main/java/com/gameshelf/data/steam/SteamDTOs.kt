package com.gameshelf.data.steam

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * Los DTOs de Steam.
 *
 * Estos tipos reflejan **exactamente** lo que manda Steam, con sus nombres y
 * sus rarezas. No se guardan en la base: se traducen a `Game` y se descartan.
 * Ver la regla 5 en `CONTRIBUTING.md`.
 */

// MARK: - Biblioteca

/**
 * Respuesta cruda de `IPlayerService/GetOwnedGames`.
 *
 * Ejemplo:
 * ```json
 * { "response": { "game_count": 2, "games": [ ... ] } }
 * ```
 */
@Serializable
data class SteamOwnedGamesResponse(val response: SteamOwnedGamesPayload)

/**
 * Contenido de la respuesta.
 *
 * Steam devuelve `{"response":{}}` cuando el perfil es privado o la biblioteca
 * esta vacia: por eso los dos campos son opcionales y se exponen con valores
 * por defecto.
 */
@Serializable
data class SteamOwnedGamesPayload(
  @SerialName("game_count") private val gameCount: Int? = null,
  @SerialName("games") private val rawGames: List<SteamGameDTO>? = null,
) {
  /** Cuantos juegos reporta Steam. `0` si no vino el dato. */
  val count: Int get() = gameCount ?: 0

  /** Juegos de la biblioteca. Lista vacia si no vino el dato. */
  val games: List<SteamGameDTO> get() = rawGames ?: emptyList()

  /**
   * `true` cuando Steam respondio sin datos.
   *
   * No distingue entre "perfil privado" y "biblioteca vacia": la API manda lo
   * mismo en los dos casos. Quien llame decide como se lo explica al usuario.
   */
  val isEmpty: Boolean get() = games.isEmpty()
}

/** Un juego tal como lo describe Steam. */
@Serializable
data class SteamGameDTO(
  /** Identificador del juego en Steam. Es la clave para todo lo demas. */
  @SerialName("appid") val appID: Int,

  /** Nombre del juego. Solo viene si se pidio con `include_appinfo=1`. */
  val name: String? = null,

  /** Tiempo jugado **en minutos**, no en horas. */
  @SerialName("playtime_forever") val playtimeMinutes: Int? = null,

  /**
   * Minutos jugados en las ultimas dos semanas.
   *
   * Steam **solo manda este campo si hubo actividad reciente**: en una
   * biblioteca real aparecio en 2 de 118 juegos. Que sea `null` significa "no
   * lo has tocado", no que falte el dato.
   */
  @SerialName("playtime_2weeks") val playtimeLast2WeeksMinutes: Int? = null,

  /** Hash del icono. No es una URL: hay que construirla con [iconURL]. */
  @SerialName("img_icon_url") val iconHash: String? = null,

  /** Ultima vez que se jugo, en segundos desde 1970. `0` significa nunca. */
  @SerialName("rtime_last_played") val lastPlayedTimestamp: Int? = null,
) {
  /** Tiempo jugado en horas, que es como se muestra en la app. */
  val playtimeHours: Double get() = (playtimeMinutes ?: 0) / 60.0

  /** Horas jugadas en las ultimas dos semanas, o `0` si no hubo actividad. */
  val playtimeLast2WeeksHours: Double get() = (playtimeLast2WeeksMinutes ?: 0) / 60.0

  /** Si el juego se toco en las ultimas dos semanas. */
  val isRecentlyPlayed: Boolean get() = (playtimeLast2WeeksMinutes ?: 0) > 0

  /** Ultima vez que se jugo, o `null` si nunca. */
  val lastPlayed: Instant?
    get() = lastPlayedTimestamp?.takeIf { it > 0 }?.let { Instant.ofEpochSecond(it.toLong()) }

  /**
   * Caratula horizontal del juego.
   *
   * Se arma a partir del [appID]: Steam no la manda en esta respuesta.
   */
  val coverURL: String
    get() = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appID/header.jpg"

  /** Icono pequeno. Requiere el hash, que puede no venir. */
  val iconURL: String?
    get() = iconHash?.takeIf { it.isNotEmpty() }?.let {
      "https://media.steampowered.com/steamcommunity/public/images/apps/$appID/$it.jpg"
    }

  /** Ficha del juego en la tienda. */
  val storeURL: String get() = "https://store.steampowered.com/app/$appID"
}

// MARK: - Lista de deseos

/**
 * Respuesta de `IWishlistService/GetWishlist`.
 *
 * Cuando la wishlist es privada, o esta vacia, Steam responde
 * `{"response":{}}` con HTTP 200: **no hay forma de distinguir los dos
 * casos**. Por eso `items` es opcional y quien llame decide que decirle al
 * usuario.
 */
@Serializable
data class SteamWishlistResponse(val response: Payload) {

  @Serializable
  data class Payload(val items: List<SteamWishlistItemDTO>? = null)

  /** Los juegos, o lista vacia si no vino ninguno. */
  val items: List<SteamWishlistItemDTO> get() = response.items ?: emptyList()

  /**
   * Si Steam devolvio el objeto sin la lista.
   *
   * Distinto de "la lista llego vacia": eso ultimo no pasa en la practica,
   * pero conviene no confundir ausencia con vacio.
   */
  val isMissingItems: Boolean get() = response.items == null
}

/**
 * Un juego en la lista de deseos.
 *
 * Trae solo el identificador: el nombre y la caratula hay que pedirlos aparte
 * a `IStoreBrowseService/GetItems`.
 */
@Serializable
data class SteamWishlistItemDTO(
  @SerialName("appid") val appID: Int,

  /** Orden que el usuario le puso en Steam. `0` significa sin prioridad. */
  val priority: Int? = null,

  /** Cuando se agrego a la lista, en segundos desde 1970. */
  @SerialName("date_added") val dateAdded: Int? = null,
) {
  /** Cuando se agrego, ya como fecha. */
  val addedAt: Instant?
    get() = dateAdded?.takeIf { it > 0 }?.let { Instant.ofEpochSecond(it.toLong()) }
}

// MARK: - Fichas de tienda

/**
 * Respuesta de `IStoreBrowseService/GetItems`.
 *
 * Es el complemento de la wishlist: esa devuelve solo appids, y esto convierte
 * una tanda de appids en nombres, caratulas y fechas de lanzamiento.
 */
@Serializable
data class SteamStoreItemsResponse(val response: SteamStoreItemsPayload) {
  val items: List<SteamStoreItemDTO> get() = response.storeItems ?: emptyList()
}

@Serializable
data class SteamStoreItemsPayload(
  @SerialName("store_items") val storeItems: List<SteamStoreItemDTO>? = null,
)

/** La ficha de tienda de un juego. */
@Serializable
data class SteamStoreItemDTO(
  @SerialName("appid") val appID: Int,
  val name: String? = null,

  /** `false` si el juego ya no se muestra en la tienda (retirado, por ejemplo). */
  val visible: Boolean? = null,

  /** `1` si Steam pudo resolver el appid. */
  val success: Int? = null,

  val assets: SteamStoreAssets? = null,
  val release: SteamStoreRelease? = null,

  /** Ruta relativa de la ficha, del estilo `app/268910/Cuphead`. */
  @SerialName("store_url_path") val storeURLPath: String? = null,
) {
  /** Si Steam devolvio datos utiles para este appid. */
  val isUsable: Boolean get() = success == 1 && !name.isNullOrEmpty()

  /**
   * Ficha del juego en la tienda.
   *
   * Se arma con el appid y no con `store_url_path` porque esa ruta incluye el
   * nombre y cambia si el juego se renombra; el appid solo, no.
   */
  val storeURL: String get() = "https://store.steampowered.com/app/$appID"

  /**
   * Caratula apaisada, la misma forma que usa el resto de la biblioteca.
   *
   * No se puede armar a mano como con los juegos que ya tienes: los titulos
   * recientes guardan sus imagenes bajo un hash y la ruta directa da 404. Por
   * eso hay que usar el formato que manda Steam y sustituirle el nombre del
   * archivo.
   */
  val coverURL: String? get() = assets?.url(assets.header)

  /** Cuando sale, o salio, el juego. */
  val releaseDate: Instant? get() = release?.date

  /** Si todavia no ha salido. */
  val isComingSoon: Boolean get() = release?.isComingSoon == true

  /**
   * Texto que pone Steam cuando no hay fecha ("Proximamente", un trimestre).
   *
   * Steam usa una de las dos formas, nunca las dos: o una fecha aproximada (el
   * 31 de diciembre quiere decir "en algun momento de este ano") o este texto.
   */
  val releaseNote: String? get() = release?.customMessage
}

/** Imagenes de un juego en la tienda. */
@Serializable
data class SteamStoreAssets(
  /** Plantilla con un hueco, del estilo `steam/apps/268910/${'$'}{FILENAME}?t=1`. */
  @SerialName("asset_url_format") val urlFormat: String? = null,
  val header: String? = null,
  @SerialName("library_capsule") val libraryCapsule: String? = null,
) {
  /** Arma la URL de una imagen concreta. */
  fun url(archivo: String?): String? {
    if (urlFormat.isNullOrEmpty() || archivo.isNullOrEmpty()) return null
    return CDN + urlFormat.replace("\${FILENAME}", archivo)
  }

  companion object {
    /**
     * Base del CDN de imagenes de tienda.
     *
     * Se usa el dominio de Akamai porque el de Cloudflare responde con una
     * redireccion 301 para estas rutas.
     */
    const val CDN = "https://shared.akamai.steamstatic.com/store_item_assets/"
  }
}

/** Datos de lanzamiento de un juego. */
@Serializable
data class SteamStoreRelease(
  @SerialName("steam_release_date") val steamReleaseDate: Int? = null,
  @SerialName("is_coming_soon") val isComingSoon: Boolean? = null,
  @SerialName("custom_release_date_message") val customMessage: String? = null,
) {
  val date: Instant?
    get() = steamReleaseDate?.takeIf { it > 0 }?.let { Instant.ofEpochSecond(it.toLong()) }
}
