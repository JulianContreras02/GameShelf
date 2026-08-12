package com.gameshelf.data.net

import android.content.Context
import com.gameshelf.R

/**
 * Lo que puede salir mal al pedir datos a una API.
 *
 * Los mensajes estan pensados para mostrarse tal cual al usuario: en vez de
 * "Error -1009" dicen que paso y, cuando aplica, que puede hacer.
 */
sealed class NetworkError : Exception(), UserFacingError {

  /** No hay internet, o el servidor no responde. */
  data object NoConnection : NetworkError()

  /** La respuesta no es HTTP, o llego vacia cuando no debia. */
  data object InvalidResponse : NetworkError()

  /** El servidor respondio con un codigo fuera del rango 200-299. */
  data class HttpError(val statusCode: Int) : NetworkError()

  /**
   * Llegaron datos, pero no tienen la forma que esperabamos.
   *
   * Casi siempre significa que la API cambio su formato, no que el usuario
   * hizo algo mal.
   */
  data class DecodingFailed(val description: String) : NetworkError()

  /** La URL no se pudo construir. Es un error de programacion, no del usuario. */
  data class InvalidURL(val url: String) : NetworkError()

  override fun message(context: Context): String = when (this) {
    NoConnection -> context.getString(R.string.error_no_connection)
    InvalidResponse -> context.getString(R.string.error_invalid_response)
    is HttpError -> context.getString(R.string.error_http, statusCode)
    is DecodingFailed -> context.getString(R.string.error_decoding)
    is InvalidURL -> context.getString(R.string.error_invalid_url, url)
  }

  override fun recovery(context: Context): String? = when {
    this is NoConnection -> context.getString(R.string.recovery_check_connection)
    this is HttpError && (statusCode == 401 || statusCode == 403) ->
      context.getString(R.string.recovery_check_api_key)
    this is HttpError && statusCode == 429 -> context.getString(R.string.recovery_too_many_requests)
    this is HttpError && statusCode in 500..599 -> context.getString(R.string.recovery_server_problem)
    else -> null
  }

  /**
   * Si vale la pena reintentar automaticamente.
   *
   * Un 404 o un JSON mal formado no se arreglan reintentando; una caida de red
   * o un 503 si.
   */
  val isRetryable: Boolean
    get() = when (this) {
      NoConnection -> true
      is HttpError -> statusCode == 429 || statusCode in 500..599
      InvalidResponse, is DecodingFailed, is InvalidURL -> false
    }

  // `message` de Throwable se sobreescribe para que los volcados de pila digan
  // algo util. El texto para el usuario sigue saliendo de `message(context)`.
  override val message: String
    get() = when (this) {
      NoConnection -> "Sin conexion"
      InvalidResponse -> "Respuesta invalida"
      is HttpError -> "HTTP $statusCode"
      is DecodingFailed -> "Fallo al decodificar: $description"
      is InvalidURL -> "URL invalida: $url"
    }
}
