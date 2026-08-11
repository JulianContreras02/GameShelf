//
//  SteamDTOTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

@Suite("DTOs de Steam - respuesta real")
struct SteamOwnedGamesDTOTests {

  private func cargarBiblioteca() throws -> SteamOwnedGamesPayload {
    try Fixture.decode(SteamOwnedGamesResponse.self, from: "steam_owned_games").response
  }

  @Test("Decodifica la respuesta guardada sin error")
  func decodificaRespuestaReal() throws {
    let payload = try cargarBiblioteca()

    #expect(payload.count == 4)
    #expect(payload.games.count == 4)
    #expect(payload.isEmpty == false)
  }

  @Test("Lee los campos de un juego completo")
  func camposDeUnJuego() throws {
    let payload = try cargarBiblioteca()
    let tf2 = try #require(payload.games.first { $0.appID == 440 })

    #expect(tf2.name == "Team Fortress 2")
    #expect(tf2.playtimeMinutes == 1234)
    #expect(tf2.iconHash == "e3f595a92552da3d664ad00277fad2107345f743")
  }

  @Test("Convierte minutos a horas, que es la unidad que usa la app")
  func minutosAHoras() throws {
    let payload = try cargarBiblioteca()

    let tf2 = try #require(payload.games.first { $0.appID == 440 })
    // 1234 minutos = 20.5666... horas
    #expect(abs(tf2.playtimeHours - 20.5667) < 0.001)

    let hollowKnight = try #require(payload.games.first { $0.appID == 367520 })
    #expect(hollowKnight.playtimeHours == 1.5, "90 minutos son exactamente 1.5 horas")
  }

  @Test("Un juego sin nombre no rompe la decodificacion")
  func juegoSinNombre() throws {
    // El appid 1245620 viene sin name, sin img_icon_url y sin rtime_last_played.
    // Pasa cuando se consulta sin include_appinfo=1.
    let payload = try cargarBiblioteca()
    let incompleto = try #require(payload.games.first { $0.appID == 1245620 })

    #expect(incompleto.name == nil)
    #expect(incompleto.iconHash == nil)
    #expect(incompleto.playtimeMinutes == 45)
    #expect(incompleto.lastPlayed == nil)
  }

  @Test("Nunca jugado se traduce a nil, no a 1970")
  func nuncaJugado() throws {
    let payload = try cargarBiblioteca()
    let stardew = try #require(payload.games.first { $0.appID == 413150 })

    #expect(stardew.playtimeMinutes == 0)
    #expect(
      stardew.lastPlayed == nil,
      "rtime_last_played 0 significa nunca, no el 1 de enero de 1970"
    )
  }

  @Test("Una fecha real se convierte bien")
  func fechaRealSeConvierte() throws {
    let payload = try cargarBiblioteca()
    let tf2 = try #require(payload.games.first { $0.appID == 440 })
    let fecha = try #require(tf2.lastPlayed)

    #expect(fecha == Date(timeIntervalSince1970: 1_719_878_400))
  }
}

@Suite("DTOs de Steam - casos borde")
struct SteamDTOEdgeCaseTests {

  @Test("Perfil privado o biblioteca vacia no es un error")
  func bibliotecaVacia() throws {
    let payload = try Fixture
      .decode(SteamOwnedGamesResponse.self, from: "steam_empty_library")
      .response

    #expect(payload.isEmpty)
    #expect(payload.count == 0)
    #expect(payload.games.isEmpty)
  }

  @Test("Faltar 'games' da lista vacia, no un fallo")
  func sinCampoGames() throws {
    let json = #"{"response": {"game_count": 0}}"#
    let payload = try JSONDecoder()
      .decode(SteamOwnedGamesResponse.self, from: Data(json.utf8))
      .response

    #expect(payload.games.isEmpty)
    #expect(payload.count == 0)
  }

  @Test("Un JSON sin la envoltura 'response' si debe fallar")
  func sinEnvoltura() {
    let json = #"{"game_count": 1, "games": []}"#

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(SteamOwnedGamesResponse.self, from: Data(json.utf8))
    }
  }

  @Test("Faltar 'appid' si debe fallar: sin el no se puede identificar el juego")
  func sinAppID() {
    let json = #"{"response": {"games": [{"name": "Sin ID"}]}}"#

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(SteamOwnedGamesResponse.self, from: Data(json.utf8))
    }
  }
}

@Suite("DTOs de Steam - URLs construidas")
struct SteamDTOURLTests {

  private func cargarBiblioteca() throws -> SteamOwnedGamesPayload {
    try Fixture.decode(SteamOwnedGamesResponse.self, from: "steam_owned_games").response
  }

  @Test("La caratula se arma a partir del appID")
  func caratula() throws {
    let tf2 = try #require(cargarBiblioteca().games.first { $0.appID == 440 })

    #expect(
      tf2.coverURL?.absoluteString
        == "https://cdn.cloudflare.steamstatic.com/steam/apps/440/header.jpg"
    )
  }

  @Test("El icono usa el hash que manda Steam")
  func icono() throws {
    let tf2 = try #require(cargarBiblioteca().games.first { $0.appID == 440 })
    let url = try #require(tf2.iconURL?.absoluteString)

    #expect(url.contains("/440/"))
    #expect(url.hasSuffix("e3f595a92552da3d664ad00277fad2107345f743.jpg"))
  }

  @Test("Sin hash de icono no se inventa una URL rota")
  func iconoAusente() throws {
    let juegos = try cargarBiblioteca().games

    // Cadena vacia
    let stardew = try #require(juegos.first { $0.appID == 413150 })
    #expect(stardew.iconURL == nil)

    // Campo ausente
    let incompleto = try #require(juegos.first { $0.appID == 1245620 })
    #expect(incompleto.iconURL == nil)
  }

  @Test("La ficha de la tienda apunta al appID correcto")
  func fichaDeTienda() throws {
    let hollowKnight = try #require(cargarBiblioteca().games.first { $0.appID == 367520 })

    #expect(
      hollowKnight.storeURL?.absoluteString
        == "https://store.steampowered.com/app/367520"
    )
  }
}
