//
//  SteamPresenceTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

// Los tres `steam_presencia_*.json` estan escritos a mano con la forma que
// documenta Valve para GetPlayerSummaries, con datos de mentira: no se
// grabaron de una cuenta real. `scripts/explorar-presencia-steam.sh` graba
// las de verdad para compararlas.

/// La misma cuenta de los archivos de apoyo.
private let cuenta = "76561198000000000"

private func presencia(_ archivo: String) throws -> SteamPresence {
  SteamPresence(try Fixture.decode(SteamPlayerSummariesResponse.self, from: archivo), steamID: cuenta)
}

private func presencia(json: String) throws -> SteamPresence {
  let respuesta = try JSONDecoder().decode(SteamPlayerSummariesResponse.self, from: Data(json.utf8))
  return SteamPresence(respuesta, steamID: cuenta)
}

@Suite("Steam: presencia")
struct SteamPresenceMappingTests {

  @Test("Jugando: dice a que juego, con su appid")
  func jugando() throws {
    #expect(try presencia("steam_presencia_jugando") == .playing(appID: 1_145_360, name: "Hades"))
  }

  @Test("Sin jugar: el perfil es publico y no trae juego en curso")
  func sinJugar() throws {
    let resultado = try presencia("steam_presencia_sin_jugar")

    #expect(resultado == .notPlaying)
    #expect(!resultado.isPlaying)
  }

  @Test("Perfil privado: no se sabe, que no es lo mismo que no estar jugando")
  func perfilPrivado() throws {
    #expect(try presencia("steam_presencia_privada") == .unavailable)
  }

  @Test("Si el campo del juego no viene, no esta jugando")
  func sinCampo() throws {
    let json = #"{"response": {"players": [{"steamid": "76561198000000000", "communityvisibilitystate": 3}]}}"#

    #expect(try presencia(json: json) == .notPlaying)
  }

  @Test("Un campo vacio cuenta como si no viniera")
  func campoVacio() throws {
    let json = """
      {"response": {"players": [
        {"steamid": "76561198000000000", "communityvisibilitystate": 3, "gameid": "", "gameextrainfo": ""}
      ]}}
      """

    #expect(try presencia(json: json) == .notPlaying)
  }

  @Test("Un juego de fuera de la tienda llega con nombre pero sin appid")
  func juegoDeFuera() throws {
    // Steam arma un id de 64 bits para los juegos agregados a mano a la
    // biblioteca. No es un appid: no corresponde a nada en la tienda.
    let json = """
      {"response": {"players": [
        {"steamid": "76561198000000000", "communityvisibilitystate": 3,
          "gameid": "13280471429706432512", "gameextrainfo": "Minecraft"}
      ]}}
      """

    #expect(try presencia(json: json) == .playing(appID: nil, name: "Minecraft"))
  }

  @Test("Si Steam manda el juego, gana aunque el perfil no diga que es publico")
  func juegoSinVisibilidad() throws {
    let json = #"{"response": {"players": [{"steamid": "76561198000000000", "gameid": "730"}]}}"#

    #expect(try presencia(json: json) == .playing(appID: 730, name: nil))
  }

  @Test("Si Steam no encuentra la cuenta, no se sabe")
  func cuentaInexistente() throws {
    #expect(try presencia(json: #"{"response": {"players": []}}"#) == .unavailable)
    #expect(try presencia(json: #"{"response": {}}"#) == .unavailable)
  }

  @Test("Solo cuenta el perfil de la cuenta pedida")
  func otraCuenta() throws {
    let json = """
      {"response": {"players": [
        {"steamid": "76561198999999999", "communityvisibilitystate": 3, "gameid": "730"}
      ]}}
      """

    #expect(try presencia(json: json) == .unavailable)
  }

  @Test("Solo son appids los numeros de 32 bits mayores que cero")
  func appIDs() {
    #expect(SteamPresence.appID(desde: "1145360") == 1_145_360)
    #expect(SteamPresence.appID(desde: "0") == nil)
    #expect(SteamPresence.appID(desde: "13280471429706432512") == nil)
    #expect(SteamPresence.appID(desde: "abc") == nil)
  }
}

@Suite("Steam: peticion de presencia")
struct SteamPresenceRequestTests {

  private let credenciales = SteamService.Credentials(apiKey: "CLAVE_DE_PRUEBA", steamID: cuenta)

  private func servicio(_ client: HTTPClient) -> SteamService {
    SteamService(client: client, credentials: credenciales)
  }

  @Test("Pide GetPlayerSummaries de la cuenta conectada")
  func url() throws {
    let url = try servicio(StubHTTPClient(json: "{}")).playerSummariesURL()
    let componentes = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let parametros = Dictionary(uniqueKeysWithValues: (componentes.queryItems ?? []).map { ($0.name, $0.value) })

    #expect(componentes.host == "api.steampowered.com")
    #expect(componentes.path == "/ISteamUser/GetPlayerSummaries/v2/")
    #expect(parametros["key"] == "CLAVE_DE_PRUEBA")
    #expect(parametros["steamids"] == cuenta, "En plural: el endpoint admite varias cuentas")
    #expect(parametros["format"] == "json")
  }

  @Test("La URL registrable oculta la key y la cuenta")
  func urlSinSecretos() throws {
    let registrable = try servicio(StubHTTPClient(json: "{}")).playerSummariesURL().redactingSecrets

    #expect(!registrable.contains("CLAVE_DE_PRUEBA"))
    #expect(!registrable.contains(cuenta))
  }

  @Test("Trae la presencia de la respuesta")
  func trae() async throws {
    let cliente = StubHTTPClient(.success(try Fixture.data("steam_presencia_jugando")))

    let resultado = try await servicio(cliente).fetchPresence()

    #expect(resultado == .playing(appID: 1_145_360, name: "Hades"))
    #expect(cliente.requestedURLs.count == 1)
  }

  @Test("Un fallo de red se propaga tal cual")
  func falla() async {
    let cliente = StubHTTPClient(.failure(.httpError(statusCode: 403)))

    await #expect(throws: NetworkError.httpError(statusCode: 403)) {
      try await servicio(cliente).fetchPresence()
    }
  }
}
