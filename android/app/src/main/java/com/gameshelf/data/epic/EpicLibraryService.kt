package com.gameshelf.data.epic

import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.NetworkError
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.text.Collator
import java.util.Locale

/** Un juego de Epic, ya agrupado y listo para guardar. */
data class EpicGame(
  /** El `namespace` de Epic, que identifica al juego. */
  val namespace: String,
  val name: String,
  val coverURL: String?,
  /** Horas jugadas. `0` si nunca se abrio, que en Epic es lo mas comun. */
  val playtimeHours: Double,
)

/**
 * Trae la biblioteca de Epic del usuario.
 *
 * Es el conector mas fragil de los tres: API no oficial, sin nombres en la
 * respuesta principal y con el tiempo jugado repartido por artefactos. Todo
 * eso queda encerrado aca detras.
 */
interface EpicLibraryServicing {
  /**
   * Trae los juegos de la cuenta.
   *
   * @throws EpicAuthError si la sesion ya no sirve.
   * @throws NetworkError si falla la peticion principal.
   */
  suspend fun fetchOwnedGames(): List<EpicGame>
}

/** Implementacion real contra los endpoints de Epic. */
class EpicLibraryService(
  private val client: HttpClient,
  private val accessToken: suspend () -> String,
  private val accountID: suspend () -> String?,
) : EpicLibraryServicing {

  override suspend fun fetchOwnedGames(): List<EpicGame> {
    val registros = fetchRecords()
    if (registros.isEmpty()) return emptyList()

    val tiempos = fetchPlaytimes()
    val porNamespace = agrupar(registros, tiempos)

    // Solo se pregunta al catalogo por los que no tienen nombre util. Con la
    // biblioteca real eran 49 de 293: preguntar por todos serian casi 300
    // peticiones para resolver algo que ya venia resuelto.
    val sinNombre = porNamespace.values.filter { !it.tieneNombre }
    val resueltos = resolverNombres(sinNombre)

    return porNamespace.values.mapNotNull { grupo ->
      if (grupo.tieneNombre) {
        return@mapNotNull EpicGame(
          namespace = grupo.namespace,
          name = grupo.nombre,
          coverURL = null,
          playtimeHours = grupo.horas,
        )
      }

      // Sin nombre resuelto se descarta: guardar un juego llamado
      // "1b737464d3c441f8" no le sirve a nadie.
      val ficha = resueltos[grupo.namespace] ?: return@mapNotNull null
      val titulo = ficha.title?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null

      EpicGame(
        namespace = grupo.namespace,
        name = titulo,
        coverURL = ficha.coverURL,
        playtimeHours = grupo.horas,
      )
    }.sortedWith(compareBy(COLLATOR) { it.name })
  }

  // --- Agrupar -------------------------------------------------------------

  /** Los artefactos de un mismo juego, ya juntos. */
  data class Grupo(
    val namespace: String,
    val nombre: String,
    val horas: Double,
    val catalogItemID: String?,
  ) {
    val tieneNombre: Boolean
      get() = nombre.isNotEmpty() && nombre != EpicLibraryRecordDTO.NOMBRE_SIN_RESOLVER
  }

  // --- Peticiones ----------------------------------------------------------

  /** Trae todas las paginas de la biblioteca. */
  suspend fun fetchRecords(): List<EpicLibraryRecordDTO> {
    val todos = mutableListOf<EpicLibraryRecordDTO>()
    var cursor: String? = null

    repeat(PAGINAS_MAXIMAS) {
      val respuesta = get(libraryURL(cursor), EpicLibraryResponse.serializer())
      todos += respuesta.registros

      cursor = respuesta.siguienteCursor ?: return todos
    }

    return todos
  }

  /**
   * Trae el tiempo jugado, indexado por artefacto.
   *
   * **No propaga errores.** Sin tiempos la biblioteca sigue sirviendo: se
   * veran los juegos con 0 horas, que es mejor que no ver nada.
   */
  suspend fun fetchPlaytimes(): Map<String, Double> {
    val cuenta = runCatching { accountID() }.getOrNull()
    if (cuenta.isNullOrEmpty()) return emptyMap()

    val url = "$LIBRARY_BASE/library/api/public/playtime/account/$cuenta/all"
    val tiempos = runCatching {
      get(url, ListSerializer(EpicPlaytimeDTO.serializer()))
    }.getOrNull() ?: return emptyMap()

    return tiempos.associate { it.artifactId to it.horas }
  }

  /**
   * Pregunta al catalogo por los juegos sin nombre util.
   *
   * **No propaga errores**, y por eso el catalogo no puede tumbar la
   * sincronizacion: si falla, esos juegos simplemente se quedan fuera y el
   * resto entra igual.
   */
  suspend fun resolverNombres(grupos: List<Grupo>): Map<String, EpicCatalogItemDTO> {
    val resultado = mutableMapOf<String, EpicCatalogItemDTO>()

    grupos.forEach { grupo ->
      val itemID = grupo.catalogItemID ?: return@forEach

      val base = "$CATALOG_BASE/catalog/api/shared/namespace/${grupo.namespace}/bulk/items"
      val url = base.toHttpUrlOrNull()?.newBuilder()
        ?.addQueryParameter("id", itemID)
        ?.addQueryParameter("includeDLCDetails", "false")
        ?.addQueryParameter("includeMainGameDetails", "false")
        ?.addQueryParameter("country", "CO")
        ?.addQueryParameter("locale", "es")
        ?.build()?.toString() ?: return@forEach

      val respuesta = runCatching {
        get(url, MapSerializer(String.serializer(), EpicCatalogItemDTO.serializer()))
      }.getOrNull() ?: return@forEach

      respuesta[itemID]?.let { resultado[grupo.namespace] = it }
    }

    return resultado
  }

  private suspend fun <T> get(url: String, serializer: DeserializationStrategy<T>): T = try {
    client.get(url, serializer, mapOf("Authorization" to "bearer ${accessToken()}"))
  } catch (e: NetworkError.HttpError) {
    if (e.statusCode == 401 || e.statusCode == 403) throw EpicAuthError.SesionExpirada else throw e
  }

  /** Arma la URL de la biblioteca, con su cursor si lo hay. */
  fun libraryURL(cursor: String? = null): String {
    val base = LIBRARY_URL.toHttpUrlOrNull() ?: throw NetworkError.InvalidURL(LIBRARY_URL)
    return base.newBuilder()
      .addQueryParameter("includeMetadata", "true")
      .apply { if (!cursor.isNullOrEmpty()) addQueryParameter("cursor", cursor) }
      .build()
      .toString()
  }

  companion object {
    /** Tope de paginas, por si `nextCursor` nunca dejara de venir. */
    const val PAGINAS_MAXIMAS = 30

    const val LIBRARY_BASE = "https://library-service.live.use1a.on.epicgames.com"
    const val LIBRARY_URL = "$LIBRARY_BASE/library/api/public/items"
    const val CATALOG_BASE = "https://catalog-public-service-prod06.ol.epicgames.com"

    /**
     * Orden por nombre sensible al idioma.
     *
     * Es el equivalente de `localizedStandardCompare`: sin el, "Ángel" caeria
     * despues de "Zelda" por comparacion de puntos de codigo.
     */
    private val COLLATOR: Collator = Collator.getInstance(Locale.getDefault()).apply {
      strength = Collator.PRIMARY
    }

    /**
     * Junta los artefactos por juego y les asigna su tiempo.
     *
     * El tiempo es el **mayor** de sus artefactos, no la suma: Epic repite las
     * mismas horas bajo varios ids del mismo juego, y sumarlas las duplicaria.
     */
    fun agrupar(
      registros: List<EpicLibraryRecordDTO>,
      tiempos: Map<String, Double>,
    ): Map<String, Grupo> {
      val porNamespace = mutableMapOf<String, Grupo>()

      registros.forEach { registro ->
        val horas = registro.appName?.let { tiempos[it] } ?: 0.0
        val actual = porNamespace[registro.namespace]

        porNamespace[registro.namespace] = if (actual == null) {
          Grupo(
            namespace = registro.namespace,
            nombre = registro.sandboxName.orEmpty(),
            horas = horas,
            catalogItemID = registro.catalogItemId,
          )
        } else {
          actual.copy(
            horas = maxOf(actual.horas, horas),
            nombre = if (!actual.tieneNombre && registro.tieneNombreUtil) {
              registro.sandboxName ?: actual.nombre
            } else {
              actual.nombre
            },
            catalogItemID = actual.catalogItemID ?: registro.catalogItemId,
          )
        }
      }

      return porNamespace
    }
  }
}
