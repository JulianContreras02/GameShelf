//
//  SteamWishlistService.swift
//  GameShelf
//

import Foundation

/// Un juego de la lista de deseos, ya con todo lo que hace falta para mostrarlo.
///
/// Junta las dos llamadas que hay que hacer: la wishlist da los appids y la
/// tienda da los nombres.
struct SteamWishlistGame: Sendable, Equatable {
  let appID: Int
  let name: String
  let coverURL: URL?
  let storeURL: URL?

  /// Cuando se agrego a la lista en Steam.
  let addedAt: Date?

  /// Orden que le puso el usuario en Steam. `0` es sin prioridad.
  let priority: Int

  let releaseDate: Date?
  let isComingSoon: Bool
}

/// Acceso a la lista de deseos de Steam.
///
/// Va en un protocolo aparte de `SteamServicing` a proposito. El endpoint de
/// wishlist es **semi-oficial**: no esta documentado, no promete estabilidad y
/// ya cambio una vez (el antiguo de la tienda dejo de responder). Manteniendolo
/// separado, si se rompe se cae la wishlist y no la biblioteca.
protocol SteamWishlistServicing: Sendable {
  /// Trae la lista de deseos con nombres y caratulas.
  ///
  /// - Returns: Lista vacia si la wishlist esta vacia **o** si es privada:
  ///   Steam responde igual en los dos casos.
  /// - Throws: `NetworkError` si la peticion falla.
  func fetchWishlist() async throws -> [SteamWishlistGame]
}

/// Implementacion real contra la API de Steam.
struct SteamWishlistService: SteamWishlistServicing {

  /// Cuantos appids se piden por llamada a la tienda.
  ///
  /// Steam no documenta un limite. Se parte en tandas para no armar una URL
  /// enorme con una wishlist grande, que es justo donde reventaria.
  static let tamanoDeTanda = 50

  private let client: HTTPClient
  private let steamID: String

  init(client: HTTPClient, steamID: String) {
    self.client = client
    self.steamID = steamID
  }

  /// Crea el servicio con el SteamID del archivo de configuracion.
  ///
  /// A diferencia del resto de la API, estos dos endpoints **no piden API
  /// key**: se comprobo contra la cuenta real que responden igual con y sin
  /// ella. Se pide solo el SteamID para no exponer la clave sin necesidad.
  static func live(
    client: HTTPClient = URLSessionHTTPClient(),
    bundle: Bundle = .main
  ) throws -> SteamWishlistService {
    SteamWishlistService(
      client: client,
      steamID: try AppSecrets.value(for: .steamID, in: bundle)
    )
  }

  func fetchWishlist() async throws -> [SteamWishlistGame] {
    let entradas = try await client
      .get(SteamWishlistResponse.self, from: try wishlistURL())
      .items

    guard !entradas.isEmpty else { return [] }

    let fichas = try await fetchStoreItems(for: entradas.map(\.appID))
    return combinar(entradas, con: fichas)
  }

  /// Pide a la tienda los datos de una lista de appids, en tandas.
  func fetchStoreItems(for appIDs: [Int]) async throws -> [Int: SteamStoreItemDTO] {
    var porAppID: [Int: SteamStoreItemDTO] = [:]

    for tanda in appIDs.chunked(into: Self.tamanoDeTanda) {
      let respuesta = try await client.get(
        SteamStoreItemsResponse.self,
        from: try storeItemsURL(for: tanda)
      )

      for ficha in respuesta.items where ficha.isUsable {
        porAppID[ficha.appID] = ficha
      }
    }

    return porAppID
  }

  /// Une lo que dice la wishlist con lo que dice la tienda.
  ///
  /// Si la tienda no supo resolver un appid, el juego **igual se conserva** con
  /// un nombre de respaldo: perder una entrada de la lista de deseos porque su
  /// ficha fallo seria peor que mostrarla incompleta.
  private func combinar(
    _ entradas: [SteamWishlistItemDTO],
    con fichas: [Int: SteamStoreItemDTO]
  ) -> [SteamWishlistGame] {
    entradas.map { entrada in
      let ficha = fichas[entrada.appID]
      return SteamWishlistGame(
        appID: entrada.appID,
        name: ficha?.name ?? SteamGameMapper.fallbackName(for: entrada.appID),
        coverURL: ficha?.coverURL,
        storeURL: ficha?.storeURL ?? URL(string: "https://store.steampowered.com/app/\(entrada.appID)"),
        addedAt: entrada.addedAt,
        priority: entrada.priority ?? 0,
        releaseDate: ficha?.releaseDate,
        isComingSoon: ficha?.isComingSoon ?? false
      )
    }
  }

  // MARK: - URLs

  /// Arma la URL de `GetWishlist`.
  ///
  /// Se expone aparte para poder verificar la construccion sin hacer la
  /// peticion, igual que en `SteamService`.
  func wishlistURL() throws -> URL {
    guard var componentes = URLComponents(
      url: SteamService.baseURL.appendingPathComponent("/IWishlistService/GetWishlist/v1/"),
      resolvingAgainstBaseURL: false
    ) else {
      throw NetworkError.invalidURL("/IWishlistService/GetWishlist/v1/")
    }

    componentes.queryItems = [URLQueryItem(name: "steamid", value: steamID)]

    guard let url = componentes.url else {
      throw NetworkError.invalidURL("/IWishlistService/GetWishlist/v1/")
    }
    return url
  }

  /// Arma la URL de `GetItems` para una tanda de appids.
  ///
  /// El endpoint recibe un JSON dentro del parametro `input_json`, no
  /// parametros sueltos.
  func storeItemsURL(for appIDs: [Int]) throws -> URL {
    let ruta = "/IStoreBrowseService/GetItems/v1/"

    let peticion = StoreItemsRequest(
      ids: appIDs.map(StoreItemID.init(appid:)),
      context: .init(language: "spanish", countryCode: "CO"),
      dataRequest: .init(includeAssets: true, includeRelease: true)
    )

    guard let datos = try? JSONEncoder().encode(peticion),
          let json = String(data: datos, encoding: .utf8),
          var componentes = URLComponents(
            url: SteamService.baseURL.appendingPathComponent(ruta),
            resolvingAgainstBaseURL: false
          )
    else {
      throw NetworkError.invalidURL(ruta)
    }

    componentes.queryItems = [URLQueryItem(name: "input_json", value: json)]

    guard let url = componentes.url else {
      throw NetworkError.invalidURL(ruta)
    }
    return url
  }
}

/// Cuerpo de la peticion a `GetItems`.
///
/// Va fuera del servicio y no anidado dentro para que sus tipos no queden a dos
/// niveles de profundidad.
private struct StoreItemsRequest: Encodable {
  let ids: [StoreItemID]
  let context: StoreItemsContext
  let dataRequest: StoreItemsDataRequest

  enum CodingKeys: String, CodingKey {
    case ids
    case context
    case dataRequest = "data_request"
  }
}

private struct StoreItemID: Encodable {
  let appid: Int
}

/// Idioma y pais con los que responde la tienda.
private struct StoreItemsContext: Encodable {
  let language: String
  let countryCode: String

  enum CodingKeys: String, CodingKey {
    case language
    case countryCode = "country_code"
  }
}

/// Que partes de la ficha se quieren.
private struct StoreItemsDataRequest: Encodable {
  let includeAssets: Bool
  let includeRelease: Bool

  enum CodingKeys: String, CodingKey {
    case includeAssets = "include_assets"
    case includeRelease = "include_release"
  }
}

extension Array {
  /// Parte el arreglo en tandas de como maximo `tamano` elementos.
  func chunked(into tamano: Int) -> [[Element]] {
    guard tamano > 0 else { return [self] }
    return stride(from: 0, to: count, by: tamano).map {
      Array(self[$0..<Swift.min($0 + tamano, count)])
    }
  }
}
