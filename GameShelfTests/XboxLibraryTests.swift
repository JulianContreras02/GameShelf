//
//  XboxLibraryTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

// Los dos archivos de apoyo (`xbox_historial.json` y `xbox_estadisticas.json`)
// son respuestas grabadas por OpenXbox/xbox-webapi-python (licencia MIT) para
// sus propias pruebas, copiadas tal cual. A diferencia de PSN y Epic no salen
// de una cuenta propia: hace falta una app de Azure registrada para llegar a
// pedirlas.

/// Respuestas cortas escritas a mano, para los casos que las grabadas no traen.
enum XboxJSONDePrueba {
  /// Un juego con scid, que es lo que hace falta para pedir sus horas.
  static let historial = """
    {
      "xuid": "123",
      "titles": [
        {
          "titleId": "1717113201",
          "name": "Sea of Thieves",
          "type": "Game",
          "displayImage": "http://store-images.s-microsoft.com/image/apps.1",
          "serviceConfigId": "1370999b-fca2-4c53-8ec5-73493bcb67e5",
          "achievement": {"currentGamerscore": 120, "totalGamerscore": 5000},
          "titleHistory": {"lastTimePlayed": "2020-10-08T01:55:12.4411936Z"}
        }
      ]
    }
    """

  static let estadisticas = """
    {
      "statlistscollection": [
        {
          "arrangebyfield": "xuid",
          "arrangebyfieldid": "123",
          "stats": [
            {"scid": "1370999b-fca2-4c53-8ec5-73493bcb67e5", "name": "MinutesPlayed", "value": "1220"}
          ]
        }
      ]
    }
    """
}

@Suite("Xbox: decodificar el historial")
struct XboxTitleHistoryDecodingTests {

  private func juegos() throws -> [XboxTitleDTO] {
    try Fixture.decode(XboxTitleHistoryResponse.self, from: "xbox_historial").juegos
  }

  private func juego(_ nombre: String) throws -> XboxTitleDTO {
    try #require(try juegos().first { $0.name?.hasPrefix(nombre) == true })
  }

  @Test("Decodifica la respuesta grabada, con todos sus campos de mas")
  func decodifica() throws {
    let todos = try juegos()

    #expect(todos.count == 5)
    #expect(todos.allSatisfy { !$0.titleId.isEmpty })
    #expect(todos.allSatisfy { $0.nombre != nil })
  }

  @Test("El Gamerscore sale de los puntos, no del numero de logros")
  func gamerscore() throws {
    let syndicate = try juego("Assassin")
    let puntos = try #require(syndicate.achievement?.gamerscore)

    #expect(puntos == Gamerscore(earned: 465, total: 1300))
    #expect(Double(puntos.progress) == syndicate.achievement?.progressPercentage, "La misma cuenta que hace Xbox")

    // Por esto no se usa `totalAchievements`: dice 0 de un juego del que ya se
    // consiguieron 22.
    #expect(syndicate.achievement?.currentAchievements == 22)
    #expect(syndicate.achievement?.totalAchievements == 0)
  }

  @Test("Un juego sin logros no tiene Gamerscore, en vez de un 0 de 0")
  func sinLogros() throws {
    // Call of Duty en PC (Win32), sin Xbox Live: todo llega en 0.
    let cod = try juego("Call of Duty")

    #expect(cod.achievement?.totalGamerscore == 0)
    #expect(cod.achievement?.gamerscore == nil)
  }

  @Test("Un juego con logros sin conseguir si tiene Gamerscore: 0 de 1000")
  func logrosSinEmpezar() throws {
    let pes = try juego("eFootball")

    #expect(pes.achievement?.gamerscore == Gamerscore(earned: 0, total: 1000))
  }

  @Test("Lee la ultima partida aunque traiga siete digitos de fraccion")
  func fecha() throws {
    let syndicate = try juego("Assassin")
    let esperada = ISO8601DateFormatter().date(from: "2020-10-08T01:55:12Z")

    #expect(syndicate.lastPlayedAt == esperada)
  }

  @Test("Las fechas sin fraccion, vacias o ausentes no rompen nada")
  func fechasRaras() {
    #expect(XboxTitleDTO.fecha("2020-10-08T01:55:12Z") == ISO8601DateFormatter().date(from: "2020-10-08T01:55:12Z"))
    #expect(XboxTitleDTO.fecha("") == nil)
    #expect(XboxTitleDTO.fecha(nil) == nil)
    #expect(XboxTitleDTO.fecha("ayer") == nil)
  }

  @Test("Todas las caratulas salen por HTTPS, aunque Xbox las mande por HTTP")
  func caratulasSeguras() throws {
    let todos = try juegos()

    // Con HTTP, iOS no las cargaria y saldrian todas en gris.
    #expect(todos.allSatisfy { $0.coverURL?.scheme == "https" })
  }

  @Test("Prefiere la caratula apaisada con nombre, la que se parece al header de Steam")
  func caratulaApaisada() throws {
    let syndicate = try juego("Assassin")
    let apaisada = try #require(syndicate.images?.first { $0.type == "TitledHeroArt" }?.url)

    #expect(syndicate.coverURL?.absoluteString == apaisada.replacingOccurrences(of: "http://", with: "https://"))
  }

  @Test("Sin imagenes usa la principal, y la de images-eds va por su host seguro")
  func sinImagenes() throws {
    // Call of Duty no trae `images`, y su imagen principal esta en
    // images-eds.xboxlive.com.
    let cod = try juego("Call of Duty")
    #expect(cod.images?.isEmpty == true)

    let url = try #require(cod.coverURL)
    #expect(url.scheme == "https")
    #expect(url.host == "images-eds-ssl.xboxlive.com")
    #expect(url.query?.hasPrefix("url=") == true, "El resto de la direccion no se toca")
  }

  @Test("Deja fuera las apps y lo que llega sin nombre")
  func soloJuegos() throws {
    let json = """
      {"titles": [
        {"titleId": "1", "name": "Halo Infinite", "type": "Game"},
        {"titleId": "2", "name": "Netflix", "type": "App"},
        {"titleId": "3", "name": "Sin tipo"},
        {"titleId": "4", "name": "  ", "type": "Game"}
      ]}
      """
    let respuesta = try JSONDecoder().decode(XboxTitleHistoryResponse.self, from: Data(json.utf8))

    #expect(respuesta.juegos.map(\.titleId) == ["1", "4"])
    #expect(respuesta.juegos.compactMap(\.nombre) == ["Halo Infinite"])
  }

  @Test("Una respuesta sin juegos no falla")
  func vacia() throws {
    let respuesta = try JSONDecoder().decode(XboxTitleHistoryResponse.self, from: Data(#"{"xuid": "1"}"#.utf8))

    #expect(respuesta.juegos.isEmpty)
  }
}

@Suite("Xbox: decodificar el tiempo jugado")
struct XboxStatsDecodingTests {

  @Test("Lee los minutos jugados de la respuesta grabada")
  func minutos() throws {
    let respuesta = try Fixture.decode(XboxStatsBatchResponse.self, from: "xbox_estadisticas")

    #expect(respuesta.minutosPorSCID == ["1370999b-fca2-4c53-8ec5-73493bcb67e5": 1220])
  }

  @Test("Acepta el valor como numero, no solo como texto")
  func valorNumerico() throws {
    let json = """
      {"statlistscollection": [{"stats": [{"scid": "ABC", "name": "MinutesPlayed", "value": 90}]}]}
      """
    let respuesta = try JSONDecoder().decode(XboxStatsBatchResponse.self, from: Data(json.utf8))

    #expect(respuesta.minutosPorSCID == ["abc": 90], "Indexado en minusculas")
  }

  @Test("Ignora otras estadisticas y los valores que no son numero")
  func ignoraLoDemas() throws {
    let json = """
      {"statlistscollection": [{"stats": [
        {"scid": "a", "name": "DistanceSailed", "value": "92173"},
        {"scid": "b", "name": "MinutesPlayed", "value": "mucho"},
        {"scid": "c", "name": "MinutesPlayed"}
      ]}]}
      """
    let respuesta = try JSONDecoder().decode(XboxStatsBatchResponse.self, from: Data(json.utf8))

    #expect(respuesta.minutosPorSCID.isEmpty)
  }

  @Test("El cuerpo pide los minutos de cada juego de la tanda")
  func cuerpo() throws {
    let cuerpo = XboxStatsBatchRequest(xuid: "123", scids: ["a", "b"])
    let datos = try JSONEncoder().encode(cuerpo)
    let json = try #require(try JSONSerialization.jsonObject(with: datos) as? [String: Any])

    #expect(json["arrangebyfield"] as? String == "xuid")
    #expect(json["xuids"] as? [String] == ["123"])

    let estadisticas = try #require(json["stats"] as? [[String: String]])
    #expect(estadisticas == [["name": "MinutesPlayed", "scid": "a"], ["name": "MinutesPlayed", "scid": "b"]])

    let grupos = try #require(json["groups"] as? [[String: String]])
    #expect(grupos == [["name": "Hero", "scid": "a"], ["name": "Hero", "scid": "b"]])
  }
}

@Suite("Xbox: Gamerscore")
struct GamerscoreTests {

  @Test("El porcentaje se redondea como Xbox")
  func porcentaje() {
    #expect(Gamerscore(earned: 465, total: 1300).progress == 36)
    #expect(Gamerscore(earned: 195, total: 2600).progress == 8)
    #expect(Gamerscore(earned: 1000, total: 1000).progress == 100)
  }

  @Test("Un total en cero da 0 %, no un error")
  func totalEnCero() {
    #expect(Gamerscore(earned: 0, total: 0).progress == 0)
    #expect(!Gamerscore(earned: 0, total: 0).isComplete)
  }

  @Test("Completo solo con todos los puntos")
  func completo() {
    #expect(Gamerscore(earned: 1000, total: 1000).isComplete)
    #expect(!Gamerscore(earned: 999, total: 1000).isComplete)
  }
}

@Suite("Xbox: peticiones de biblioteca")
struct XboxLibraryRequestTests {

  private func servicio(_ client: HTTPClient, xuid: String? = "123") -> XboxLibraryService {
    XboxLibraryService(client: client, authorizationHeader: { "XBL3.0 x=HASH;TOKEN" }, xuid: { xuid })
  }

  @Test("La URL lleva el xuid, las decoraciones y el tope")
  func url() throws {
    let url = try servicio(StubHTTPClient(json: "{}")).titleHistoryURL(xuid: "2719584417856940").absoluteString

    #expect(url.hasPrefix("https://titlehub.xboxlive.com/users/xuid(2719584417856940)/titles/titlehistory/"))
    #expect(url.contains("/decoration/achievement,image,scid"))
    #expect(url.contains("maxItems=\(XboxLibraryService.maxItems)"))
  }

  @Test("Un xuid que no es numero no arma ninguna URL")
  func xuidRaro() {
    #expect(throws: NetworkError.self) {
      try servicio(StubHTTPClient(json: "{}")).titleHistoryURL(xuid: "1)/otra/ruta")
    }
  }

  @Test("El token y la version de contrato van en la cabecera")
  func cabeceras() async throws {
    let cliente = StubHTTPClient(json: #"{"titles": []}"#)

    _ = try await servicio(cliente).fetchPlayedGames()

    let cabeceras = try #require(cliente.sentHeaders.first)
    #expect(cabeceras["Authorization"] == "XBL3.0 x=HASH;TOKEN")
    #expect(cabeceras["x-xbl-contract-version"] == "2")
  }

  @Test("Un 401 se traduce a sesion expirada")
  func tokenRechazado() async {
    let cliente = StubHTTPClient(.failure(.httpError(statusCode: 401)))

    await #expect(throws: XboxAuthError.sesionExpirada) {
      try await servicio(cliente).fetchPlayedGames()
    }
  }

  @Test("Sin xuid lo dice, sin pedir nada")
  func sinXuid() async {
    let cliente = StubHTTPClient(json: "{}")

    await #expect(throws: XboxAuthError.self) {
      try await servicio(cliente, xuid: nil).fetchPlayedGames()
    }
    #expect(cliente.requestedURLs.isEmpty)
  }

  @Test("Junta el historial con las horas")
  func juntaHorasYLogros() async throws {
    let cliente = RoutingHTTPClient(rutas: [
      ("titlehub", XboxJSONDePrueba.historial),
      ("userstats", XboxJSONDePrueba.estadisticas)
    ])

    let juegos = try await servicio(cliente).fetchPlayedGames()

    let sea = try #require(juegos.first)
    #expect(sea.titleId == "1717113201")
    #expect(sea.name == "Sea of Thieves")
    #expect(sea.gamerscore == Gamerscore(earned: 120, total: 5000))
    #expect(sea.playtimeHours.map { abs($0 - 1220.0 / 60) < 0.001 } == true, "1220 minutos")
    #expect(sea.coverURL?.scheme == "https")
    #expect(sea.lastPlayedAt != nil)
  }

  @Test("Que fallen las horas no tumba la sincronizacion")
  func horasQueFallan() async throws {
    // Sin ruta para userstats: esa peticion falla.
    let cliente = RoutingHTTPClient(rutas: [("titlehub", XboxJSONDePrueba.historial)])

    let juegos = try await servicio(cliente).fetchPlayedGames()

    #expect(juegos.count == 1)
    #expect(juegos.first?.playtimeHours == nil, "Sin dato, no un cero inventado")
    #expect(juegos.first?.gamerscore != nil, "Lo demas llega igual")
  }

  @Test("Las horas se piden en tandas, sin repetir juegos")
  func tandas() async {
    let cliente = RoutingHTTPClient(rutas: [("userstats", "{}")])
    let scids = (1...25).map { "scid-\($0)" } + ["SCID-1"]

    _ = await servicio(cliente).fetchMinutesPlayed(xuid: "123", scids: scids)

    // 25 distintos (el ultimo repite el primero en mayusculas), de 10 en 10.
    #expect(cliente.sentBodies.count == 3)
    #expect(cliente.requestedURLs.allSatisfy { $0 == XboxLibraryService.statsBatchURL })
  }

  @Test("Sin ningun scid no se pide nada")
  func sinScid() async {
    let cliente = RoutingHTTPClient(rutas: [("userstats", "{}")])

    let minutos = await servicio(cliente).fetchMinutesPlayed(xuid: "123", scids: [])

    #expect(minutos.isEmpty)
    #expect(cliente.requestedURLs.isEmpty)
  }
}
