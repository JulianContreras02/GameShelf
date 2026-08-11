//
//  HTTPClientTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Tipo de juguete para no depender de ningun modelo real del proyecto.
private struct Juego: Decodable, Equatable {
  let id: Int
  let nombre: String
}

@Suite("Cliente HTTP (con doble)")
struct HTTPClientTests {

  private let url = URL(string: "https://api.ejemplo.com/juegos")!

  @Test("Decodifica una respuesta correcta")
  func respuestaCorrecta() async throws {
    let client = StubHTTPClient(json: #"{"id": 1, "nombre": "Hollow Knight"}"#)

    let juego = try await client.get(Juego.self, from: url)

    #expect(juego == Juego(id: 1, nombre: "Hollow Knight"))
  }

  @Test("Un JSON malformado da error de decodificacion, no un crash")
  func jsonMalformado() async {
    let client = StubHTTPClient(json: "{ esto no es json valido")

    await #expect(throws: NetworkError.self) {
      try await client.get(Juego.self, from: url)
    }
  }

  @Test("Un JSON valido pero con la forma equivocada tambien falla")
  func jsonConFormaEquivocada() async {
    // Es JSON valido, pero le falta 'nombre'
    let client = StubHTTPClient(json: #"{"id": 1}"#)

    await #expect(throws: NetworkError.self) {
      try await client.get(Juego.self, from: url)
    }
  }

  @Test("Un error de red se propaga tal cual")
  func errorDeRed() async throws {
    let client = StubHTTPClient(.failure(.noConnection))

    let error = await #expect(throws: NetworkError.self) {
      try await client.get(Juego.self, from: url)
    }

    #expect(error == .noConnection)
  }

  @Test("Un error HTTP conserva su codigo")
  func errorHTTP() async throws {
    let client = StubHTTPClient(.failure(.httpError(statusCode: 503)))

    let error = await #expect(throws: NetworkError.self) {
      try await client.get(Juego.self, from: url)
    }

    #expect(error == .httpError(statusCode: 503))
  }

  @Test("Registra la URL que se pidio")
  func registraLaURL() async throws {
    let client = StubHTTPClient(json: #"{"id": 1, "nombre": "Celeste"}"#)

    _ = try await client.get(Juego.self, from: url)

    #expect(client.requestedURLs == [url])
  }
}

@Suite("NetworkError")
struct NetworkErrorTests {

  @Test("Todos los casos tienen un mensaje para el usuario")
  func todosTienenMensaje() {
    let casos: [NetworkError] = [
      .noConnection,
      .invalidResponse,
      .httpError(statusCode: 500),
      .decodingFailed(description: "x"),
      .invalidURL("http://")
    ]

    for caso in casos {
      #expect(caso.errorDescription?.isEmpty == false, "Falta mensaje en \(caso)")
    }
  }

  @Test(
    "Solo se reintenta lo que puede mejorar solo",
    arguments: [
      (NetworkError.noConnection, true),
      (.httpError(statusCode: 429), true),
      (.httpError(statusCode: 503), true),
      (.httpError(statusCode: 404), false),
      (.httpError(statusCode: 401), false),
      (.decodingFailed(description: "x"), false),
      (.invalidResponse, false)
    ]
  )
  func reintentoSoloCuandoTieneSentido(caso: NetworkError, esperado: Bool) {
    #expect(caso.isRetryable == esperado)
  }

  @Test("Un 401 sugiere revisar la API key")
  func sugerenciaParaCredenciales() {
    let sugerencia = NetworkError.httpError(statusCode: 401).recoverySuggestion
    #expect(sugerencia?.contains("API key") == true)
  }
}
