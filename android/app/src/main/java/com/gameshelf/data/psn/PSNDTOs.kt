package com.gameshelf.data.psn

import com.gameshelf.domain.TrophyCounts
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.format.DateTimeParseException

// --- Autenticacion --------------------------------------------------------

/** Respuesta buena del endpoint de tokens. */
@Serializable
data class PSNTokenResponse(
  @SerialName("access_token") val accessToken: String? = null,
  @SerialName("refresh_token") val refreshToken: String? = null,

  /** Segundos que le quedan de vida al token de acceso. Suele ser 3600. */
  @SerialName("expires_in") val expiresIn: Int? = null,

  /**
   * Segundos de vida del token de refresco, si Sony lo dice.
   *
   * Es el dato que de verdad le importa al usuario: mientras este siga vivo,
   * la app renueva sola y no hay que hacer nada. No esta documentado en ningun
   * sitio publico que se pueda consultar, asi que se lee de la respuesta y, si
   * no viene, no se muestra ninguna fecha en vez de inventarse una.
   */
  @SerialName("refresh_token_expires_in") val refreshTokenExpiresIn: Int? = null,
) {
  /**
   * Convierte la respuesta en credenciales, o `null` si venia incompleta.
   *
   * Se pide la hora en vez de leerla aca para que las pruebas puedan fijarla.
   */
  fun credentials(ahora: Instant): PSNCredentials? {
    if (accessToken.isNullOrEmpty() || refreshToken.isNullOrEmpty()) return null

    // Sin expires_in se asume una hora, que es lo que Sony devuelve siempre.
    // Es preferible a tratar el token como eterno.
    val duracion = (expiresIn ?: 3600).toLong()

    return PSNCredentials(
      accessToken = accessToken,
      refreshToken = refreshToken,
      expiresAt = ahora.plusSeconds(duracion),
      refreshExpiresAt = refreshTokenExpiresIn?.let { ahora.plusSeconds(it.toLong()) },
    )
  }
}

/**
 * Respuesta de error del endpoint de tokens.
 *
 * Forma real, comprobada contra la API:
 * ```json
 * { "error": "invalid_grant",
 *   "error_description": "Invalid authorization code",
 *   "error_code": 4650 }
 * ```
 */
@Serializable
data class PSNErrorResponse(
  val error: String? = null,
  @SerialName("error_description") val errorDescription: String? = null,
  @SerialName("error_code") val errorCode: Int? = null,
) {
  val esDeCredencialesInvalidas: Boolean
    get() {
      if (errorCode != null && errorCode in CODIGOS_DE_CREDENCIAL_INVALIDA) return true
      return error == "invalid_grant" || error == "invalid_request"
    }

  val descripcion: String get() = errorDescription ?: error ?: "sin detalle"

  companion object {
    /**
     * Codigos que significan "lo que mandaste ya no sirve".
     *
     * Son los que se comprobaron pidiendo con datos invalidos:
     * - `4650` codigo de autorizacion invalido
     * - `4150` peticion invalida (sale con un refresh token que ya no vale)
     * - `4165` el usuario no esta autenticado (el NPSSO caduco)
     */
    val CODIGOS_DE_CREDENCIAL_INVALIDA = setOf(4650, 4150, 4165)
  }
}

// --- Lista de juegos jugados ---------------------------------------------

/** Respuesta de `/gamelist/v2/users/me/titles`. */
@Serializable
data class PSNGameListResponse(
  val titles: List<PSNTitleDTO>? = null,
  val totalItemCount: Int? = null,
  /** Desde donde pedir la siguiente pagina. `null` si ya no hay mas. */
  val nextOffset: Int? = null,
) {
  val juegos: List<PSNTitleDTO> get() = titles ?: emptyList()
}

/** Un juego jugado en PlayStation. */
@Serializable
data class PSNTitleDTO(
  /**
   * Identificador del juego en la tienda, del estilo `PPSA28038_00`.
   *
   * **No es el mismo que el de los trofeos**, que usan `npCommunicationId`
   * (`NPWR49518_00`). Relacionarlos necesita un endpoint aparte.
   */
  val titleId: String,

  val name: String? = null,

  /** El nombre en el idioma pedido. Suele coincidir con [name]. */
  val localizedName: String? = null,

  val imageUrl: String? = null,
  val localizedImageUrl: String? = null,

  /**
   * Que clase de contenido es: `ps5_native_game`, `ps4_game`, `pspc_game`,
   * `ps5_web_based_media_app`...
   */
  val category: String? = null,

  /** Cuantas veces se ha abierto. */
  val playCount: Int? = null,

  /** Tiempo jugado, en formato ISO 8601: `PT29H47M44S`. */
  val playDuration: String? = null,

  val firstPlayedDateTime: String? = null,
  val lastPlayedDateTime: String? = null,
) {
  /**
   * Si es un juego y no otra cosa.
   *
   * La lista trae tambien apps de video: Crunchyroll aparecio con categoria
   * `ps5_web_based_media_app` y 15 segundos de uso. Meterlas en la biblioteca
   * la ensuciaria con cosas que el usuario no considera juegos.
   */
  val esJuego: Boolean get() = category?.contains("game") == true

  /** El nombre a mostrar, prefiriendo el localizado. */
  val nombre: String? get() = (localizedName ?: name)?.takeIf { it.isNotEmpty() }

  /** La caratula, prefiriendo la localizada. */
  val coverURL: String? get() = localizedImageUrl ?: imageUrl

  /** Horas jugadas. `null` si la duracion no se pudo leer. */
  val playtimeHours: Double? get() = ISO8601Duration.hours(playDuration)

  val lastPlayedAt: Instant? get() = fecha(lastPlayedDateTime)
  val firstPlayedAt: Instant? get() = fecha(firstPlayedDateTime)

  companion object {
    /**
     * Las fechas llegan con fracciones de segundo (`...T02:43:03.060000Z`) y a
     * veces sin ellas.
     *
     * `Instant.parse` acepta las dos formas, asi que basta con envolverlo para
     * que un texto raro devuelva `null` en vez de tumbar la sincronizacion.
     */
    fun fecha(texto: String?): Instant? {
      if (texto.isNullOrEmpty()) return null
      return try {
        Instant.parse(texto)
      } catch (e: DateTimeParseException) {
        null
      }
    }
  }
}

// --- Trofeos por juego ----------------------------------------------------

/**
 * Respuesta de `/trophy/v1/users/me/titles/trophyTitles?npTitleIds=...`.
 *
 * Es la que relaciona los dos mundos: recibe ids de juego y devuelve los sets
 * de trofeos de cada uno.
 *
 * **Los resultados no vienen en el orden en que se pidieron.** Hay que
 * indexarlos por `npTitleId`.
 */
@Serializable
data class PSNTrophyMapResponse(val titles: List<PSNTitleTrophiesDTO>? = null) {
  /**
   * El progreso de cada juego, indexado por su id de tienda.
   *
   * Si un juego tiene varios sets de trofeos se toma el mas avanzado: es el
   * que el usuario reconoce como "lo que llevo".
   */
  val progresoPorTitleID: Map<String, PSNTrophyTitleDTO>
    get() = buildMap {
      (titles ?: emptyList()).forEach { entrada ->
        val mejor = (entrada.trophyTitles ?: emptyList()).maxByOrNull { it.progress ?: 0 }
        if (mejor != null) put(entrada.npTitleId, mejor)
      }
    }
}

/** Los sets de trofeos de un juego. */
@Serializable
data class PSNTitleTrophiesDTO(
  val npTitleId: String,
  /** Puede venir vacio: hay juegos sin trofeos. */
  val trophyTitles: List<PSNTrophyTitleDTO>? = null,
)

/** Un set de trofeos. */
@Serializable
data class PSNTrophyTitleDTO(
  val npCommunicationId: String? = null,
  val trophyTitleName: String? = null,
  /** Porcentaje conseguido, de 0 a 100. Ya viene calculado por Sony. */
  val progress: Int? = null,
  val earnedTrophies: PSNTrophyCountsDTO? = null,
  val definedTrophies: PSNTrophyCountsDTO? = null,
)

/** Cuantos trofeos hay de cada tipo. */
@Serializable
data class PSNTrophyCountsDTO(
  val bronze: Int? = null,
  val silver: Int? = null,
  val gold: Int? = null,
  val platinum: Int? = null,
) {
  val total: Int get() = (bronze ?: 0) + (silver ?: 0) + (gold ?: 0) + (platinum ?: 0)

  /** El mismo dato como valor de dominio. */
  val counts: TrophyCounts
    get() = TrophyCounts(
      bronze = bronze ?: 0,
      silver = silver ?: 0,
      gold = gold ?: 0,
      platinum = platinum ?: 0,
    )
}
