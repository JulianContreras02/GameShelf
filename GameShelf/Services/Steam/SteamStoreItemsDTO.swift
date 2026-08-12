//
//  SteamStoreItemsDTO.swift
//  GameShelf
//

import Foundation

/// Respuesta de `IStoreBrowseService/GetItems`.
///
/// Es el complemento de la wishlist: esa devuelve solo appids, y esto convierte
/// una tanda de appids en nombres, caratulas y fechas de lanzamiento.
struct SteamStoreItemsResponse: Decodable, Sendable {
  let response: SteamStoreItemsPayload

  var items: [SteamStoreItemDTO] { response.storeItems ?? [] }
}

/// El contenido de la respuesta.
///
/// Va fuera y no anidado para no dejar sus `CodingKeys` a dos niveles.
struct SteamStoreItemsPayload: Decodable, Sendable {
  let storeItems: [SteamStoreItemDTO]?

  enum CodingKeys: String, CodingKey {
    case storeItems = "store_items"
  }
}

/// La ficha de tienda de un juego.
struct SteamStoreItemDTO: Decodable, Sendable {
  let appID: Int
  let name: String?

  /// `false` si el juego ya no se muestra en la tienda (retirado, por ejemplo).
  let visible: Bool?

  /// `1` si Steam pudo resolver el appid.
  let success: Int?

  let assets: SteamStoreAssets?
  let release: SteamStoreRelease?

  /// Ruta relativa de la ficha, del estilo `app/268910/Cuphead`.
  let storeURLPath: String?

  /// Si Steam devolvio datos utiles para este appid.
  var isUsable: Bool {
    success == 1 && name?.isEmpty == false
  }

  /// Ficha del juego en la tienda.
  ///
  /// Se arma con el appid y no con `store_url_path` porque esa ruta incluye el
  /// nombre y cambia si el juego se renombra; el appid solo, no.
  var storeURL: URL? {
    URL(string: "https://store.steampowered.com/app/\(appID)")
  }

  /// Caratula apaisada, la misma forma que usa el resto de la biblioteca.
  ///
  /// No se puede armar a mano como con los juegos que ya tienes: los titulos
  /// recientes guardan sus imagenes bajo un hash
  /// (`.../4348760/927c8308…/header.jpg`) y la ruta directa da 404. Por eso hay
  /// que usar el formato que manda Steam y sustituirle el nombre del archivo.
  var coverURL: URL? {
    assets?.url(for: \.header)
  }

  /// Cuando sale, o salio, el juego.
  var releaseDate: Date? { release?.date }

  /// Si todavia no ha salido.
  var isComingSoon: Bool { release?.isComingSoon == true }

  /// Texto que pone Steam cuando no hay fecha ("Proximamente", un trimestre).
  ///
  /// Steam usa una de las dos formas, nunca las dos: o una fecha aproximada
  /// (el 31 de diciembre quiere decir "en algun momento de este ano") o este
  /// texto.
  var releaseNote: String? { release?.customMessage }

  enum CodingKeys: String, CodingKey {
    case appID = "appid"
    case name
    case visible
    case success
    case assets
    case release
    case storeURLPath = "store_url_path"
  }
}

/// Imagenes de un juego en la tienda.
///
/// Va fuera de `SteamStoreItemDTO` y no anidado dentro para no dejar sus
/// `CodingKeys` a dos niveles de profundidad.
struct SteamStoreAssets: Decodable, Sendable {
  /// Plantilla con un hueco, del estilo `steam/apps/268910/${FILENAME}?t=1`.
  let urlFormat: String?
  let header: String?
  let libraryCapsule: String?

  /// Base del CDN de imagenes de tienda.
  ///
  /// Se usa el dominio de Akamai porque el de Cloudflare responde con una
  /// redireccion 301 para estas rutas.
  static let cdn = "https://shared.akamai.steamstatic.com/store_item_assets/"

  /// Arma la URL de una imagen concreta.
  func url(for imagen: KeyPath<SteamStoreAssets, String?>) -> URL? {
    guard let urlFormat,
          let archivo = self[keyPath: imagen],
          !archivo.isEmpty
    else { return nil }

    let ruta = urlFormat.replacingOccurrences(of: "${FILENAME}", with: archivo)
    return URL(string: Self.cdn + ruta)
  }

  enum CodingKeys: String, CodingKey {
    case urlFormat = "asset_url_format"
    case header
    case libraryCapsule = "library_capsule"
  }
}

/// Datos de lanzamiento de un juego.
struct SteamStoreRelease: Decodable, Sendable {
  let steamReleaseDate: Int?
  let isComingSoon: Bool?
  let customMessage: String?

  var date: Date? {
    guard let steamReleaseDate, steamReleaseDate > 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(steamReleaseDate))
  }

  enum CodingKeys: String, CodingKey {
    case steamReleaseDate = "steam_release_date"
    case isComingSoon = "is_coming_soon"
    case customMessage = "custom_release_date_message"
  }
}
