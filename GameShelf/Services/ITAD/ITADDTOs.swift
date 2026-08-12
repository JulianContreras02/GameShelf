//
//  ITADDTOs.swift
//  GameShelf
//

import Foundation

// MARK: - Precios

/// Un juego en la respuesta de `POST /games/prices/v3`.
///
/// Ojo con dos cosas de esta respuesta:
///
/// 1. Es un arreglo, pero **puede traer menos juegos de los que se pidieron**.
///    Los que la API no conoce, o que no se venden en ningun lado (un juego que
///    todavia no ha salido, por ejemplo), simplemente no aparecen. Por eso
///    quien la consuma tiene que indexar por `id` y nunca emparejar por
///    posicion.
/// 2. `deals` trae **todas** las tiendas, no solo las que tienen descuento, y
///    no vienen ordenadas por precio.
struct ITADGamePricesDTO: Decodable, Sendable {
  let id: String
  let historyLow: ITADHistoryLowDTO?
  let deals: [ITADDealDTO]?
}

/// Minimos historicos en distintas ventanas de tiempo.
struct ITADHistoryLowDTO: Decodable, Sendable {
  /// El minimo de siempre. Es el que interesa.
  let all: ITADPriceDTO?

  /// Minimo del ultimo ano.
  let ultimoAno: ITADPriceDTO?

  /// Minimo de los ultimos tres meses.
  let ultimosTresMeses: ITADPriceDTO?

  // La API los llama "y1" y "m3"; se renombran porque nombres de dos letras no
  // dicen nada en el sitio donde se leen.
  enum CodingKeys: String, CodingKey {
    case all
    case ultimoAno = "y1"
    case ultimosTresMeses = "m3"
  }
}

/// Una oferta concreta en una tienda.
struct ITADDealDTO: Decodable, Sendable {
  let shop: ITADShopDTO
  let price: ITADPriceDTO
  let regular: ITADPriceDTO

  /// Porcentaje de descuento que reporta la tienda. `0` si esta a precio lleno.
  let cut: Int?

  /// Enlace de afiliado de ITAD que redirige a la tienda.
  let url: String?
}

struct ITADShopDTO: Decodable, Sendable {
  let id: Int
  let name: String
}

/// Un importe tal como lo manda la API.
struct ITADPriceDTO: Decodable, Sendable {
  /// El valor con decimales. **No usar para calcular**: llega como numero de
  /// coma flotante y pierde precision al convertirlo.
  let amount: Double?

  /// El mismo valor en centavos, exacto. Es el que se usa.
  let amountInt: Int?

  /// Codigo ISO 4217.
  let currency: String?

  /// El importe ya como valor de dominio, o `nil` si la respuesta venia
  /// incompleta.
  var money: Money? {
    guard let currency, !currency.isEmpty else { return nil }
    if let amountInt {
      return Money(minorUnits: amountInt, currency: currency)
    }
    guard let amount else { return nil }
    return Money(amount: Decimal(amount), currency: currency)
  }
}

// MARK: - Busqueda por id de tienda

/// Respuesta de `POST /lookup/id/shop/{shopId}/v1`.
///
/// Es un diccionario plano `{"app/268910": "uuid", "app/999": null}`: la clave
/// es el id **dentro de la tienda** y el valor el id de ITAD, o `null` si no lo
/// conoce.
///
/// Para Steam la clave no es el appid pelado sino `app/<appid>`. Mandar solo el
/// numero devuelve `null` para todo, sin error: un fallo silencioso facil de no
/// notar.
struct ITADShopLookupResponse: Decodable, Sendable {
  let porIDDeTienda: [String: String?]

  init(from decoder: Decoder) throws {
    let contenedor = try decoder.singleValueContainer()
    porIDDeTienda = try contenedor.decode([String: String?].self)
  }

  /// Prefijo que usa Steam para sus ids dentro de ITAD.
  static func steamKey(appID: Int) -> String { "app/\(appID)" }

  /// Traduce el diccionario crudo a `appid -> id de ITAD`, dejando fuera los
  /// que no se encontraron.
  var porSteamAppID: [Int: String] {
    porIDDeTienda.reduce(into: [:]) { resultado, par in
      let (clave, valor) = par
      guard let valor,
            clave.hasPrefix("app/"),
            let appID = Int(clave.dropFirst("app/".count))
      else { return }
      resultado[appID] = valor
    }
  }
}
