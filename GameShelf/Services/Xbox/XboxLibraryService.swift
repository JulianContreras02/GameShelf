//
//  XboxLibraryService.swift
//  GameShelf
//

import Foundation

/// Un juego de Xbox, ya con todo lo que hace falta para guardarlo.
struct XboxGame: Sendable, Equatable {
  /// Identificador del juego en Xbox, del estilo `1560034050`.
  let titleId: String

  let name: String
  let coverURL: URL?

  /// Horas jugadas. `nil` si Xbox no las dio: el juego no lleva estadisticas,
  /// o fallo la consulta.
  let playtimeHours: Double?

  let lastPlayedAt: Date?

  /// `nil` si el juego no tiene logros.
  let gamerscore: Gamerscore?
}

/// Trae la biblioteca de Xbox del usuario.
///
/// Como la autenticacion, es una **API no oficial** para apps de terceros:
/// los endpoints y la forma de las respuestas salen de OpenXbox/xbox-webapi,
/// no de Microsoft. Todo eso queda detras de este protocolo.
protocol XboxLibraryServicing: Sendable {
  /// Trae los juegos jugados, con su Gamerscore y sus horas.
  ///
  /// - Throws: `XboxAuthError` si la sesion ya no sirve, `NetworkError` si
  ///   falla la peticion principal.
  func fetchPlayedGames() async throws -> [XboxGame]
}

/// Implementacion real contra TitleHub y userstats.
struct XboxLibraryService: XboxLibraryServicing {

  /// Cuantos juegos se piden del historial.
  ///
  /// El historial no viene paginado, asi que se pide de una vez. OpenXbox usa
  /// 5 por defecto y no documenta un maximo: 1000 cubre de sobra un
  /// historial real, pero **no se comprobo** contra la API. Si Xbox
  /// respondiera con un error por pedir tantos, este es el numero a bajar.
  static let maxItems = 1000

  /// Cuantos juegos se consultan por llamada a las estadisticas.
  ///
  /// Tampoco se comprobo: OpenXbox solo pide uno por llamada. Se deja bajo
  /// para no tropezar con un limite que Microsoft no documenta.
  static let tamanoDeTandaDeEstadisticas = 10

  /// Que trae cada juego, ademas de lo basico: logros, imagenes y el scid que
  /// hace falta para pedir las horas.
  static let decoraciones = "achievement,image,scid"

  static let titleHubHost = "titlehub.xboxlive.com"
  static let statsBatchURL = URL(string: "https://userstats.xboxlive.com/batch")!

  private let client: HTTPClient

  /// De donde sacar la cabecera `Authorization` vigente.
  ///
  /// Es una funcion y no un texto por lo mismo que en PSN: el XSTS caduca, y
  /// pedirlo en el momento deja que quien lo provea lo renueve.
  private let authorizationHeader: @Sendable () async throws -> String

  /// El identificador numerico de la cuenta, que va en la URL del historial.
  private let xuid: @Sendable () async throws -> String?

  init(
    client: HTTPClient,
    authorizationHeader: @escaping @Sendable () async throws -> String,
    xuid: @escaping @Sendable () async throws -> String?
  ) {
    self.client = client
    self.authorizationHeader = authorizationHeader
    self.xuid = xuid
  }

  func fetchPlayedGames() async throws -> [XboxGame] {
    guard let cuenta = try await xuid(), !cuenta.isEmpty else {
      throw XboxAuthError.respuestaInesperada("Falta el identificador de la cuenta. Vuelve a conectarla.")
    }

    let titulos = try await fetchTitles(xuid: cuenta)
    guard !titulos.isEmpty else { return [] }

    let minutos = await fetchMinutesPlayed(xuid: cuenta, scids: titulos.compactMap(\.serviceConfigId))

    return titulos.compactMap { titulo in
      guard let nombre = titulo.nombre else { return nil }
      return XboxGame(
        titleId: titulo.titleId,
        name: nombre,
        coverURL: titulo.coverURL,
        playtimeHours: titulo.serviceConfigId.flatMap { minutos[$0.lowercased()] }.map { $0 / 60 },
        lastPlayedAt: titulo.lastPlayedAt,
        gamerscore: titulo.achievement?.gamerscore
      )
    }
  }

  // MARK: - Peticiones

  /// Trae el historial de juegos, ya sin las apps.
  func fetchTitles(xuid: String) async throws -> [XboxTitleDTO] {
    let url = try titleHistoryURL(xuid: xuid)
    let token = try await authorizationHeader()

    do {
      return try await client.get(XboxTitleHistoryResponse.self, from: url, headers: Self.cabecerasTitleHub(token))
        .juegos
    } catch NetworkError.httpError(let codigo) where codigo == 401 || codigo == 403 {
      // Igual que en PSN y Epic: se traduce para que la pantalla pueda pedir
      // un codigo nuevo en vez de mostrar "error 401".
      throw XboxAuthError.sesionExpirada
    }
  }

  /// Trae los minutos jugados, indexados por scid en minusculas.
  ///
  /// **No propaga errores**, igual que los tiempos de Epic: sin horas la
  /// biblioteca sigue sirviendo, y una tanda que falle no se lleva las demas.
  /// Los juegos que se queden sin dato conservan las horas que ya tenian.
  func fetchMinutesPlayed(xuid: String, scids: [String]) async -> [String: Double] {
    var vistos = Set<String>()
    let unicos = scids.filter { !$0.isEmpty && vistos.insert($0.lowercased()).inserted }
    guard !unicos.isEmpty, let token = try? await authorizationHeader() else { return [:] }

    var resultado: [String: Double] = [:]

    for tanda in unicos.chunked(into: Self.tamanoDeTandaDeEstadisticas) {
      guard let respuesta = try? await client.post(
        XboxStatsBatchResponse.self,
        to: Self.statsBatchURL,
        body: XboxStatsBatchRequest(xuid: xuid, scids: tanda),
        headers: Self.cabecerasEstadisticas(token)
      ) else { continue }

      resultado.merge(respuesta.minutosPorSCID) { actual, nuevo in max(actual, nuevo) }
    }

    return resultado
  }

  // MARK: - URLs y cabeceras

  /// Arma la URL del historial de juegos.
  ///
  /// El xuid va dentro de la ruta (`users/xuid(123)/...`), asi que se exige
  /// que sea solo digitos: es lo que es, y cualquier otra cosa armaria otra
  /// ruta.
  func titleHistoryURL(xuid: String) throws -> URL {
    let ruta = "/users/xuid(\(xuid))/titles/titlehistory/decoration/\(Self.decoraciones)"
    guard xuid.allSatisfy(\.isASCIIDigit) else {
      throw NetworkError.invalidURL(ruta)
    }

    var componentes = URLComponents()
    componentes.scheme = "https"
    componentes.host = Self.titleHubHost
    componentes.path = ruta
    componentes.queryItems = [URLQueryItem(name: "maxItems", value: String(Self.maxItems))]

    guard let url = componentes.url else {
      throw NetworkError.invalidURL(ruta)
    }
    return url
  }

  /// Las de OpenXbox para TitleHub, tal cual.
  ///
  /// Las tres `x-xbl-client-*` presentan la peticion como la app de Xbox. No
  /// esta claro que hagan falta, pero son las de la peticion que si se sabe
  /// que funciona, y quitarlas solo agregaria una duda mas.
  static func cabecerasTitleHub(_ autorizacion: String) -> [String: String] {
    [
      "Authorization": autorizacion,
      "x-xbl-contract-version": "2",
      "x-xbl-client-name": "XboxApp",
      "x-xbl-client-type": "UWA",
      "x-xbl-client-version": "39.39.22001.0",
      "Accept-Language": "es-CO"
    ]
  }

  static func cabecerasEstadisticas(_ autorizacion: String) -> [String: String] {
    [
      "Authorization": autorizacion,
      "x-xbl-contract-version": "2"
    ]
  }
}

private extension Character {
  /// Solo 0-9. `isNumber` acepta tambien otros sistemas de numeracion.
  var isASCIIDigit: Bool {
    isASCII && isNumber
  }
}
