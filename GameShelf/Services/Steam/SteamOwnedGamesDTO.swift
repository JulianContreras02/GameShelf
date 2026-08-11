//
//  SteamOwnedGamesDTO.swift
//  GameShelf
//

import Foundation

/// Respuesta cruda de `IPlayerService/GetOwnedGames`.
///
/// Estos tipos reflejan **exactamente** lo que manda Steam, con sus nombres y
/// sus rarezas. No se guardan en SwiftData: se traducen a `Game` y se
/// descartan. Ver la regla 5 en `CONTRIBUTING.md`.
///
/// Ejemplo de respuesta:
/// ```json
/// { "response": { "game_count": 2, "games": [ ... ] } }
/// ```
struct SteamOwnedGamesResponse: Decodable, Equatable {
  let response: SteamOwnedGamesPayload
}

/// Contenido de la respuesta.
///
/// Steam devuelve `{"response":{}}` cuando el perfil es privado o la
/// biblioteca esta vacia: por eso los dos campos son opcionales y se exponen
/// con valores por defecto.
struct SteamOwnedGamesPayload: Decodable, Equatable {
  private let gameCount: Int?
  private let rawGames: [SteamGameDTO]?

  /// Cuantos juegos reporta Steam. `0` si no vino el dato.
  var count: Int { gameCount ?? 0 }

  /// Juegos de la biblioteca. Lista vacia si no vino el dato.
  var games: [SteamGameDTO] { rawGames ?? [] }

  /// `true` cuando Steam respondio sin datos.
  ///
  /// No distingue entre "perfil privado" y "biblioteca vacia": la API manda lo
  /// mismo en los dos casos. Quien llame decide como se lo explica al usuario.
  var isEmpty: Bool { games.isEmpty }

  enum CodingKeys: String, CodingKey {
    case gameCount = "game_count"
    case rawGames = "games"
  }
}

/// Un juego tal como lo describe Steam.
struct SteamGameDTO: Decodable, Equatable, Identifiable {
  /// Identificador del juego en Steam. Es la clave para todo lo demas.
  let appID: Int

  /// Nombre del juego. Solo viene si se pidio con `include_appinfo=1`.
  let name: String?

  /// Tiempo jugado **en minutos**, no en horas.
  let playtimeMinutes: Int?

  /// Minutos jugados en las ultimas dos semanas.
  ///
  /// Steam **solo manda este campo si hubo actividad reciente**: en una
  /// biblioteca real aparecio en 2 de 118 juegos. Que sea `nil` significa
  /// "no lo has tocado", no que falte el dato.
  let playtimeLast2WeeksMinutes: Int?

  /// Hash del icono. No es una URL: hay que construirla con `iconURL`.
  let iconHash: String?

  /// Ultima vez que se jugo, en segundos desde 1970. `0` significa nunca.
  let lastPlayedTimestamp: Int?

  var id: Int { appID }

  /// Tiempo jugado en horas, que es como se muestra en la app.
  var playtimeHours: Double {
    Double(playtimeMinutes ?? 0) / 60
  }

  /// Horas jugadas en las ultimas dos semanas, o `0` si no hubo actividad.
  var playtimeLast2WeeksHours: Double {
    Double(playtimeLast2WeeksMinutes ?? 0) / 60
  }

  /// Si el juego se toco en las ultimas dos semanas.
  ///
  /// Sirve para destacar lo que se esta jugando ahora sin tener que comparar
  /// fechas a mano.
  var isRecentlyPlayed: Bool {
    (playtimeLast2WeeksMinutes ?? 0) > 0
  }

  /// Ultima vez que se jugo, o `nil` si nunca.
  var lastPlayed: Date? {
    guard let timestamp = lastPlayedTimestamp, timestamp > 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(timestamp))
  }

  /// Caratula horizontal del juego.
  ///
  /// Se arma a partir del `appID`: Steam no la manda en esta respuesta.
  var coverURL: URL? {
    URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg")
  }

  /// Icono pequeño. Requiere el hash, que puede no venir.
  var iconURL: URL? {
    guard let iconHash, !iconHash.isEmpty else { return nil }
    return URL(
      string: "https://media.steampowered.com/steamcommunity/public/images/apps/\(appID)/\(iconHash).jpg"
    )
  }

  /// Ficha del juego en la tienda.
  var storeURL: URL? {
    URL(string: "https://store.steampowered.com/app/\(appID)")
  }

  enum CodingKeys: String, CodingKey {
    case appID = "appid"
    case name
    case playtimeMinutes = "playtime_forever"
    case playtimeLast2WeeksMinutes = "playtime_2weeks"
    case iconHash = "img_icon_url"
    case lastPlayedTimestamp = "rtime_last_played"
  }
}
