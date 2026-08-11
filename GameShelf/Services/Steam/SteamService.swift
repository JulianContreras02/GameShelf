//
//  SteamService.swift
//  GameShelf
//

import Foundation

/// Acceso a los datos de Steam del usuario.
///
/// Es un protocolo para que los ViewModels dependan de esta forma y no de la
/// implementacion concreta, y se pueda inyectar un doble en las pruebas.
protocol SteamServicing: Sendable {
  /// Trae los juegos que el usuario posee en Steam.
  ///
  /// - Returns: Lista vacia si la biblioteca esta vacia **o** si el perfil es
  ///   privado: la API responde igual en los dos casos y no hay forma de
  ///   distinguirlos.
  /// - Throws: `NetworkError` si la peticion falla.
  func fetchOwnedGames() async throws -> [SteamGameDTO]
}

/// Implementacion real contra la Steam Web API.
struct SteamService: SteamServicing {

  /// Credenciales necesarias para consultar la API.
  struct Credentials: Sendable {
    let apiKey: String
    let steamID: String

    /// Las lee de `AppSecrets`, o sea del archivo de configuracion.
    ///
    /// - Throws: `AppSecrets.MissingSecretError` si falta alguna.
    static func fromAppSecrets(bundle: Bundle = .main) throws -> Credentials {
      Credentials(
        apiKey: try AppSecrets.value(for: .steamAPIKey, in: bundle),
        steamID: try AppSecrets.value(for: .steamID, in: bundle)
      )
    }
  }

  private let client: HTTPClient
  private let credentials: Credentials

  static let baseURL = URL(string: "https://api.steampowered.com")!

  init(client: HTTPClient, credentials: Credentials) {
    self.client = client
    self.credentials = credentials
  }

  /// Crea el servicio con las credenciales del archivo de configuracion.
  static func live(
    client: HTTPClient = URLSessionHTTPClient(),
    bundle: Bundle = .main
  ) throws -> SteamService {
    SteamService(client: client, credentials: try .fromAppSecrets(bundle: bundle))
  }

  func fetchOwnedGames() async throws -> [SteamGameDTO] {
    let url = try ownedGamesURL()
    let respuesta = try await client.get(SteamOwnedGamesResponse.self, from: url)
    return respuesta.response.games
  }

  /// Arma la URL de `GetOwnedGames`.
  ///
  /// Se expone aparte para poder verificar la construccion sin hacer la
  /// peticion.
  ///
  /// Los dos parametros de contenido importan y no son opcionales en la
  /// practica:
  /// - `include_appinfo=1` trae el nombre y el icono. Sin el, los juegos
  ///   llegan como puros numeros.
  /// - `include_played_free_games=1` incluye los free-to-play jugados. Sin el,
  ///   Steam los omite: en una biblioteca real la diferencia fue de 88 a 118
  ///   juegos y de 1220 a 2735 horas, porque el juego mas jugado era F2P.
  func ownedGamesURL() throws -> URL {
    let ruta = "/IPlayerService/GetOwnedGames/v1/"

    guard var componentes = URLComponents(
      url: Self.baseURL.appendingPathComponent(ruta),
      resolvingAgainstBaseURL: false
    ) else {
      throw NetworkError.invalidURL(Self.baseURL.absoluteString + ruta)
    }

    componentes.queryItems = [
      URLQueryItem(name: "key", value: credentials.apiKey),
      URLQueryItem(name: "steamid", value: credentials.steamID),
      URLQueryItem(name: "include_appinfo", value: "1"),
      URLQueryItem(name: "include_played_free_games", value: "1"),
      URLQueryItem(name: "format", value: "json")
    ]

    guard let url = componentes.url else {
      throw NetworkError.invalidURL(componentes.description)
    }

    return url
  }
}

extension URL {
  /// La URL con la API key oculta, para poder registrarla sin filtrar el
  /// secreto.
  ///
  /// La Steam Web API recibe la key como parametro de consulta, asi que la URL
  /// completa **es** informacion sensible y nunca debe imprimirse tal cual.
  var redactingSecrets: String {
    guard var componentes = URLComponents(url: self, resolvingAgainstBaseURL: false),
          let items = componentes.queryItems else {
      return absoluteString
    }

    let sensibles: Set<String> = ["key", "steamid", "access_token", "token"]
    componentes.queryItems = items.map { item in
      sensibles.contains(item.name.lowercased())
        ? URLQueryItem(name: item.name, value: "***")
        : item
    }

    return componentes.url?.absoluteString ?? absoluteString
  }
}
