//
//  PSNLibraryService.swift
//  GameShelf
//

import Foundation

/// Un juego de PlayStation, ya con todo lo que hace falta para guardarlo.
struct PSNGame: Sendable, Equatable {
  /// Identificador en la tienda, del estilo `PPSA28038_00`.
  let titleId: String

  let name: String
  let coverURL: URL?

  /// Horas jugadas. `nil` si PSN mando una duracion que no se pudo leer.
  let playtimeHours: Double?

  /// Cuantas veces se ha abierto.
  let playCount: Int?

  let lastPlayedAt: Date?
  let firstPlayedAt: Date?

  /// Porcentaje de trofeos, de 0 a 100. `nil` si el juego no tiene.
  let trophyProgress: Int?
}

/// Trae la biblioteca de PlayStation del usuario.
///
/// Como el resto de PSN, es una **API no oficial**: va detras de un protocolo
/// para que un cambio de Sony no se extienda por toda la app.
protocol PSNLibraryServicing: Sendable {
  /// Trae los juegos jugados, con su progreso de trofeos.
  ///
  /// - Throws: `PSNAuthError` si la sesion ya no sirve, `NetworkError` si
  ///   falla la peticion.
  func fetchPlayedGames() async throws -> [PSNGame]
}

/// Implementacion real contra los endpoints de PSN.
struct PSNLibraryService: PSNLibraryServicing {

  /// Cuantos juegos se piden por pagina. El maximo que acepta el endpoint.
  static let tamanoDePagina = 200

  /// Cuantos juegos se consultan por llamada al mapa de trofeos.
  ///
  /// Se comprobo que 5 funciona. Sony no documenta el limite y pasarse suele
  /// devolver un error, asi que se deja en el valor verificado.
  static let tamanoDeTandaDeTrofeos = 5

  /// Cuantas paginas como maximo, por si `nextOffset` nunca dejara de venir.
  ///
  /// Sin este tope, una respuesta rara colgaria la app en un bucle infinito.
  static let paginasMaximas = 20

  static let baseURL = URL(string: "https://m.np.playstation.com/api")!

  private let client: HTTPClient

  /// De donde sacar un token de acceso vigente.
  ///
  /// Es una funcion y no un texto porque el token dura una hora: pedirlo en el
  /// momento deja que quien lo provea lo renueve si hace falta.
  private let accessToken: @Sendable () async throws -> String

  init(client: HTTPClient, accessToken: @escaping @Sendable () async throws -> String) {
    self.client = client
    self.accessToken = accessToken
  }

  func fetchPlayedGames() async throws -> [PSNGame] {
    let titulos = try await fetchTitles()
    guard !titulos.isEmpty else { return [] }

    let trofeos = try await fetchTrophyProgress(for: titulos.map(\.titleId))

    return titulos.compactMap { titulo in
      guard let nombre = titulo.nombre else { return nil }
      return PSNGame(
        titleId: titulo.titleId,
        name: nombre,
        coverURL: titulo.coverURL,
        playtimeHours: titulo.playtimeHours,
        playCount: titulo.playCount,
        lastPlayedAt: titulo.lastPlayedAt,
        firstPlayedAt: titulo.firstPlayedAt,
        trophyProgress: trofeos[titulo.titleId]?.progress
      )
    }
  }

  /// Trae todas las paginas de la lista de juegos.
  ///
  /// Se dejan fuera las apps de video, que PSN mezcla con los juegos.
  func fetchTitles() async throws -> [PSNTitleDTO] {
    var todos: [PSNTitleDTO] = []
    var offset = 0

    for _ in 0..<Self.paginasMaximas {
      let respuesta = try await get(PSNGameListResponse.self, from: try titlesURL(offset: offset))
      todos.append(contentsOf: respuesta.juegos.filter(\.esJuego))

      guard let siguiente = respuesta.nextOffset, siguiente > offset else { break }
      offset = siguiente
    }

    return todos
  }

  /// Trae el progreso de trofeos de una lista de juegos, en tandas.
  ///
  /// - Returns: Indexado por id de juego. Los que no tienen trofeos no
  ///   aparecen.
  func fetchTrophyProgress(for titleIDs: [String]) async throws -> [String: PSNTrophyTitleDTO] {
    var resultado: [String: PSNTrophyTitleDTO] = [:]

    for tanda in titleIDs.chunked(into: Self.tamanoDeTandaDeTrofeos) {
      let respuesta = try await get(PSNTrophyMapResponse.self, from: try trophyMapURL(for: tanda))

      // Se indexa por id y no por posicion: la respuesta llega en otro orden
      // del que se pidio. Se comprobo con datos reales.
      resultado.merge(respuesta.progresoPorTitleID) { actual, _ in actual }
    }

    return resultado
  }

  // MARK: - Peticiones

  private func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    let token = try await accessToken()

    do {
      return try await client.get(type, from: url, headers: [
        "Authorization": "Bearer \(token)",
        "Accept-Language": "es-CO"
      ])
    } catch NetworkError.httpError(let codigo) where codigo == 401 || codigo == 403 {
      // El token dejo de servir a mitad de camino. Se traduce para que la
      // pantalla pueda pedir uno nuevo en vez de mostrar "error 401".
      throw PSNAuthError.sesionExpirada
    }
  }

  // MARK: - URLs

  /// Arma la URL de la lista de juegos.
  func titlesURL(offset: Int = 0) throws -> URL {
    try url(
      ruta: "/gamelist/v2/users/me/titles",
      parametros: [
        URLQueryItem(name: "limit", value: String(Self.tamanoDePagina)),
        URLQueryItem(name: "offset", value: String(offset))
      ]
    )
  }

  /// Arma la URL que relaciona juegos con sus trofeos.
  func trophyMapURL(for titleIDs: [String]) throws -> URL {
    try url(
      ruta: "/trophy/v1/users/me/titles/trophyTitles",
      parametros: [URLQueryItem(name: "npTitleIds", value: titleIDs.joined(separator: ","))]
    )
  }

  private func url(ruta: String, parametros: [URLQueryItem]) throws -> URL {
    guard var componentes = URLComponents(
      url: Self.baseURL.appendingPathComponent(ruta),
      resolvingAgainstBaseURL: false
    ) else {
      throw NetworkError.invalidURL(ruta)
    }

    componentes.queryItems = parametros

    guard let url = componentes.url else {
      throw NetworkError.invalidURL(ruta)
    }
    return url
  }
}
