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

    #expect(payload.count == 5)
    #expect(payload.games.count == 5)
    #expect(payload.isEmpty == false)
  }

  @Test("Lee los campos de un juego completo")
  func camposDeUnJuego() throws {
    let payload = try cargarBiblioteca()
    let juego = try #require(payload.games.first { $0.appID == 444090 })

    #expect(juego.name == "Juego Con Muchas Horas")
    #expect(juego.playtimeMinutes == 84270)
    #expect(juego.iconHash == "e3f595a92552da3d664ad00277fad2107345f743")
  }

  @Test("Convierte minutos a horas, que es la unidad que usa la app")
  func minutosAHoras() throws {
    let payload = try cargarBiblioteca()

    let juego = try #require(payload.games.first { $0.appID == 444090 })
    // 84270 minutos = 1404.5 horas
    #expect(abs(juego.playtimeHours - 1404.5) < 0.001)

    let corto = try #require(payload.games.first { $0.appID == 1245620 })
    #expect(corto.playtimeHours == 0.75, "45 minutos son exactamente 0.75 horas")
  }

  @Test("Campos extra que manda Steam no rompen la decodificacion")
  func camposExtraNoRompen() throws {
    // La respuesta real trae content_descriptorids, has_leaderboards y los
    // playtime_* por plataforma, que el DTO no modela a proposito.
    let payload = try cargarBiblioteca()

    #expect(payload.games.count == 5, "Los campos que ignoramos no deben estorbar")
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
    let nunca = try #require(payload.games.first { $0.appID == 34330 })

    #expect(nunca.playtimeMinutes == 0)
    #expect(
      nunca.lastPlayed == nil,
      "rtime_last_played 0 significa nunca, no el 1 de enero de 1970"
    )
  }

  @Test("Una fecha real se convierte bien")
  func fechaRealSeConvierte() throws {
    let payload = try cargarBiblioteca()
    let juego = try #require(payload.games.first { $0.appID == 444090 })
    let fecha = try #require(juego.lastPlayed)

    #expect(fecha == Date(timeIntervalSince1970: 1_739_079_369))
  }
}

@Suite("DTOs de Steam - actividad reciente")
struct SteamRecentPlaytimeTests {

  private func cargarBiblioteca() throws -> SteamOwnedGamesPayload {
    try Fixture.decode(SteamOwnedGamesResponse.self, from: "steam_owned_games").response
  }

  @Test("playtime_2weeks se lee cuando viene")
  func conActividadReciente() throws {
    let juego = try #require(cargarBiblioteca().games.first { $0.appID == 1174180 })

    #expect(juego.playtimeLast2WeeksMinutes == 320)
    #expect(abs(juego.playtimeLast2WeeksHours - 5.3333) < 0.001)
    #expect(juego.isRecentlyPlayed)
  }

  @Test("Sin playtime_2weeks el juego no cuenta como reciente")
  func sinActividadReciente() throws {
    // Steam omite el campo cuando no hubo actividad: en la biblioteca real
    // solo venia en 2 de 118 juegos.
    let juego = try #require(cargarBiblioteca().games.first { $0.appID == 444090 })

    #expect(juego.playtimeLast2WeeksMinutes == nil)
    #expect(juego.playtimeLast2WeeksHours == 0)
    #expect(juego.isRecentlyPlayed == false)
  }

  @Test("Solo los juegos con actividad aparecen como recientes")
  func soloLosRecientes() throws {
    let recientes = try cargarBiblioteca().games.filter(\.isRecentlyPlayed)

    #expect(recientes.map(\.appID) == [1174180])
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
    let juego = try #require(cargarBiblioteca().games.first { $0.appID == 444090 })

    #expect(
      juego.coverURL?.absoluteString
        == "https://cdn.cloudflare.steamstatic.com/steam/apps/444090/header.jpg"
    )
  }

  @Test("El icono usa el hash que manda Steam")
  func icono() throws {
    let juego = try #require(cargarBiblioteca().games.first { $0.appID == 444090 })
    let url = try #require(juego.iconURL?.absoluteString)

    #expect(url.contains("/444090/"))
    #expect(url.hasSuffix("e3f595a92552da3d664ad00277fad2107345f743.jpg"))
  }

  @Test("Sin hash de icono no se inventa una URL rota")
  func iconoAusente() throws {
    let juegos = try cargarBiblioteca().games

    // Cadena vacia
    let sinIcono = try #require(juegos.first { $0.appID == 34330 })
    #expect(sinIcono.iconURL == nil)

    // Campo ausente
    let incompleto = try #require(juegos.first { $0.appID == 1245620 })
    #expect(incompleto.iconURL == nil)
  }

  @Test("La ficha de la tienda apunta al appID correcto")
  func fichaDeTienda() throws {
    let juego = try #require(cargarBiblioteca().games.first { $0.appID == 322170 })

    #expect(
      juego.storeURL?.absoluteString
        == "https://store.steampowered.com/app/322170"
    )
  }
}
