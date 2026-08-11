//
//  GameDetailTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

@Suite("Enlace a la tienda")
struct StoreLinkTests {

  @Test("Con una sola tienda devuelve su enlace")
  func unaTienda() throws {
    let game = Game(name: "Juego")
    game.storeEntries = [
      StoreEntry(
        store: .steam,
        storeGameID: "440",
        storeURL: "https://store.steampowered.com/app/440"
      )
    ]

    #expect(game.storeLink()?.absoluteString == "https://store.steampowered.com/app/440")
  }

  @Test("Con varias tiendas se puede pedir una en concreto")
  func prefiereUnaTienda() throws {
    let game = Game(name: "Juego")
    game.storeEntries = [
      StoreEntry(store: .steam, storeGameID: "1", storeURL: "https://steam.example/1"),
      StoreEntry(store: .psn, storeGameID: "2", storeURL: "https://psn.example/2")
    ]

    #expect(game.storeLink(preferring: .psn)?.absoluteString == "https://psn.example/2")
    #expect(game.storeLink(preferring: .steam)?.absoluteString == "https://steam.example/1")
  }

  @Test("Si la tienda pedida no tiene enlace, usa otra que si")
  func recurreAOtraTienda() throws {
    let game = Game(name: "Juego")
    game.storeEntries = [
      StoreEntry(store: .steam, storeGameID: "1", storeURL: "https://steam.example/1")
    ]

    #expect(game.storeLink(preferring: .epic)?.absoluteString == "https://steam.example/1")
  }

  @Test("Sin enlaces devuelve nil en vez de una URL rota")
  func sinEnlaces() {
    let game = Game(name: "Juego")
    game.storeEntries = [StoreEntry(store: .steam, storeGameID: "1", storeURL: nil)]

    #expect(game.storeLink() == nil)
  }

  @Test("Un enlace vacio no cuenta como enlace")
  func enlaceVacio() {
    let game = Game(name: "Juego")
    game.storeEntries = [StoreEntry(store: .steam, storeGameID: "1", storeURL: "")]

    #expect(game.storeLink() == nil)
  }

  @Test("Un juego sin tiendas no rompe")
  func sinTiendas() {
    #expect(Game(name: "Juego").storeLink() == nil)
  }
}

@Suite("Ultima vez jugado")
struct LastPlayedTests {

  @Test("Toma la fecha mas reciente entre todas las tiendas")
  func fechaMasReciente() throws {
    let game = Game(name: "Juego")
    let vieja = Date(timeIntervalSince1970: 1_600_000_000)
    let nueva = Date(timeIntervalSince1970: 1_700_000_000)

    game.storeEntries = [
      StoreEntry(store: .steam, storeGameID: "1", lastPlayedAt: vieja),
      StoreEntry(store: .psn, storeGameID: "2", lastPlayedAt: nueva)
    ]

    #expect(game.lastPlayedAt == nueva)
  }

  @Test("Sin fechas devuelve nil")
  func sinFechas() {
    let game = Game(name: "Juego")
    game.storeEntries = [StoreEntry(store: .steam, storeGameID: "1")]

    #expect(game.lastPlayedAt == nil)
  }

  @Test("Un juego sin horas se considera no jugado")
  func noJugado() {
    #expect(Game(name: "Juego").isUnplayed)
    #expect(Game(name: "Juego", playtimeHours: 0.5).isUnplayed == false)
  }
}

@Suite("Formato de la ultima partida")
struct LastPlayedFormatterTests {

  private let calendario = Calendar(identifier: .gregorian)
  private let ahora = Date(timeIntervalSince1970: 1_754_870_400)

  private func hace(dias: Int) -> Date {
    ahora.addingTimeInterval(TimeInterval(-dias * 86_400))
  }

  @Test("Nunca jugado no muestra una fecha inventada")
  func nunca() {
    #expect(LastPlayedFormatter.text(for: nil) == "Nunca")
  }

  @Test("Hoy y ayer se dicen con palabras")
  func hoyYAyer() {
    #expect(
      LastPlayedFormatter.text(for: ahora, relativeTo: ahora, calendar: calendario) == "Hoy"
    )
    #expect(
      LastPlayedFormatter.text(for: hace(dias: 1), relativeTo: ahora, calendar: calendario)
        == "Ayer"
    )
  }

  @Test("Hasta un mes se cuenta en dias")
  func enDias() {
    #expect(
      LastPlayedFormatter.text(for: hace(dias: 5), relativeTo: ahora, calendar: calendario)
        == "Hace 5 dias"
    )
    #expect(
      LastPlayedFormatter.text(for: hace(dias: 30), relativeTo: ahora, calendar: calendario)
        == "Hace 30 dias"
    )
  }

  @Test("Mas de un mes muestra la fecha, no 'hace 400 dias'")
  func fechaCompleta() {
    let texto = LastPlayedFormatter.text(
      for: hace(dias: 400),
      relativeTo: ahora,
      calendar: calendario,
      locale: Locale(identifier: "en_US")
    )

    #expect(texto.contains("2024"))
    #expect(!texto.contains("Hace"))
  }

  @Test("Una fecha futura no dice 'hace -2 dias'")
  func fechaFutura() {
    // Puede pasar si el reloj del equipo esta desajustado
    let manana = ahora.addingTimeInterval(2 * 86_400)

    let texto = LastPlayedFormatter.text(for: manana, relativeTo: ahora, calendar: calendario)

    #expect(!texto.contains("-"))
    #expect(texto == "Hoy")
  }
}
