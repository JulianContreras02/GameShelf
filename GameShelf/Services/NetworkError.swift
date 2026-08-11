//
//  NetworkError.swift
//  GameShelf
//

import Foundation

/// Lo que puede salir mal al pedir datos a una API.
///
/// Los mensajes estan pensados para mostrarse tal cual al usuario: en vez de
/// "Error -1009" dicen que paso y, cuando aplica, que puede hacer.
enum NetworkError: LocalizedError, Equatable {

  /// No hay internet, o el servidor no responde.
  case noConnection

  /// La respuesta no es HTTP, o llego vacia cuando no debia.
  case invalidResponse

  /// El servidor respondio con un codigo fuera del rango 200-299.
  case httpError(statusCode: Int)

  /// Llegaron datos, pero no tienen la forma que esperabamos.
  ///
  /// Casi siempre significa que la API cambio su formato, no que el usuario
  /// hizo algo mal.
  case decodingFailed(description: String)

  /// La URL no se pudo construir. Es un error de programacion, no del usuario.
  case invalidURL(String)

  var errorDescription: String? {
    switch self {
    case .noConnection:
      "No hay conexion a internet."
    case .invalidResponse:
      "El servidor respondio de una forma inesperada."
    case .httpError(let statusCode):
      "El servidor respondio con el codigo \(statusCode)."
    case .decodingFailed:
      "Los datos que llegaron no tienen el formato esperado."
    case .invalidURL(let url):
      "La direccion no es valida: \(url)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .noConnection:
      "Revisa tu conexion y vuelve a intentar."
    case .httpError(let statusCode) where statusCode == 401 || statusCode == 403:
      "Revisa que tu API key sea correcta y siga vigente."
    case .httpError(let statusCode) where statusCode == 429:
      "Hiciste demasiadas peticiones seguidas. Espera un momento."
    case .httpError(let statusCode) where (500...599).contains(statusCode):
      "El problema es del servidor. Intenta mas tarde."
    case .invalidResponse, .httpError, .decodingFailed, .invalidURL:
      nil
    }
  }

  /// Si vale la pena reintentar automaticamente.
  ///
  /// Un 404 o un JSON mal formado no se arreglan reintentando; una caida de red
  /// o un 503 si.
  var isRetryable: Bool {
    switch self {
    case .noConnection:
      true
    case .httpError(let statusCode):
      statusCode == 429 || (500...599).contains(statusCode)
    case .invalidResponse, .decodingFailed, .invalidURL:
      false
    }
  }
}
