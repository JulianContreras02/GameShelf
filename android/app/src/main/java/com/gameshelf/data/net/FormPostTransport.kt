package com.gameshelf.data.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.CookieJar
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit

/**
 * Manda formularios, que es como piden los tokens casi todos los OAuth.
 *
 * No se reusa [HttpClient] porque ese manda JSON, y estos endpoints esperan
 * `application/x-www-form-urlencoded`. Lo usan PSN y Epic.
 */
interface FormPostTransporting {
  /** Manda un formulario y devuelve la respuesta cruda como texto. */
  suspend fun postForm(campos: Map<String, String>, url: String, authorization: String): String
}

/** Lo que necesita el inicio de sesion de PSN, ademas del formulario. */
interface PSNAuthTransporting : FormPostTransporting {
  /**
   * Pide [url] con la cookie del NPSSO y devuelve a donde redirige, **sin ir**.
   *
   * El codigo de autorizacion viaja en esa redireccion. Si se sigue, se pierde.
   * Es propio de PSN: Epic entrega su codigo en una pagina normal.
   */
  suspend fun redirectLocation(url: String, npsso: String): String
}

/**
 * Implementacion real sobre OkHttp.
 *
 * Se usan dos clientes: uno normal para los formularios y otro que **no sigue
 * redirecciones** para el paso de autorizacion de PSN. Siguiendo esa
 * redireccion se perderia el codigo, porque el destino
 * (`com.scee.psxandroid.scecompcall://redirect`) es el esquema de otra app.
 *
 * Ninguno guarda cookies: el NPSSO se manda a mano en cada peticion y no debe
 * quedar en ningun almacen compartido.
 */
class OkHttpFormTransport(
  base: OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(15, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .cookieJar(CookieJar.NO_COOKIES)
    .build(),
) : PSNAuthTransporting {

  private val siguiendoRedirecciones = base
  private val sinSeguirRedirecciones = base.newBuilder()
    .followRedirects(false)
    .followSslRedirects(false)
    .build()

  override suspend fun redirectLocation(url: String, npsso: String): String =
    withContext(Dispatchers.IO) {
      val peticion = Request.Builder()
        .url(url)
        .header("Cookie", "npsso=$npsso")
        .get()
        .build()

      traducirFallosDeRed {
        sinSeguirRedirecciones.newCall(peticion).execute().use { respuesta ->
          if (respuesta.code !in 300..399) {
            // Sin redireccion no hay codigo que leer. Pasa si Sony cambia el flujo.
            throw RedirectMissingException("HTTP ${respuesta.code} sin redireccion")
          }
          respuesta.header("Location")
            ?: throw RedirectMissingException("Redireccion sin destino")
        }
      }
    }

  override suspend fun postForm(
    campos: Map<String, String>,
    url: String,
    authorization: String,
  ): String = withContext(Dispatchers.IO) {
    // Se ordenan las claves para que el cuerpo sea el mismo en cada ejecucion
    // y las pruebas puedan compararlo, igual que en iOS.
    val cuerpo = FormBody.Builder().apply {
      campos.keys.sorted().forEach { clave -> add(clave, campos[clave].orEmpty()) }
    }.build()

    val peticion = Request.Builder()
      .url(url)
      .header("Authorization", authorization)
      .post(cuerpo)
      .build()

    traducirFallosDeRed {
      // A diferencia del cliente JSON, aca **no** se mira el codigo de estado:
      // Sony y Epic devuelven el motivo del fallo en el cuerpo con un 400, y
      // ese cuerpo es justo lo que hay que leer para dar un mensaje util.
      siguiendoRedirecciones.newCall(peticion).execute().use { respuesta ->
        respuesta.body?.string() ?: throw NetworkError.InvalidResponse
      }
    }
  }

  private inline fun <T> traducirFallosDeRed(bloque: () -> T): T = try {
    bloque()
  } catch (e: UnknownHostException) {
    throw NetworkError.NoConnection
  } catch (e: SocketTimeoutException) {
    throw NetworkError.NoConnection
  } catch (e: IOException) {
    throw NetworkError.NoConnection
  }
}

/**
 * La redireccion que traia el codigo de autorizacion no llego.
 *
 * Va aparte de [NetworkError] porque quien la atrapa (el servicio de PSN) la
 * traduce a un error suyo con un mensaje que habla de PlayStation.
 */
class RedirectMissingException(val detalle: String) : Exception(detalle)
