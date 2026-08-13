//
//  ITADServiceTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

@Suite("ITAD: importes")
struct MoneyTests {

  @Test("Los centavos evitan el error de la coma flotante")
  func centavosExactos() {
    // 19.99 decodificado desde un Double da 19.989999999999998. Por eso se usa
    // amountInt y no amount.
    let desdeCentavos = Money(minorUnits: 1999, currency: "USD")
    #expect(desdeCentavos.amount == Decimal(string: "19.99"))

    let dto = ITADPriceDTO(amount: 19.99, amountInt: 1999, currency: "USD")
    #expect(dto.money?.amount == Decimal(string: "19.99"))
  }

  @Test("Sin moneda no se arma un importe")
  func sinMoneda() {
    #expect(ITADPriceDTO(amount: 10, amountInt: 1000, currency: nil).money == nil)
    #expect(ITADPriceDTO(amount: 10, amountInt: 1000, currency: "").money == nil)
  }

  @Test("El descuento se calcula sobre el precio lleno")
  func descuento() {
    let regular = Money(minorUnits: 1999, currency: "USD")
    let rebajado = Money(minorUnits: 999, currency: "USD")

    #expect(rebajado.discount(from: regular) == 50)
    #expect(regular.discount(from: regular) == 0)
  }

  @Test("No se comparan monedas distintas")
  func monedasDistintas() {
    let dolares = Money(minorUnits: 1999, currency: "USD")
    let euros = Money(minorUnits: 999, currency: "EUR")

    // Restar euros a dolares daria un porcentaje inventado.
    #expect(euros.discount(from: dolares) == nil)
  }

  @Test("Un precio regular de cero no divide por cero")
  func regularEnCero() {
    let gratis = Money(minorUnits: 0, currency: "USD")
    #expect(gratis.discount(from: gratis) == nil)
  }

  @Test("El formato lleva la moneda de la tienda, no la del sistema")
  func formato() {
    let dolares = Money(minorUnits: 1999, currency: "USD")
    let texto = dolares.formatted(locale: Locale(identifier: "es_CO"))

    // Un colombiano viendo un precio en dolares tiene que notarlo: "$19.99" a
    // secas se leeria como pesos.
    #expect(texto.contains("19"))
    #expect(texto.contains("US") || texto.contains("USD"))
  }
}

@Suite("ITAD: decodificar respuestas reales")
struct ITADDecodingTests {

  private func precios() throws -> [ITADGamePricesDTO] {
    try Fixture.decode([ITADGamePricesDTO].self, from: "itad_precios")
  }

  @Test("La respuesta puede traer menos juegos de los que se pidieron")
  func respuestaIncompleta() throws {
    // El fixture se genero pidiendo tres juegos. El tercero no ha salido y no
    // se vende en ninguna tienda, asi que la API simplemente no lo devuelve.
    // Emparejar por posicion asignaria los precios al juego equivocado.
    let dtos = try precios()
    #expect(dtos.count == 2, "Se pidieron 3 y la API devolvio 2")
  }

  @Test("Decodifica precios, minimo historico y ofertas")
  func decodifica() throws {
    let dtos = try precios()
    let cuphead = try #require(dtos.first { $0.id.hasPrefix("018d937e") })

    #expect(cuphead.historyLow?.all?.money == Money(minorUnits: 1199, currency: "USD"))
    #expect((cuphead.deals ?? []).count == 6)

    let tiendas = Set((cuphead.deals ?? []).map(\.shop.name))
    #expect(tiendas.contains("Steam"))
  }

  @Test("El lookup en lote separa los encontrados de los que no")
  func lookup() throws {
    let respuesta = try Fixture.decode(ITADShopLookupResponse.self, from: "itad_lookup")
    let porAppID = respuesta.porSteamAppID

    #expect(porAppID.count == 3, "Se pidieron 4 y uno no existe")
    #expect(porAppID[268910] == "018d937e-ffba-7200-8bc4-99eccd424fa1")
    #expect(porAppID[999999999] == nil, "Un appid inventado no debe aparecer")
  }

  @Test("La clave de Steam lleva el prefijo app/")
  func claveDeSteam() {
    // Mandar el appid pelado devuelve null para todo, sin error: un fallo
    // silencioso que costo encontrar.
    #expect(ITADShopLookupResponse.steamKey(appID: 268910) == "app/268910")
  }
}

@Suite("ITAD: mapeo al modelo de dominio")
struct ITADMappingTests {

  /// Una oferta de prueba, con los importes en centavos.
  struct Oferta {
    var tienda: String
    var precio: Int
    var regular: Int
    var moneda = "USD"
  }

  private func mapear(_ id: String = "x", ofertas: [Oferta], historico: Int?) -> GamePrices {
    let deals = ofertas.map { oferta in
      ITADDealDTO(
        shop: ITADShopDTO(id: 1, name: oferta.tienda),
        price: ITADPriceDTO(amount: nil, amountInt: oferta.precio, currency: oferta.moneda),
        regular: ITADPriceDTO(amount: nil, amountInt: oferta.regular, currency: oferta.moneda),
        cut: nil,
        url: "https://itad.link/abc/"
      )
    }
    let low = historico.map { ITADPriceDTO(amount: nil, amountInt: $0, currency: "USD") }
    let minimos = ITADHistoryLowDTO(all: low, ultimoAno: nil, ultimosTresMeses: nil)
    return ITADService.mapear(
      ITADGamePricesDTO(id: id, historyLow: minimos, deals: deals)
    )
  }

  @Test("Se queda con la oferta mas barata, no con la primera")
  func masBarata() {
    // La API manda las tiendas sin ordenar.
    let precios = mapear(ofertas: [
      Oferta(tienda: "GreenManGaming", precio: 1999, regular: 1999),
      Oferta(tienda: "Fanatical", precio: 999, regular: 1999),
      Oferta(tienda: "Steam", precio: 1499, regular: 1999)
    ], historico: 799)

    #expect(precios.best?.shopName == "Fanatical")
    #expect(precios.best?.discountPercent == 50)
    #expect(precios.isOnSale)
  }

  @Test("Detecta cuando el precio iguala el minimo historico")
  func minimoHistorico() {
    let enMinimo = mapear(ofertas: [Oferta(tienda: "Steam", precio: 799, regular: 1999)], historico: 799)
    #expect(enMinimo.isAtHistoricalLow)

    let porEncima = mapear(ofertas: [Oferta(tienda: "Steam", precio: 999, regular: 1999)], historico: 799)
    #expect(!porEncima.isAtHistoricalLow)

    // Un 50% de descuento no dice nada si ya estuvo mas barato.
    #expect(porEncima.isOnSale)
    #expect(!porEncima.isAtHistoricalLow)
  }

  @Test("Un juego sin ofertas no inventa un precio")
  func sinOfertas() {
    let precios = mapear(ofertas: [], historico: nil)

    #expect(precios.best == nil)
    #expect(precios.historicalLow == nil)
    #expect(!precios.isOnSale)
    #expect(!precios.isAtHistoricalLow)
  }

  @Test("No se compara contra un minimo historico en otra moneda")
  func monedasMezcladas() {
    let precios = mapear(
      ofertas: [Oferta(tienda: "Tienda", precio: 500, regular: 1999, moneda: "EUR")],
      historico: 799
    )

    // El minimo esta en USD y la oferta en EUR: decir que esta en minimo
    // historico seria mentir.
    #expect(!precios.isAtHistoricalLow)
  }

  @Test("Mapea la respuesta real completa")
  func respuestaReal() throws {
    let dtos = try Fixture.decode([ITADGamePricesDTO].self, from: "itad_precios")
    let cuphead = try #require(dtos.first { $0.id.hasPrefix("018d937e") })

    let precios = ITADService.mapear(cuphead)

    #expect(precios.best != nil)
    #expect(precios.historicalLow == Money(minorUnits: 1199, currency: "USD"))
    #expect(precios.best?.price.currency == "USD", "Colombia se factura en dolares")
    #expect(precios.best?.url != nil)
  }
}

@Suite("ITAD: peticiones")
struct ITADRequestTests {

  private func servicio(_ client: HTTPClient) -> ITADService {
    ITADService(client: client, apiKey: "CLAVE", country: "CO")
  }

  @Test("Las URLs llevan la clave y el pais")
  func urls() throws {
    let itad = servicio(StubHTTPClient(json: "{}"))

    let lookup = try itad.lookupURL().absoluteString
    #expect(lookup.contains("/lookup/id/shop/61/v1"), "61 es la tienda Steam en ITAD")
    #expect(lookup.contains("key=CLAVE"))

    let precios = try itad.pricesURL().absoluteString
    #expect(precios.contains("/games/prices/v3"))
    #expect(precios.contains("country=CO"))
  }

  @Test("Consulta en lote: una peticion por tanda, no una por juego")
  func consultaEnLote() async throws {
    let cliente = RoutingHTTPClient(rutas: [
      ("lookup/id/shop", #"{"app/1":"aaa","app/2":"bbb","app/3":"ccc"}"#),
      ("games/prices", #"[{"id":"aaa","historyLow":null,"deals":[]}]"#)
    ])

    _ = try await servicio(cliente).prices(forSteamAppIDs: [1, 2, 3])

    // Tres juegos, dos peticiones: una para traducir los ids y otra para los
    // precios. Ese es el criterio del issue.
    #expect(cliente.requestedURLs.count == 2)

    // Y los tres juegos van en el mismo cuerpo, no uno por peticion.
    let cuerpo = try #require(cliente.sentBodies.first)
    for appID in [1, 2, 3] {
      #expect(cuerpo.contains("app\\/\(appID)"), "Falta el appid \(appID) en el lote")
    }
  }

  @Test("Los juegos que ITAD no conoce no aparecen en el resultado")
  func juegosDesconocidos() async throws {
    let cliente = RoutingHTTPClient(rutas: [
      ("lookup/id/shop", #"{"app/1":"aaa","app/2":null}"#),
      ("games/prices", #"[{"id":"aaa","historyLow":null,"deals":[]}]"#)
    ])

    let precios = try await servicio(cliente).prices(forSteamAppIDs: [1, 2])

    #expect(precios[1] != nil)
    #expect(precios[2] == nil, "El appid 2 no lo conoce ITAD")
  }

  @Test("Un juego conocido pero sin precios tampoco aparece")
  func sinPrecios() async throws {
    // Es el caso de los juegos que todavia no han salido: ITAD los conoce, pero
    // la respuesta de precios no los incluye.
    let cliente = RoutingHTTPClient(rutas: [
      ("lookup/id/shop", #"{"app/1":"aaa","app/2":"bbb"}"#),
      ("games/prices", #"[{"id":"aaa","historyLow":null,"deals":[]}]"#)
    ])

    let precios = try await servicio(cliente).prices(forSteamAppIDs: [1, 2])

    #expect(precios[1] != nil)
    #expect(precios[2] == nil)
  }

  @Test("Con la lista vacia no se hace ninguna peticion")
  func listaVacia() async throws {
    let cliente = RoutingHTTPClient(rutas: [])

    let precios = try await servicio(cliente).prices(forSteamAppIDs: [])

    #expect(precios.isEmpty)
    #expect(cliente.requestedURLs.isEmpty)
  }

  @Test("Si el lookup no encuentra nada, no se piden precios")
  func lookupVacio() async throws {
    let cliente = RoutingHTTPClient(rutas: [("lookup/id/shop", #"{"app/1":null}"#)])

    let precios = try await servicio(cliente).prices(forSteamAppIDs: [1])

    #expect(precios.isEmpty)
    #expect(cliente.requestedURLs.count == 1, "No tiene sentido pedir precios de cero juegos")
  }

  @Test("Las tandas respetan el limite de la API")
  func tandas() {
    #expect(ITADService.tamanoDeTanda == 200, "La API acepta hasta 200 por peticion")

    let muchos = Array(1...450)
    let tandas = muchos.chunked(into: ITADService.tamanoDeTanda)
    #expect(tandas.map(\.count) == [200, 200, 50])
  }
}

@Suite("ITAD: credenciales en el llavero")
struct ITADCredentialsTests {

  @Test("Sin clave guardada, avisa en vez de fallar en la red")
  func sinClave() throws {
    #expect(throws: ITADCredentialsError.notConnected) {
      _ = try ITADService.live(client: StubHTTPClient(json: "{}"), keychain: InMemoryKeychainStore())
    }
  }

  @Test("Con clave guardada, live() la usa")
  func conClave() throws {
    let llavero = InMemoryKeychainStore()
    try ITADService.save(apiKey: "CLAVE_GUARDADA", to: llavero)

    let itad = try ITADService.live(client: StubHTTPClient(json: "{}"), keychain: llavero)

    #expect(try itad.pricesURL().absoluteString.contains("key=CLAVE_GUARDADA"))
  }

  @Test("hasAPIKey refleja si hay algo guardado")
  func hasAPIKey() throws {
    let llavero = InMemoryKeychainStore()
    #expect(ITADService.hasAPIKey(in: llavero) == false)

    try ITADService.save(apiKey: "CLAVE", to: llavero)
    #expect(ITADService.hasAPIKey(in: llavero) == true)
  }

  @Test("Borrar la clave la quita del llavero")
  func borrar() throws {
    let llavero = InMemoryKeychainStore()
    try ITADService.save(apiKey: "CLAVE", to: llavero)

    try ITADService.removeAPIKey(from: llavero)

    #expect(ITADService.hasAPIKey(in: llavero) == false)
  }
}
