//
//  SteamPlayerSummaryDTO.swift
//  GameShelf
//

import Foundation

/// Respuesta cruda de `ISteamUser/GetPlayerSummaries`.
///
/// Como los demas DTOs de Steam, refleja lo que manda la API y no se guarda:
/// se traduce a `SteamPresence` y se descarta.
///
/// Ejemplo de respuesta:
/// ```json
/// { "response": { "players": [ { "steamid": "...", "gameid": "730", "gameextrainfo": "Counter-Strike 2" } ] } }
/// ```
struct SteamPlayerSummariesResponse: Decodable, Equatable {
  let response: SteamPlayerSummariesPayload
}

/// Contenido de la respuesta.
///
/// Si el SteamID no existe, Steam responde con la lista vacia, no con un
/// error.
struct SteamPlayerSummariesPayload: Decodable, Equatable {
  private let rawPlayers: [SteamPlayerSummaryDTO]?

  /// Perfiles devueltos. Lista vacia si no vino el dato.
  var players: [SteamPlayerSummaryDTO] { rawPlayers ?? [] }

  enum CodingKeys: String, CodingKey {
    case rawPlayers = "players"
  }
}

/// Un perfil de Steam, con solo los campos que hacen falta para la presencia.
struct SteamPlayerSummaryDTO: Decodable, Equatable {
  let steamID: String

  /// Quien puede ver el perfil: `3` es publico, `1` es cualquier otra cosa
  /// (privado, solo amigos...).
  let communityVisibilityState: Int?

  /// El appid del juego en curso, **como texto**. No viene si no esta jugando
  /// a nada, ni si el perfil no es publico.
  let gameID: String?

  /// El nombre del juego en curso.
  let gameExtraInfo: String?

  /// Valor de `communityvisibilitystate` para un perfil publico.
  static let perfilPublico = 3

  /// Si Steam deja ver lo que esta jugando.
  ///
  /// El juego en curso es un dato "privado" para Steam: solo lo manda de
  /// perfiles publicos.
  var isPublic: Bool { communityVisibilityState == Self.perfilPublico }

  enum CodingKeys: String, CodingKey {
    case steamID = "steamid"
    case communityVisibilityState = "communityvisibilitystate"
    case gameID = "gameid"
    case gameExtraInfo = "gameextrainfo"
  }
}
