//
//  SteamWishlistDTO.swift
//  GameShelf
//

import Foundation

/// Respuesta de `IWishlistService/GetWishlist`.
///
/// Forma real:
/// ```json
/// { "response": { "items": [ { "appid": 268910, "priority": 0,
///                              "date_added": 1758333422 } ] } }
/// ```
///
/// Cuando la wishlist es privada, o esta vacia, Steam responde `{"response":{}}`
/// con HTTP 200: **no hay forma de distinguir los dos casos**. Por eso `items`
/// es opcional y quien llame decide que decirle al usuario.
struct SteamWishlistResponse: Decodable, Sendable {
  let response: Payload

  struct Payload: Decodable, Sendable {
    let items: [SteamWishlistItemDTO]?
  }

  /// Los juegos, o lista vacia si no vino ninguno.
  var items: [SteamWishlistItemDTO] { response.items ?? [] }

  /// Si Steam devolvio el objeto sin la lista.
  ///
  /// Distinto de "la lista llego vacia": eso ultimo no pasa en la practica,
  /// pero conviene no confundir ausencia con vacio.
  var isMissingItems: Bool { response.items == nil }
}

/// Un juego en la lista de deseos.
///
/// Trae solo el identificador: el nombre y la caratula hay que pedirlos aparte
/// a `IStoreBrowseService/GetItems`.
struct SteamWishlistItemDTO: Decodable, Sendable, Equatable {
  let appID: Int

  /// Orden que el usuario le puso en Steam. `0` significa sin prioridad.
  let priority: Int?

  /// Cuando se agrego a la lista, en segundos desde 1970.
  let dateAdded: Int?

  /// Cuando se agrego, ya como fecha.
  var addedAt: Date? {
    guard let dateAdded, dateAdded > 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(dateAdded))
  }

  enum CodingKeys: String, CodingKey {
    case appID = "appid"
    case priority
    case dateAdded = "date_added"
  }
}
