//
//  EpicLibraryService.swift
//  GameShelf
//

import Foundation

/// Un juego de Epic, ya agrupado y listo para guardar.
struct EpicGame: Sendable, Equatable {
  /// El `namespace` de Epic, que identifica al juego.
  let namespace: String

  let name: String
  let coverURL: URL?

  /// Horas jugadas. `0` si nunca se abrio, que en Epic es lo mas comun.
  let playtimeHours: Double
}

/// Trae la biblioteca de Epic del usuario.
///
/// Es el conector mas fragil de los tres: API no oficial, sin nombres en la
/// respuesta principal y con el tiempo jugado repartido por artefactos. Todo
/// eso queda encerrado aca detras.
protocol EpicLibraryServicing: Sendable {
  /// Trae los juegos de la cuenta.
  ///
  /// - Throws: `EpicAuthError` si la sesion ya no sirve, `NetworkError` si
  ///   falla la peticion principal.
  func fetchOwnedGames() async throws -> [EpicGame]
}

/// Implementacion real contra los endpoints de Epic.
struct EpicLibraryService: EpicLibraryServicing {

  /// Tope de paginas, por si `nextCursor` nunca dejara de venir.
  static let paginasMaximas = 30

  static let libraryURL = URL(
    string: "https://library-service.live.use1a.on.epicgames.com/library/api/public/items"
  )!

  private let client: HTTPClient
  private let accessToken: @Sendable () async throws -> String
  private let accountID: @Sendable () async throws -> String?

  init(
    client: HTTPClient,
    accessToken: @escaping @Sendable () async throws -> String,
    accountID: @escaping @Sendable () async throws -> String?
  ) {
    self.client = client
    self.accessToken = accessToken
    self.accountID = accountID
  }

  func fetchOwnedGames() async throws -> [EpicGame] {
    let registros = try await fetchRecords()
    guard !registros.isEmpty else { return [] }

    let tiempos = await fetchPlaytimes()
    let porNamespace = Self.agrupar(registros, tiempos: tiempos)

    // Solo se pregunta al catalogo por los que no tienen nombre util. Con la
    // biblioteca real eran 49 de 293: preguntar por todos serian casi 300
    // peticiones para resolver algo que ya venia resuelto.
    let sinNombre = porNamespace.filter { !$0.value.tieneNombre }
    let resueltos = await resolverNombres(de: sinNombre.values.map { $0 })

    return porNamespace.values.compactMap { grupo in
      if grupo.tieneNombre {
        return EpicGame(
          namespace: grupo.namespace,
          name: grupo.nombre,
          coverURL: nil,
          playtimeHours: grupo.horas
        )
      }

      // Sin nombre resuelto se descarta: guardar un juego llamado
      // "1b737464d3c441f8" no le sirve a nadie.
      guard let ficha = resueltos[grupo.namespace], let titulo = ficha.title, !titulo.isEmpty else {
        return nil
      }

      return EpicGame(
        namespace: grupo.namespace,
        name: titulo,
        coverURL: ficha.coverURL,
        playtimeHours: grupo.horas
      )
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  // MARK: - Agrupar

  /// Los artefactos de un mismo juego, ya juntos.
  struct Grupo: Sendable {
    let namespace: String
    var nombre: String
    var horas: Double
    var catalogItemID: String?

    var tieneNombre: Bool {
      !nombre.isEmpty && nombre != EpicLibraryRecordDTO.nombreSinResolver
    }
  }

  /// Junta los artefactos por juego y les asigna su tiempo.
  ///
  /// El tiempo es el **mayor** de sus artefactos, no la suma: Epic repite las
  /// mismas horas bajo varios ids del mismo juego, y sumarlas las duplicaria.
  static func agrupar(
    _ registros: [EpicLibraryRecordDTO],
    tiempos: [String: Double]
  ) -> [String: Grupo] {
    var porNamespace: [String: Grupo] = [:]

    for registro in registros {
      let horas = registro.appName.flatMap { tiempos[$0] } ?? 0

      if var grupo = porNamespace[registro.namespace] {
        grupo.horas = max(grupo.horas, horas)
        if !grupo.tieneNombre, registro.tieneNombreUtil {
          grupo.nombre = registro.sandboxName ?? grupo.nombre
        }
        grupo.catalogItemID = grupo.catalogItemID ?? registro.catalogItemId
        porNamespace[registro.namespace] = grupo
      } else {
        porNamespace[registro.namespace] = Grupo(
          namespace: registro.namespace,
          nombre: registro.sandboxName ?? "",
          horas: horas,
          catalogItemID: registro.catalogItemId
        )
      }
    }

    return porNamespace
  }

  // MARK: - Peticiones

  /// Trae todas las paginas de la biblioteca.
  func fetchRecords() async throws -> [EpicLibraryRecordDTO] {
    var todos: [EpicLibraryRecordDTO] = []
    var cursor: String?

    for _ in 0..<Self.paginasMaximas {
      let respuesta = try await get(EpicLibraryResponse.self, from: try libraryURL(cursor: cursor))
      todos.append(contentsOf: respuesta.registros)

      guard let siguiente = respuesta.siguienteCursor else { break }
      cursor = siguiente
    }

    return todos
  }

  /// Trae el tiempo jugado, indexado por artefacto.
  ///
  /// **No propaga errores.** Sin tiempos la biblioteca sigue sirviendo: se
  /// veran los juegos con 0 horas, que es mejor que no ver nada.
  func fetchPlaytimes() async -> [String: Double] {
    guard let cuenta = (try? await accountID()) ?? nil, !cuenta.isEmpty else { return [:] }

    let ruta = "https://library-service.live.use1a.on.epicgames.com"
      + "/library/api/public/playtime/account/\(cuenta)/all"
    guard let url = URL(string: ruta) else { return [:] }

    guard let tiempos = try? await get([EpicPlaytimeDTO].self, from: url) else { return [:] }

    return tiempos.reduce(into: [:]) { resultado, entrada in
      resultado[entrada.artifactId] = entrada.horas
    }
  }

  /// Pregunta al catalogo por los juegos sin nombre util.
  ///
  /// **No propaga errores**, y por eso el catalogo no puede tumbar la
  /// sincronizacion: si falla, esos juegos simplemente se quedan fuera y el
  /// resto entra igual.
  func resolverNombres(de grupos: [Grupo]) async -> [String: EpicCatalogItemDTO] {
    var resultado: [String: EpicCatalogItemDTO] = [:]

    for grupo in grupos {
      guard let itemID = grupo.catalogItemID else { continue }

      let ruta = "https://catalog-public-service-prod06.ol.epicgames.com"
        + "/catalog/api/shared/namespace/\(grupo.namespace)/bulk/items"
      guard var componentes = URLComponents(string: ruta) else { continue }
      componentes.queryItems = [
        URLQueryItem(name: "id", value: itemID),
        URLQueryItem(name: "includeDLCDetails", value: "false"),
        URLQueryItem(name: "includeMainGameDetails", value: "false"),
        URLQueryItem(name: "country", value: "CO"),
        URLQueryItem(name: "locale", value: "es")
      ]
      guard let url = componentes.url else { continue }

      if let respuesta = try? await get(EpicCatalogResponse.self, from: url),
         let ficha = respuesta.items[itemID] {
        resultado[grupo.namespace] = ficha
      }
    }

    return resultado
  }

  private func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    let token = try await accessToken()

    do {
      return try await client.get(type, from: url, headers: ["Authorization": "bearer \(token)"])
    } catch NetworkError.httpError(let codigo) where codigo == 401 || codigo == 403 {
      throw EpicAuthError.sesionExpirada
    }
  }

  /// Arma la URL de la biblioteca, con su cursor si lo hay.
  func libraryURL(cursor: String? = nil) throws -> URL {
    guard var componentes = URLComponents(url: Self.libraryURL, resolvingAgainstBaseURL: false) else {
      throw NetworkError.invalidURL(Self.libraryURL.absoluteString)
    }

    var parametros = [URLQueryItem(name: "includeMetadata", value: "true")]
    if let cursor, !cursor.isEmpty {
      parametros.append(URLQueryItem(name: "cursor", value: cursor))
    }
    componentes.queryItems = parametros

    guard let url = componentes.url else {
      throw NetworkError.invalidURL(Self.libraryURL.absoluteString)
    }
    return url
  }
}
