package com.gameshelf.data.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit

/**
 * Trae datos de una URL y los convierte al tipo que se le pida.
 *
 * Es una interfaz, no una clase, para que los servicios dependan de esta forma
 * y no de OkHttp. En las pruebas se inyecta un doble que devuelve respuestas
 * fijas, sin tocar la red.
 *
 * No sabe nada de Steam, de juegos ni de ninguna API concreta: eso vive en los
 * servicios que la usan.
 *
 * A diferencia de la version de iOS, el tipo a decodificar se pasa como
 * `DeserializationStrategy` en vez de como `T.Type`: kotlinx.serialization
 * necesita el serializador, y los genericos con `reified` no se pueden
 * declarar en una interfaz. Los atajos `getAs`/`postAs` de abajo devuelven la
 * comodidad de escribir solo el tipo.
 */
interface HttpClient {

  /**
   * Pide los datos de [url] y los decodifica.
   *
   * @param headers Cabeceras extra. Hacen falta para las APIs que piden un
   *   token de sesion, como la de PlayStation.
   * @throws NetworkError con el motivo del fallo.
   */
  suspend fun <T> get(
    url: String,
    serializer: DeserializationStrategy<T>,
    headers: Map<String, String> = emptyMap(),
  ): T

  /**
   * Manda [jsonBody] a [url] y decodifica la respuesta.
   *
   * Hace falta porque hay APIs que solo aceptan consultas en lote por POST:
   * IsThereAnyDeal, por ejemplo, recibe la lista de juegos en el cuerpo. Pedir
   * uno por uno con GET seria una peticion por juego.
   *
   * @throws NetworkError con el motivo del fallo.
   */
  suspend fun <T> post(
    url: String,
    jsonBody: String,
    serializer: DeserializationStrategy<T>,
    headers: Map<String, String> = emptyMap(),
  ): T
}

/** Atajo para no tener que nombrar el serializador cuando el tipo ya lo dice. */
suspend inline fun <reified T> HttpClient.getAs(
  url: String,
  headers: Map<String, String> = emptyMap(),
): T = get(url, GameShelfJson.serializersModule.serializer(), headers)

/** Configuracion de JSON compartida por toda la app. */
val GameShelfJson: Json = Json {
  // Las APIs de tienda agregan campos sin avisar. Ignorarlos es la diferencia
  // entre que la app siga funcionando y que reviente el dia que Steam agregue
  // una columna nueva.
  ignoreUnknownKeys = true
  coerceInputValues = true
  explicitNulls = false
}

/** Implementacion real, sobre OkHttp. */
class OkHttpNetworkClient(
  private val client: OkHttpClient = defaultClient(),
  private val json: Json = GameShelfJson,
) : HttpClient {

  override suspend fun <T> get(
    url: String,
    serializer: DeserializationStrategy<T>,
    headers: Map<String, String>,
  ): T {
    val peticion = Request.Builder()
      .url(url)
      .get()
      .apply { headers.forEach { (clave, valor) -> header(clave, valor) } }
      .build()

    return enviar(peticion, serializer)
  }

  override suspend fun <T> post(
    url: String,
    jsonBody: String,
    serializer: DeserializationStrategy<T>,
    headers: Map<String, String>,
  ): T {
    val peticion = Request.Builder()
      .url(url)
      .post(jsonBody.toRequestBody(JSON_MEDIA_TYPE))
      .apply { headers.forEach { (clave, valor) -> header(clave, valor) } }
      .build()

    return enviar(peticion, serializer)
  }

  /** Lo comun a GET y POST: mandar, traducir errores y decodificar. */
  private suspend fun <T> enviar(peticion: Request, serializer: DeserializationStrategy<T>): T =
    withContext(Dispatchers.IO) {
      val cuerpo = try {
        client.newCall(peticion).execute().use { respuesta ->
          if (!respuesta.isSuccessful) {
            throw NetworkError.HttpError(respuesta.code)
          }
          respuesta.body?.string() ?: throw NetworkError.InvalidResponse
        }
      } catch (e: NetworkError) {
        throw e
      } catch (e: UnknownHostException) {
        // Se traducen los errores de red a los nuestros para que las capas de
        // arriba no tengan que conocer las excepciones de OkHttp.
        throw NetworkError.NoConnection
      } catch (e: SocketTimeoutException) {
        throw NetworkError.NoConnection
      } catch (e: IOException) {
        throw NetworkError.NoConnection
      }

      try {
        json.decodeFromString(serializer, cuerpo)
      } catch (e: SerializationException) {
        // El mensaje por defecto no siempre dice que campo estaba mal, pero es
        // lo unico que hay para depurar un cambio de formato en una API ajena.
        throw NetworkError.DecodingFailed(e.message ?: "formato inesperado")
      } catch (e: IllegalArgumentException) {
        throw NetworkError.DecodingFailed(e.message ?: "formato inesperado")
      }
    }

  companion object {
    private val JSON_MEDIA_TYPE = "application/json".toMediaType()

    fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
      .connectTimeout(15, TimeUnit.SECONDS)
      .readTimeout(30, TimeUnit.SECONDS)
      .build()
  }
}

/**
 * La URL con la API key oculta, para poder registrarla sin filtrar el secreto.
 *
 * La Steam Web API recibe la key como parametro de consulta, asi que la URL
 * completa **es** informacion sensible y nunca debe imprimirse tal cual.
 */
fun String.redactingSecrets(): String {
  val url = this.toHttpUrlOrNull() ?: return this

  val sensibles = setOf("key", "steamid", "access_token", "token")
  val builder = url.newBuilder()

  url.queryParameterNames.forEach { nombre ->
    if (nombre.lowercase() in sensibles) {
      builder.removeAllQueryParameters(nombre)
      builder.addQueryParameter(nombre, "***")
    }
  }

  return builder.build().toString()
}
