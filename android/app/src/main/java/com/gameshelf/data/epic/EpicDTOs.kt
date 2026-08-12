package com.gameshelf.data.epic

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

// --- Autenticacion --------------------------------------------------------

/** Respuesta buena del endpoint de tokens de Epic. */
@Serializable
data class EpicTokenResponse(
  @SerialName("access_token") val accessToken: String? = null,
  @SerialName("refresh_token") val refreshToken: String? = null,
  @SerialName("expires_in") val expiresIn: Int? = null,
  @SerialName("refresh_expires") val refreshExpires: Int? = null,
  @SerialName("account_id") val accountId: String? = null,
  val displayName: String? = null,
) {
  /** Convierte la respuesta en credenciales, o `null` si venia incompleta. */
  fun credentials(ahora: Instant): EpicCredentials? {
    if (accessToken.isNullOrEmpty() || refreshToken.isNullOrEmpty()) return null

    return EpicCredentials(
      accessToken = accessToken,
      refreshToken = refreshToken,
      // Epic da unas ocho horas; si no lo dice, se asume eso en vez de tratar
      // el token como eterno.
      expiresAt = ahora.plusSeconds((expiresIn ?: 28_800).toLong()),
      refreshExpiresAt = refreshExpires?.let { ahora.plusSeconds(it.toLong()) },
      accountID = accountId,
      displayName = displayName,
    )
  }
}

/**
 * Respuesta de error de Epic.
 *
 * Forma real, comprobada contra la API:
 * ```json
 * { "errorCode": "errors.com.epicgames.account.oauth.authorization_code_not_found",
 *   "numericErrorCode": 18059 }
 * ```
 */
@Serializable
data class EpicErrorResponse(
  val errorCode: String? = null,
  val errorMessage: String? = null,
  val numericErrorCode: Int? = null,
) {
  val esDeCredencialesInvalidas: Boolean
    get() {
      if (numericErrorCode != null && numericErrorCode in CODIGOS_DE_CREDENCIAL_INVALIDA) {
        return true
      }
      return errorCode?.contains("authorization_code") == true ||
        errorCode?.contains("refresh_token") == true
    }

  val descripcion: String get() = errorMessage ?: errorCode ?: "sin detalle"

  companion object {
    /**
     * Codigos que significan "lo que mandaste ya no sirve", comprobados
     * pidiendo con datos invalidos:
     * - `18059` el codigo de autorizacion no existe o ya se uso
     * - `18036` el refresh token no vale
     */
    val CODIGOS_DE_CREDENCIAL_INVALIDA = setOf(18059, 18036)
  }
}

// --- Biblioteca -----------------------------------------------------------

/**
 * Respuesta de `library/api/public/items`.
 *
 * Viene paginada: mientras `nextCursor` traiga algo, faltan mas.
 */
@Serializable
data class EpicLibraryResponse(
  val records: List<EpicLibraryRecordDTO>? = null,
  val responseMetadata: EpicResponseMetadataDTO? = null,
) {
  val registros: List<EpicLibraryRecordDTO> get() = records ?: emptyList()
  val siguienteCursor: String? get() = responseMetadata?.nextCursor?.takeIf { it.isNotEmpty() }
}

@Serializable
data class EpicResponseMetadataDTO(val nextCursor: String? = null)

/**
 * Una entrada de la biblioteca de Epic.
 *
 * **No es un juego, es un artefacto.** Un mismo juego aparece varias veces: el
 * ejecutable, sus DLC, sus editores... En la biblioteca real, Ark salia 6
 * veces y Cyberpunk 4. Lo que agrupa a todos es el `namespace`.
 */
@Serializable
data class EpicLibraryRecordDTO(
  /**
   * Identifica al **juego**. Se comprobo con la biblioteca real que cada
   * namespace tiene un unico nombre, asi que sirve de identificador estable.
   */
  val namespace: String,

  val catalogItemId: String? = null,

  /**
   * Identifica al **artefacto** dentro del juego. Es la clave con la que se
   * emparejan los tiempos jugados.
   */
  val appName: String? = null,

  /** Nombre legible del juego. En la biblioteca real venia en todos. */
  val sandboxName: String? = null,

  val recordType: String? = null,
) {
  /**
   * Si el nombre sirve para mostrarlo.
   *
   * Epic pone `"Live"` en unos cuantos, casi todos regalos semanales, y ahi no
   * dice nada del juego. Esos hay que resolverlos contra el catalogo.
   */
  val tieneNombreUtil: Boolean
    get() = !sandboxName.isNullOrEmpty() && sandboxName != NOMBRE_SIN_RESOLVER

  companion object {
    /** El valor que pone Epic cuando el sandbox no tiene nombre propio. */
    const val NOMBRE_SIN_RESOLVER = "Live"
  }
}

// --- Tiempo jugado --------------------------------------------------------

/**
 * Una entrada de `playtime/account/{id}/all`.
 *
 * El tiempo va por artefacto, no por juego, y **el mismo tiempo aparece
 * repetido bajo varios artefactos del mismo juego**: Cyberpunk reportaba
 * 49,8 h dos veces, con ids distintos. Por eso al juntarlos se toma el mayor y
 * no la suma, que daria el doble.
 */
@Serializable
data class EpicPlaytimeDTO(val artifactId: String, val totalTime: Int? = null) {
  val horas: Double get() = (totalTime ?: 0) / 3600.0
}

// --- Catalogo -------------------------------------------------------------

@Serializable
data class EpicCatalogItemDTO(
  val title: String? = null,
  val keyImages: List<EpicKeyImageDTO>? = null,
) {
  /**
   * La caratula vertical, que es la que encaja con el resto de la app.
   *
   * Si no esta, sirve la apaisada: mejor una imagen con otra proporcion que un
   * hueco gris.
   */
  val coverURL: String?
    get() {
      val preferidas = listOf("DieselGameBoxTall", "OfferImageTall", "DieselGameBox", "OfferImageWide")
      preferidas.forEach { tipo ->
        keyImages?.firstOrNull { it.type == tipo }?.url?.let { return it }
      }
      return keyImages?.firstOrNull()?.url
    }
}

@Serializable
data class EpicKeyImageDTO(val type: String? = null, val url: String? = null)
