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
      String(localized: "No hay conexion a internet.", comment: "Error de red")
    case .invalidResponse:
      String(localized: "El servidor respondio de una forma inesperada.", comment: "Error de red")
    case .httpError(let statusCode):
      String(localized: "El servidor respondio con el codigo \(statusCode).", comment: "Error de red")
    case .decodingFailed:
      String(localized: "Los datos que llegaron no tienen el formato esperado.", comment: "Error de red")
    case .invalidURL(let url):
      String(localized: "La direccion no es valida: \(url)", comment: "Error de red")
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .noConnection:
      String(localized: "Revisa tu conexion y vuelve a intentar.", comment: "Como recuperarse de un error")
    case .httpError(let statusCode) where statusCode == 401 || statusCode == 403:
      String(localized: "Revisa que tu API key sea correcta y siga vigente.", comment: "Como recuperarse de un error")
    case .httpError(let statusCode) where statusCode == 429:
      String(
        localized: "Hiciste demasiadas peticiones seguidas. Espera un momento.",
        comment: "Como recuperarse de un error"
      )
    case .httpError(let statusCode) where (500...599).contains(statusCode):
      String(localized: "El problema es del servidor. Intenta mas tarde.", comment: "Como recuperarse de un error")
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
