//
//  KeychainTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

@Suite("Keychain: guardar y leer")
struct KeychainStoreTests {

  /// Cada prueba usa su propio "service" para no pisar ni el llavero real de la
  /// app ni el de otra prueba que corra a la vez.
  private func store() -> KeychainStore {
    KeychainStore(service: "com.juliancontreras.GameShelf.pruebas.\(UUID().uuidString)")
  }

  @Test("Guarda un valor y lo vuelve a leer")
  func guardarYLeer() throws {
    let llavero = store()

    try llavero.set("un-token-secreto", for: "prueba")

    #expect(try llavero.string(for: "prueba") == "un-token-secreto")
    try llavero.remove(for: "prueba")
  }

  @Test("Lo que no existe devuelve nil, no un error")
  func noExiste() throws {
    #expect(try store().string(for: "nunca-guardado") == nil)
  }

  @Test("Guardar dos veces reemplaza, no duplica")
  func reemplaza() throws {
    let llavero = store()

    try llavero.set("viejo", for: "prueba")
    try llavero.set("nuevo", for: "prueba")

    #expect(try llavero.string(for: "prueba") == "nuevo")
    try llavero.remove(for: "prueba")
  }

  @Test("Borrar lo quita")
  func borrar() throws {
    let llavero = store()
    try llavero.set("algo", for: "prueba")

    try llavero.remove(for: "prueba")

    #expect(try llavero.string(for: "prueba") == nil)
  }

  @Test("Borrar algo que no existe no falla")
  func borrarLoQueNoExiste() throws {
    // El resultado buscado (que no este) ya se cumple.
    try store().remove(for: "nunca-guardado")
  }

  @Test("Dos claves distintas no se pisan")
  func clavesIndependientes() throws {
    let llavero = store()

    try llavero.set("uno", for: "a")
    try llavero.set("dos", for: "b")

    #expect(try llavero.string(for: "a") == "uno")
    #expect(try llavero.string(for: "b") == "dos")

    try llavero.remove(for: "a")
    try llavero.remove(for: "b")
  }

  @Test("Sobrevive a caracteres raros y a textos largos")
  func textosDificiles() throws {
    let llavero = store()
    // Los JWT de Sony son largos y llevan puntos y guiones.
    let valor = String(repeating: "eyJhbGciOiJ.-_", count: 200) + " ñáü 🎮"

    try llavero.set(valor, for: "prueba")

    #expect(try llavero.string(for: "prueba") == valor)
    try llavero.remove(for: "prueba")
  }
}

@Suite("Keychain: doble en memoria")
struct InMemoryKeychainTests {

  @Test("Se comporta igual que el de verdad")
  func mismoComportamiento() throws {
    let llavero = InMemoryKeychainStore()

    #expect(try llavero.string(for: "x") == nil)

    try llavero.set("uno", for: "x")
    #expect(try llavero.string(for: "x") == "uno")

    try llavero.set("dos", for: "x")
    #expect(try llavero.string(for: "x") == "dos")

    try llavero.remove(for: "x")
    #expect(try llavero.string(for: "x") == nil)

    try llavero.remove(for: "x")
  }
}
