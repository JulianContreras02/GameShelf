//
//  SteamServiceTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Credenciales de mentira: ninguna prueba sale a la red.
private let credencialesFalsas = SteamService.Credentials(
  apiKey: "CLAVE_DE_PRUEBA",
  steamID: "76561198000000000"
)

@Suite("SteamService - construccion de la URL")
struct SteamServiceURLTests {

  private func componentes() throws -> URLComponents {
    let service = SteamService(
      client: StubHTTPClient(json: "{}"),
      credentials: credencialesFalsas
    )
    let url = try service.ownedGamesURL()
    return try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
  }

  private func parametro(_ nombre: String) throws -> String? {
    try componentes().queryItems?.first { $0.name == nombre }?.value
  }

  @Test("Apunta al endpoint correcto de la Steam Web API")
  func endpointCorrecto() throws {
    let comps = try componentes()

    #expect(comps.scheme == "https")
    #expect(comps.host == "api.steampowered.com")
    #expect(comps.path == "/IPlayerService/GetOwnedGames/v1/")
  }

  @Test("Manda las credenciales que se le inyectaron")
  func mandaCredenciales() throws {
    #expect(try parametro("key") == "CLAVE_DE_PRUEBA")
    #expect(try parametro("steamid") == "76561198000000000")
  }

  @Test("include_appinfo=1: sin el, los juegos llegan sin nombre ni icono")
  func incluyeAppInfo() throws {
    #expect(try parametro("include_appinfo") == "1")
  }

  @Test("include_played_free_games=1: sin el se pierden los F2P jugados")
  func incluyeFreeToPlay() throws {
    // Verificado contra una biblioteca real: sin este parametro la respuesta
    // pasa de 118 a 88 juegos y de 2735 a 1220 horas, porque el juego mas
    // jugado era free-to-play.
    #expect(try parametro("include_played_free_games") == "1")
  }

  @Test("Pide la respuesta en JSON")
  func formatoJSON() throws {
    #expect(try parametro("format") == "json")
  }

  @Test("Una API key con caracteres raros se codifica bien")
  func codificaCaracteresEspeciales() throws {
    let service = SteamService(
      client: StubHTTPClient(json: "{}"),
      credentials: .init(apiKey: "clave con espacios&y=simbolos", steamID: "123")
    )

    let url = try service.ownedGamesURL()
    let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    // El valor se recupera intacto, y la URL cruda no rompe la separacion
    // de parametros
    #expect(comps.queryItems?.first { $0.name == "key" }?.value == "clave con espacios&y=simbolos")
    #expect(url.absoluteString.contains("clave%20con%20espacios"))
  }
}

@Suite("SteamService - traer la biblioteca")
struct SteamServiceFetchTests {

  @Test("Devuelve los juegos de una respuesta correcta")
  func trarBiblioteca() async throws {
    let json = try Fixture.data("steam_owned_games")
    let client = StubHTTPClient(.success(json))
    let service = SteamService(client: client, credentials: credencialesFalsas)

    let juegos = try await service.fetchOwnedGames()

    #expect(juegos.count == 5)
    #expect(juegos.contains { $0.appID == 444090 })
  }

  @Test("Una biblioteca vacia o un perfil privado dan lista vacia, no un error")
  func bibliotecaVacia() async throws {
    let json = try Fixture.data("steam_empty_library")
    let service = SteamService(
      client: StubHTTPClient(.success(json)),
      credentials: credencialesFalsas
    )

    let juegos = try await service.fetchOwnedGames()

    #expect(juegos.isEmpty)
  }

  @Test("Pide exactamente la URL que construye")
  func usaLaURLConstruida() async throws {
    let json = try Fixture.data("steam_owned_games")
    let client = StubHTTPClient(.success(json))
    let service = SteamService(client: client, credentials: credencialesFalsas)

    _ = try await service.fetchOwnedGames()

    #expect(client.requestedURLs.count == 1)
    #expect(client.requestedURLs.first == (try service.ownedGamesURL()))
  }

  @Test("Un error de red se propaga sin envolverlo en otra cosa")
  func propagaErrorDeRed() async throws {
    let service = SteamService(
      client: StubHTTPClient(.failure(.noConnection)),
      credentials: credencialesFalsas
    )

    let error = await #expect(throws: NetworkError.self) {
      try await service.fetchOwnedGames()
    }

    #expect(error == .noConnection)
  }

  @Test("Una API key rechazada llega como 403, no como error generico")
  func propagaErrorHTTP() async throws {
    let service = SteamService(
      client: StubHTTPClient(.failure(.httpError(statusCode: 403))),
      credentials: credencialesFalsas
    )

    let error = await #expect(throws: NetworkError.self) {
      try await service.fetchOwnedGames()
    }

    #expect(error == .httpError(statusCode: 403))
  }

  @Test("Una respuesta con basura da error de decodificacion")
  func respuestaCorrupta() async {
    let service = SteamService(
      client: StubHTTPClient(json: "no soy json"),
      credentials: credencialesFalsas
    )

    await #expect(throws: NetworkError.self) {
      try await service.fetchOwnedGames()
    }
  }
}

@Suite("SteamService - credenciales en el llavero")
struct SteamServiceCredentialsTests {

  @Test("Sin nada conectado, avisa en vez de fallar en la red")
  func sinCredenciales() throws {
    #expect(throws: SteamCredentialsError.notConnected) {
      _ = try SteamService.live(client: StubHTTPClient(json: "{}"), keychain: InMemoryKeychainStore())
    }
  }

  @Test("Con credenciales guardadas, live() las usa")
  func conCredenciales() throws {
    let llavero = InMemoryKeychainStore()
    try credencialesFalsas.save(to: llavero)

    let servicio = try SteamService.live(client: StubHTTPClient(json: "{}"), keychain: llavero)

    #expect(try servicio.ownedGamesURL().absoluteString.contains("CLAVE_DE_PRUEBA"))
  }

  @Test("Desconectar borra las dos claves del llavero")
  func desconectar() throws {
    let llavero = InMemoryKeychainStore()
    try credencialesFalsas.save(to: llavero)

    try SteamService.Credentials.removeFromKeychain(llavero)

    #expect(try SteamService.Credentials.fromKeychain(llavero) == nil)
  }
}

@Suite("Ocultar secretos en las URLs")
struct URLRedactionTests {

  @Test("La API key y el steamid no aparecen al registrar la URL")
  func ocultaLoSensible() throws {
    let service = SteamService(
      client: StubHTTPClient(json: "{}"),
      credentials: .init(apiKey: "CLAVE_SUPER_SECRETA", steamID: "76561198000000000")
    )

    let registrable = try service.ownedGamesURL().redactingSecrets

    #expect(!registrable.contains("CLAVE_SUPER_SECRETA"), "La API key no se puede registrar")
    #expect(!registrable.contains("76561198000000000"), "El steamID tampoco")
    #expect(registrable.contains("key=***"))
    #expect(registrable.contains("steamid=***"))
  }

  @Test("Lo que no es sensible se conserva, para que el registro sirva de algo")
  func conservaLoDemas() throws {
    let service = SteamService(
      client: StubHTTPClient(json: "{}"),
      credentials: credencialesFalsas
    )

    let registrable = try service.ownedGamesURL().redactingSecrets

    #expect(registrable.contains("api.steampowered.com"))
    #expect(registrable.contains("GetOwnedGames"))
    #expect(registrable.contains("include_appinfo=1"))
  }

  @Test("Una URL sin parametros no se rompe")
  func urlSinParametros() throws {
    let url = try #require(URL(string: "https://api.steampowered.com/algo"))

    #expect(url.redactingSecrets == "https://api.steampowered.com/algo")
  }
}
