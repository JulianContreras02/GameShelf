//
//  SteamWishlistTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@Suite("Wishlist: decodificar la respuesta de Steam")
struct SteamWishlistDTOTests {

  @Test("Decodifica la wishlist real")
  func wishlistReal() throws {
    let respuesta = try Fixture.decode(SteamWishlistResponse.self, from: "steam_wishlist")

    #expect(respuesta.items.count == 10)
    #expect(!respuesta.isMissingItems)

    let cuphead = try #require(respuesta.items.first { $0.appID == 268910 })
    #expect(cuphead.addedAt != nil)
  }

  @Test("Una wishlist privada no se distingue de una vacia")
  func wishlistPrivada() throws {
    let respuesta = try Fixture.decode(SteamWishlistResponse.self, from: "steam_wishlist_privada")

    // Steam responde `{"response":{}}` con HTTP 200 en los dos casos. Lo unico
    // que se puede afirmar es que no vino la lista.
    #expect(respuesta.items.isEmpty)
    #expect(respuesta.isMissingItems)
  }

  @Test("Una fecha de cero no se convierte en 1970")
  func fechaVacia() {
    let sinFecha = SteamWishlistItemDTO(appID: 1, priority: 0, dateAdded: 0)
    #expect(sinFecha.addedAt == nil)
  }
}

@Suite("Wishlist: fichas de la tienda")
struct SteamStoreItemsDTOTests {

  private func fichas() throws -> [SteamStoreItemDTO] {
    try Fixture.decode(SteamStoreItemsResponse.self, from: "steam_store_items").items
  }

  @Test("Decodifica las diez fichas reales")
  func fichasReales() throws {
    let items = try fichas()

    #expect(items.count == 10)
    #expect(items.allSatisfy { $0.isUsable })

    let cuphead = try #require(items.first { $0.appID == 268910 })
    #expect(cuphead.name == "Cuphead")
    #expect(cuphead.releaseDate != nil)
    #expect(!cuphead.isComingSoon)
  }

  @Test("Los juegos sin lanzar se marcan como tales")
  func sinLanzar() throws {
    let proximos = try fichas().filter { $0.isComingSoon }

    #expect(!proximos.isEmpty, "El fixture deberia traer al menos un juego sin lanzar")

    // Steam informa el lanzamiento de una de dos formas, nunca las dos: o una
    // fecha aproximada (el 31 de diciembre quiere decir "en algun momento de
    // este ano") o un texto ("Proximamente"). Por eso la fila se fija en que la
    // fecha sea futura y no en que exista.
    for juego in proximos {
      let tieneFecha = juego.releaseDate != nil
      let tieneTexto = juego.releaseNote?.isEmpty == false

      #expect(tieneFecha || tieneTexto, "Un juego sin lanzar deberia decir algo de cuando sale")

      if let fecha = juego.releaseDate {
        #expect(fecha > Date(), "Un juego sin lanzar no puede tener fecha pasada")
      }
    }
  }

  @Test("La caratula sale del formato que manda Steam, no de una ruta armada a mano")
  func caratula() throws {
    let items = try fichas()

    // Un juego viejo: el archivo esta directo bajo el appid.
    let cuphead = try #require(items.first { $0.appID == 268910 })
    let urlCuphead = try #require(cuphead.coverURL?.absoluteString)
    #expect(urlCuphead.hasPrefix("https://shared.akamai.steamstatic.com/store_item_assets/"))
    #expect(urlCuphead.contains("steam/apps/268910/header.jpg"))

    // Uno reciente: el archivo cuelga de un hash, y armar la ruta a mano daria
    // 404. Esta prueba es la que evita volver a ese error.
    let reciente = try #require(items.first { $0.appID == 4348760 })
    let urlReciente = try #require(reciente.coverURL?.absoluteString)
    #expect(urlReciente.contains("/4348760/"))
    #expect(urlReciente.hasSuffix("header.jpg") || urlReciente.contains("header.jpg?"))
    #expect(!urlReciente.contains("${FILENAME}"), "Quedo el hueco sin sustituir")
    #expect(urlReciente.contains("/927c8308024d2461a680ad687efba5d500cc00cc/"))
  }

  @Test("La ficha de tienda se arma con el appid, no con el nombre")
  func enlaceDeTienda() throws {
    // La llamada que lanza va fuera del macro: dentro, el compilador no sabe
    // si el throw viene de la expresion o de la comprobacion.
    let items = try fichas()
    let cuphead = try #require(items.first { $0.appID == 268910 })

    // store_url_path trae "app/268910/Cuphead", que cambia si renombran el
    // juego. El appid solo, no.
    #expect(cuphead.storeURL?.absoluteString == "https://store.steampowered.com/app/268910")
  }

  @Test("Sin assets no se inventa una URL")
  func sinAssets() throws {
    let json = Data(#"{"response":{"store_items":[{"appid":1,"name":"X","success":1}]}}"#.utf8)
    let respuesta = try JSONDecoder().decode(SteamStoreItemsResponse.self, from: json)

    #expect(respuesta.items.first?.coverURL == nil)
  }
}

@Suite("Wishlist: armado de URLs")
struct SteamWishlistURLTests {

  private func servicio() -> SteamWishlistService {
    SteamWishlistService(client: StubHTTPClient(json: "{}"), steamID: "123")
  }

  @Test("La URL de la wishlist lleva el steamid y ninguna clave")
  func urlWishlist() throws {
    let url = try servicio().wishlistURL().absoluteString

    #expect(url.contains("/IWishlistService/GetWishlist/v1/"))
    #expect(url.contains("steamid=123"))
    // Este endpoint no necesita API key: mandarla seria exponerla de gratis.
    #expect(!url.contains("key="))
  }

  @Test("La URL de las fichas manda los appids en input_json")
  func urlFichas() throws {
    let url = try servicio().storeItemsURL(for: [10, 20]).absoluteString

    #expect(url.contains("/IStoreBrowseService/GetItems/v1/"))
    #expect(url.contains("input_json="))

    let decodificada = try #require(url.removingPercentEncoding)
    #expect(decodificada.contains("\"appid\":10"))
    #expect(decodificada.contains("\"appid\":20"))
    #expect(decodificada.contains("include_assets"))
  }

  @Test("Las tandas parten la lista y no pierden ni repiten nada")
  func tandas() {
    let todos = Array(1...125)
    let tandas = todos.chunked(into: SteamWishlistService.tamanoDeTanda)

    #expect(tandas.count == 3)
    #expect(tandas.map(\.count) == [50, 50, 25])
    #expect(tandas.flatMap { $0 } == todos)
  }

  @Test("Una lista vacia no produce tandas, y un tamano invalido no cuelga")
  func tandasBorde() {
    #expect([Int]().chunked(into: 10).isEmpty)
    #expect([1, 2, 3].chunked(into: 0) == [[1, 2, 3]])
  }
}
