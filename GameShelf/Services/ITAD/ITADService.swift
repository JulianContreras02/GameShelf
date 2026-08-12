//
//  ITADService.swift
//  GameShelf
//

import Foundation

/// Consulta precios en IsThereAnyDeal.
///
/// Va en su propio protocolo, como el de Steam, para que los ViewModels
/// dependan de esta forma y no de la implementacion, y se pueda inyectar un
/// doble en las pruebas.
protocol ITADServicing: Sendable {
  /// Trae precios y minimos historicos de una lista de juegos de Steam.
  ///
  /// Son **dos peticiones en lote**, no una por juego: primero se traducen los
  /// appids a ids de ITAD y despues se piden todos los precios de una vez.
  ///
  /// - Returns: Los precios indexados por appid de Steam. Los juegos que ITAD
  ///   no conoce, o que no se venden en ninguna tienda, **no aparecen** en el
  ///   resultado.
  /// - Throws: `NetworkError` si alguna peticion falla.
  func prices(forSteamAppIDs appIDs: [Int]) async throws -> [Int: GamePrices]
}

/// Implementacion real contra la API v2 de IsThereAnyDeal.
struct ITADService: ITADServicing {

  /// Cuantos juegos se piden por peticion.
  ///
  /// La API acepta hasta 200 por llamada. Con una biblioteca de 118 juegos cabe
  /// todo en una, pero se parte igual para no romperse cuando crezca.
  static let tamanoDeTanda = 200

  /// Identificador de la tienda Steam dentro de ITAD.
  static let steamShopID = 61

  static let baseURL = URL(string: "https://api.isthereanydeal.com")!

  private let client: HTTPClient
  private let apiKey: String

  /// Pais con el que se piden los precios, en ISO 3166-1 alpha-2.
  ///
  /// Determina en que moneda responde la API. **Para Colombia responde en
  /// dolares**, y no es un error del parametro: se comprobo que con `DE`
  /// devuelve euros y con `AR` pesos argentinos, asi que el parametro funciona.
  /// Lo que pasa es que Steam y las demas tiendas facturan Colombia en USD, y
  /// eso es lo que de verdad se paga. La conversion a pesos que muestra la web
  /// de ITAD es un calculo suyo con una tasa de cambio, no el precio cobrado.
  let country: String

  init(client: HTTPClient, apiKey: String, country: String = "CO") {
    self.client = client
    self.apiKey = apiKey
    self.country = country
  }

  /// Crea el servicio con la clave del archivo de configuracion.
  static func live(
    client: HTTPClient = URLSessionHTTPClient(),
    bundle: Bundle = .main,
    country: String = "CO"
  ) throws -> ITADService {
    ITADService(
      client: client,
      apiKey: try AppSecrets.value(for: .itadAPIKey, in: bundle),
      country: country
    )
  }

  func prices(forSteamAppIDs appIDs: [Int]) async throws -> [Int: GamePrices] {
    guard !appIDs.isEmpty else { return [:] }

    let idsDeITAD = try await lookupITADIDs(forSteamAppIDs: appIDs)
    guard !idsDeITAD.isEmpty else { return [:] }

    let precios = try await prices(forITADIDs: Array(idsDeITAD.values))

    // Se vuelve a indexar por appid, que es como los conoce el resto de la app.
    return idsDeITAD.reduce(into: [:]) { resultado, par in
      let (appID, itadID) = par
      resultado[appID] = precios[itadID]
    }
  }

  /// Traduce appids de Steam a ids de ITAD, en tandas.
  ///
  /// Los que ITAD no conoce se quedan fuera del resultado.
  func lookupITADIDs(forSteamAppIDs appIDs: [Int]) async throws -> [Int: String] {
    var resultado: [Int: String] = [:]

    for tanda in appIDs.chunked(into: Self.tamanoDeTanda) {
      let claves = tanda.map(ITADShopLookupResponse.steamKey(appID:))
      let respuesta = try await client.post(
        ITADShopLookupResponse.self,
        to: try lookupURL(),
        body: claves
      )
      resultado.merge(respuesta.porSteamAppID) { actual, _ in actual }
    }

    return resultado
  }

  /// Pide los precios de una lista de ids de ITAD, en tandas.
  func prices(forITADIDs ids: [String]) async throws -> [String: GamePrices] {
    var resultado: [String: GamePrices] = [:]

    for tanda in ids.chunked(into: Self.tamanoDeTanda) {
      let respuesta = try await client.post(
        [ITADGamePricesDTO].self,
        to: try pricesURL(),
        body: tanda
      )

      // Se indexa por id y no por posicion: la respuesta puede traer menos
      // juegos de los que se pidieron.
      for dto in respuesta {
        resultado[dto.id] = Self.mapear(dto)
      }
    }

    return resultado
  }

  /// Convierte la respuesta de la API al tipo de dominio.
  ///
  /// De todas las tiendas se queda con la mas barata. La API las manda sin
  /// ordenar, asi que hay que buscarla; y se comparan solo las que estan en la
  /// misma moneda, porque mezclar monedas daria un "mas barato" falso.
  static func mapear(_ dto: ITADGamePricesDTO) -> GamePrices {
    let ofertas = (dto.deals ?? []).compactMap { oferta -> GameDeal? in
      guard let precio = oferta.price.money, let regular = oferta.regular.money else { return nil }
      return GameDeal(
        shopName: oferta.shop.name,
        price: precio,
        regular: regular,
        url: oferta.url.flatMap(URL.init(string:))
      )
    }

    let historico = dto.historyLow?.all?.money

    let masBarata = ofertas
      .filter { historico == nil || $0.price.currency == historico?.currency }
      .min { $0.price.amount < $1.price.amount }
      ?? ofertas.min { $0.price.amount < $1.price.amount }

    return GamePrices(itadID: dto.id, best: masBarata, historicalLow: historico)
  }

  // MARK: - URLs

  /// Arma la URL de la busqueda por id de tienda.
  ///
  /// Se expone aparte para poder verificar la construccion sin hacer la
  /// peticion, igual que en los servicios de Steam.
  func lookupURL() throws -> URL {
    try url(
      ruta: "/lookup/id/shop/\(Self.steamShopID)/v1",
      parametros: [URLQueryItem(name: "key", value: apiKey)]
    )
  }

  /// Arma la URL de la consulta de precios.
  func pricesURL() throws -> URL {
    try url(
      ruta: "/games/prices/v3",
      parametros: [
        URLQueryItem(name: "key", value: apiKey),
        URLQueryItem(name: "country", value: country)
      ]
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
