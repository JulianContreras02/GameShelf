package com.gameshelf.data.psn

import com.gameshelf.data.net.HttpClient
import com.gameshelf.data.net.NetworkError
import com.gameshelf.domain.TrophyCounts
import kotlinx.serialization.DeserializationStrategy
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.time.Instant

/** Un juego de PlayStation, ya con todo lo que hace falta para guardarlo. */
data class PSNGame(
  /** Identificador en la tienda, del estilo `PPSA28038_00`. */
  val titleId: String,
  val name: String,
  val coverURL: String?,
  /** Horas jugadas. `null` si PSN mando una duracion que no se pudo leer. */
  val playtimeHours: Double?,
  /** Cuantas veces se ha abierto. */
  val playCount: Int?,
  val lastPlayedAt: Instant?,
  val firstPlayedAt: Instant?,
  /** Porcentaje de trofeos, de 0 a 100. `null` si el juego no tiene. */
  val trophyProgress: Int?,
  /** Cuantos trofeos se consiguieron, por tipo. */
  val earnedTrophies: TrophyCounts? = null,
  /** Cuantos tiene el juego en total, por tipo. */
  val definedTrophies: TrophyCounts? = null,
)

/**
 * Trae la biblioteca de PlayStation del usuario.
 *
 * Como el resto de PSN, es una **API no oficial**: va detras de una interfaz
 * para que un cambio de Sony no se extienda por toda la app.
 */
interface PSNLibraryServicing {
  /**
   * Trae los juegos jugados, con su progreso de trofeos.
   *
   * @throws PSNAuthError si la sesion ya no sirve.
   * @throws NetworkError si falla la peticion.
   */
  suspend fun fetchPlayedGames(): List<PSNGame>
}

/** Implementacion real contra los endpoints de PSN. */
class PSNLibraryService(
  private val client: HttpClient,
  /**
   * De donde sacar un token de acceso vigente.
   *
   * Es una funcion y no un texto porque el token dura una hora: pedirlo en el
   * momento deja que quien lo provea lo renueve si hace falta.
   */
  private val accessToken: suspend () -> String,
) : PSNLibraryServicing {

  override suspend fun fetchPlayedGames(): List<PSNGame> {
    val titulos = fetchTitles()
    if (titulos.isEmpty()) return emptyList()

    val trofeos = fetchTrophyProgress(titulos.map { it.titleId })

    return titulos.mapNotNull { titulo ->
      val nombre = titulo.nombre ?: return@mapNotNull null
      val progreso = trofeos[titulo.titleId]
      PSNGame(
        titleId = titulo.titleId,
        name = nombre,
        coverURL = titulo.coverURL,
        playtimeHours = titulo.playtimeHours,
        playCount = titulo.playCount,
        lastPlayedAt = titulo.lastPlayedAt,
        firstPlayedAt = titulo.firstPlayedAt,
        trophyProgress = progreso?.progress,
        earnedTrophies = progreso?.earnedTrophies?.counts,
        definedTrophies = progreso?.definedTrophies?.counts,
      )
    }
  }

  /**
   * Trae todas las paginas de la lista de juegos.
   *
   * Se dejan fuera las apps de video, que PSN mezcla con los juegos.
   */
  suspend fun fetchTitles(): List<PSNTitleDTO> {
    val todos = mutableListOf<PSNTitleDTO>()
    var offset = 0

    repeat(PAGINAS_MAXIMAS) {
      val respuesta = get(titlesURL(offset), PSNGameListResponse.serializer())
      todos += respuesta.juegos.filter { it.esJuego }

      val siguiente = respuesta.nextOffset
      if (siguiente == null || siguiente <= offset) return todos
      offset = siguiente
    }

    return todos
  }

  /**
   * Trae el progreso de trofeos de una lista de juegos, en tandas.
   *
   * @return Indexado por id de juego. Los que no tienen trofeos no aparecen.
   */
  suspend fun fetchTrophyProgress(titleIDs: List<String>): Map<String, PSNTrophyTitleDTO> {
    val resultado = mutableMapOf<String, PSNTrophyTitleDTO>()

    titleIDs.chunked(TAMANO_DE_TANDA_DE_TROFEOS).forEach { tanda ->
      val respuesta = get(trophyMapURL(tanda), PSNTrophyMapResponse.serializer())
      // Se indexa por id y no por posicion: la respuesta llega en otro orden
      // del que se pidio. Se comprobo con datos reales.
      respuesta.progresoPorTitleID.forEach { (clave, valor) ->
        resultado.putIfAbsent(clave, valor)
      }
    }

    return resultado
  }

  private suspend fun <T> get(url: String, serializer: DeserializationStrategy<T>): T = try {
    client.get(
      url,
      serializer,
      mapOf(
        "Authorization" to "Bearer ${accessToken()}",
        "Accept-Language" to "es-CO",
      ),
    )
  } catch (e: NetworkError.HttpError) {
    // El token dejo de servir a mitad de camino. Se traduce para que la
    // pantalla pueda pedir uno nuevo en vez de mostrar "error 401".
    if (e.statusCode == 401 || e.statusCode == 403) throw PSNAuthError.SesionExpirada else throw e
  }

  // --- URLs ----------------------------------------------------------------

  /** Arma la URL de la lista de juegos. */
  fun titlesURL(offset: Int = 0): String = buildURL("/gamelist/v2/users/me/titles") {
    addQueryParameter("limit", TAMANO_DE_PAGINA.toString())
    addQueryParameter("offset", offset.toString())
  }

  /** Arma la URL que relaciona juegos con sus trofeos. */
  fun trophyMapURL(titleIDs: List<String>): String =
    buildURL("/trophy/v1/users/me/titles/trophyTitles") {
      addQueryParameter("npTitleIds", titleIDs.joinToString(","))
    }

  private fun buildURL(ruta: String, bloque: okhttp3.HttpUrl.Builder.() -> Unit): String {
    val base = (BASE_URL + ruta).toHttpUrlOrNull() ?: throw NetworkError.InvalidURL(ruta)
    return base.newBuilder().apply(bloque).build().toString()
  }

  companion object {
    /** Cuantos juegos se piden por pagina. El maximo que acepta el endpoint. */
    const val TAMANO_DE_PAGINA = 200

    /**
     * Cuantos juegos se consultan por llamada al mapa de trofeos.
     *
     * Se comprobo que 5 funciona. Sony no documenta el limite y pasarse suele
     * devolver un error, asi que se deja en el valor verificado.
     */
    const val TAMANO_DE_TANDA_DE_TROFEOS = 5

    /**
     * Cuantas paginas como maximo, por si `nextOffset` nunca dejara de venir.
     *
     * Sin este tope, una respuesta rara colgaria la app en un bucle infinito.
     */
    const val PAGINAS_MAXIMAS = 20

    const val BASE_URL = "https://m.np.playstation.com/api"
  }
}
