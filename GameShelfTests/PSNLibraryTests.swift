//
//  PSNLibraryTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

@Suite("PSN: duraciones ISO 8601")
struct ISO8601DurationTests {

  // PSN no manda minutos sino "PT29H47M44S". Estas son las formas que
  // aparecieron en la biblioteca real, mas las que el formato permite.

  @Test("Lee las formas que manda PSN de verdad")
  func formasReales() {
    #expect(ISO8601Duration.seconds(from: "PT29H47M44S") == 107_264)
    #expect(ISO8601Duration.seconds(from: "PT2H10M2S") == 7802)
    #expect(ISO8601Duration.seconds(from: "PT6M15S") == 375)
    #expect(ISO8601Duration.seconds(from: "PT15S") == 15)
    #expect(ISO8601Duration.seconds(from: "PT0S") == 0)
  }

  @Test("Lee tambien las partes que faltan")
  func partesOpcionales() {
    #expect(ISO8601Duration.seconds(from: "PT1H") == 3600)
    #expect(ISO8601Duration.seconds(from: "PT30M") == 1800)
    #expect(ISO8601Duration.seconds(from: "P1D") == 86_400)
    #expect(ISO8601Duration.seconds(from: "P2DT3H") == 183_600)
  }

  @Test("La M antes de la T son meses, no minutos")
  func laTImporta() {
    // "P5M" son cinco meses; "PT5M", cinco minutos. Confundirlos daria una
    // cifra absurda de horas jugadas.
    #expect(ISO8601Duration.seconds(from: "PT5M") == 300)
    #expect(ISO8601Duration.seconds(from: "P5M") == 0, "Los meses no se cuentan como tiempo jugado")
  }

  @Test("Lo que no es una duracion devuelve nil, no cero")
  func textoInvalido() {
    // Devolver 0 confundiria "no se pudo leer" con "no lo has jugado", y eso
    // acabaria borrando horas reales al sincronizar.
    #expect(ISO8601Duration.seconds(from: nil) == nil)
    #expect(ISO8601Duration.seconds(from: "") == nil)
    #expect(ISO8601Duration.seconds(from: "29H47M") == nil, "Sin la P inicial no es ISO 8601")
    #expect(ISO8601Duration.seconds(from: "PTHMS") == nil, "Unidades sin numero")
    #expect(ISO8601Duration.seconds(from: "P") == nil)
    #expect(ISO8601Duration.seconds(from: "PT") == nil)
  }

  @Test("Convierte a horas")
  func aHoras() throws {
    let horas = try #require(ISO8601Duration.hours(from: "PT29H47M44S"))
    #expect(abs(horas - 29.795) < 0.001)
    #expect(ISO8601Duration.hours(from: "PT0S") == 0)
    #expect(ISO8601Duration.hours(from: "basura") == nil)
  }
}

@Suite("PSN: decodificar la biblioteca real")
struct PSNGameListDecodingTests {

  private func juegos() throws -> [PSNTitleDTO] {
    try Fixture.decode(PSNGameListResponse.self, from: "psn_juegos").juegos
  }

  @Test("Decodifica la lista completa")
  func listaCompleta() throws {
    let respuesta = try Fixture.decode(PSNGameListResponse.self, from: "psn_juegos")

    #expect(respuesta.juegos.count == 40)
    #expect(respuesta.totalItemCount == 40)
    #expect(respuesta.nextOffset == nil, "Con 40 juegos no hay segunda pagina")
  }

  @Test("Lee nombre, caratula y tiempo jugado")
  func camposDeUnJuego() throws {
    let halo = try #require(try juegos().first { $0.titleId == "PPSA28038_00" })

    #expect(halo.nombre == "Halo: Campaign Evolved")
    #expect(halo.coverURL != nil)
    #expect(halo.playCount == 22)

    let horas = try #require(halo.playtimeHours)
    #expect(abs(horas - 29.795) < 0.01)
  }

  @Test("Las apps de video no son juegos")
  func filtraLasApps() throws {
    let todos = try juegos()
    let apps = todos.filter { !$0.esJuego }

    // En la biblioteca real aparecio Crunchyroll con 15 segundos de uso.
    #expect(!apps.isEmpty, "El fixture deberia traer al menos una app")
    #expect(apps.allSatisfy { $0.category?.contains("game") == false })

    let soloJuegos = todos.filter { $0.esJuego }
    #expect(soloJuegos.count == todos.count - apps.count)
    #expect(soloJuegos.allSatisfy { $0.nombre?.isEmpty == false })
  }

  @Test("Reconoce las categorias de PS4, PS5 y PC")
  func categorias() throws {
    let categorias = Set(try juegos().compactMap(\.category))

    #expect(categorias.contains("ps5_native_game"))
    #expect(categorias.contains("ps4_game"))
  }

  @Test("Lee las fechas, con y sin fracciones de segundo")
  func fechas() throws {
    let halo = try #require(try juegos().first { $0.titleId == "PPSA28038_00" })

    #expect(halo.lastPlayedAt != nil)
    #expect(halo.firstPlayedAt != nil)

    let primera = try #require(halo.firstPlayedAt)
    let ultima = try #require(halo.lastPlayedAt)
    #expect(primera <= ultima, "No se puede haber jugado por ultima vez antes que la primera")

    // Las de la API traen microsegundos; las de trofeos, no.
    #expect(PSNTitleDTO.fecha("2026-07-29T02:43:03.060000Z") != nil)
    #expect(PSNTitleDTO.fecha("2026-08-08T06:47:26Z") != nil)
    #expect(PSNTitleDTO.fecha("ayer") == nil)
  }

  @Test("Todos los juegos traen tiempo legible")
  func tiemposLegibles() throws {
    for juego in try juegos() {
      #expect(juego.playtimeHours != nil, "No se pudo leer la duracion de \(juego.titleId)")
    }
  }
}

@Suite("PSN: decodificar los trofeos")
struct PSNTrophyDecodingTests {

  @Test("Decodifica el progreso de la lista de trofeos")
  func listaDeTrofeos() throws {
    let datos = try Fixture.data("psn_trofeos")
    let respuesta = try JSONDecoder().decode(PSNTrophyTitlesResponse.self, from: datos)

    #expect(respuesta.trophyTitles?.count == 35)

    let halo = try #require(respuesta.trophyTitles?.first { $0.trophyTitleName == "Halo: Campaign Evolved" })
    #expect(halo.progress == 88)
    #expect(halo.definedTrophies?.total == 58)
    #expect(halo.earnedTrophies?.bronze == 52)
  }

  @Test("El mapa relaciona el id del juego con su progreso")
  func mapaDeTrofeos() throws {
    let respuesta = try Fixture.decode(PSNTrophyMapResponse.self, from: "psn_mapa_trofeos")
    let porID = respuesta.progresoPorTitleID

    #expect(porID.count == 5)
    #expect(porID["PPSA28038_00"]?.progress == 88, "Halo")
    #expect(porID["PPSA03420_00"]?.progress == 3, "GTA V")
    #expect(porID["PPSA01576_00"]?.progress == 0, "Empezado y sin trofeos todavia")
  }

  @Test("El mapa acierta donde el nombre falla")
  func porQueNoSeUsaElNombre() throws {
    let mapa = try Fixture.decode(PSNTrophyMapResponse.self, from: "psn_mapa_trofeos")
    let juegos = try Fixture.decode(PSNGameListResponse.self, from: "psn_juegos").juegos

    // El juego se llama "Grand Theft Auto V (PlayStation®5)" y su set de
    // trofeos "Grand Theft Auto V". Emparejar por nombre lo habria dejado sin
    // progreso; peor aun, "Marvel's Spider-Man" se habria emparejado con
    // "Spider-Man Remastered", que es otro juego con otros trofeos.
    let gta = try #require(juegos.first { $0.titleId == "PPSA03420_00" })
    let trofeos = try #require(mapa.progresoPorTitleID["PPSA03420_00"])

    #expect(gta.nombre != trofeos.trophyTitleName, "Los nombres no coinciden, y aun asi es el mismo juego")
    #expect(trofeos.progress == 3)
  }

  @Test("Un juego sin trofeos no aparece en el mapa")
  func sinTrofeos() throws {
    let json = Data(#"{"titles":[{"npTitleId":"PPSA00000_00","trophyTitles":[]}]}"#.utf8)
    let respuesta = try JSONDecoder().decode(PSNTrophyMapResponse.self, from: json)

    #expect(respuesta.progresoPorTitleID.isEmpty)
  }

  @Test("Con varios sets de trofeos se toma el mas avanzado")
  func variosSets() throws {
    let json = Data("""
      {"titles":[{"npTitleId":"X","trophyTitles":[
        {"npCommunicationId":"A","progress":20},
        {"npCommunicationId":"B","progress":75}
      ]}]}
      """.utf8)
    let respuesta = try JSONDecoder().decode(PSNTrophyMapResponse.self, from: json)

    #expect(respuesta.progresoPorTitleID["X"]?.progress == 75)
  }
}

@Suite("PSN: armado de peticiones")
struct PSNLibraryRequestTests {

  private func servicio(_ client: HTTPClient) -> PSNLibraryService {
    PSNLibraryService(client: client, accessToken: { "EL_TOKEN" })
  }

  @Test("Las URLs apuntan a los endpoints correctos")
  func urls() throws {
    let psn = servicio(StubHTTPClient(json: "{}"))

    #expect(try psn.titlesURL().absoluteString.contains("/gamelist/v2/users/me/titles"))
    #expect(try psn.titlesURL(offset: 200).absoluteString.contains("offset=200"))

    let mapa = try psn.trophyMapURL(for: ["A", "B"]).absoluteString
    #expect(mapa.contains("/trophy/v1/users/me/titles/trophyTitles"))
    #expect(mapa.contains("npTitleIds=A,B"))
  }

  @Test("El token va en la cabecera de cada peticion")
  func tokenEnLaCabecera() async throws {
    let cliente = StubHTTPClient(json: #"{"titles":[]}"#)

    _ = try await servicio(cliente).fetchTitles()

    let cabeceras = try #require(cliente.sentHeaders.first)
    #expect(cabeceras["Authorization"] == "Bearer EL_TOKEN")
  }

  @Test("El token se pide en el momento, no al crear el servicio")
  func tokenFresco() async throws {
    // Dura una hora: guardarlo al construir el servicio significaria usar uno
    // vencido en cuanto la app lleve un rato abierta.
    let contador = ContadorDeLlamadas()
    let servicio = PSNLibraryService(
      client: StubHTTPClient(json: #"{"titles":[]}"#),
      accessToken: { await contador.siguiente() }
    )

    _ = try await servicio.fetchTitles()
    _ = try await servicio.fetchTitles()

    #expect(await contador.total == 2)
  }

  @Test("Un 401 se traduce a sesion expirada, no a error 401")
  func tokenRechazado() async {
    let cliente = StubHTTPClient(.failure(.httpError(statusCode: 401)))

    await #expect(throws: PSNAuthError.sesionExpirada) {
      try await servicio(cliente).fetchTitles()
    }
  }

  @Test("Los trofeos se piden en tandas del tamano verificado")
  func tandasDeTrofeos() {
    #expect(PSNLibraryService.tamanoDeTandaDeTrofeos == 5)

    let tandas = Array(1...12).map(String.init).chunked(into: PSNLibraryService.tamanoDeTandaDeTrofeos)
    #expect(tandas.map(\.count) == [5, 5, 2])
  }
}

/// Cuenta cuantas veces se pidio el token.
private actor ContadorDeLlamadas {
  private(set) var total = 0

  func siguiente() -> String {
    total += 1
    return "TOKEN"
  }
}

/// Respuesta de `/trophy/v1/users/me/trophyTitles`.
///
/// No la usa la app (el mapa por titleId ya trae el progreso), pero el archivo
/// de apoyo existe y comprobar que se decodifica documenta su forma.
struct PSNTrophyTitlesResponse: Decodable {
  let trophyTitles: [PSNTrophyTitleDTO]?
}
