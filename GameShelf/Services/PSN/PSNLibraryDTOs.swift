//
//  PSNLibraryDTOs.swift
//  GameShelf
//

import Foundation

// MARK: - Lista de juegos jugados

/// Respuesta de `/gamelist/v2/users/me/titles`.
struct PSNGameListResponse: Decodable, Sendable {
  let titles: [PSNTitleDTO]?
  let totalItemCount: Int?

  /// Desde donde pedir la siguiente pagina. `nil` si ya no hay mas.
  let nextOffset: Int?

  var juegos: [PSNTitleDTO] { titles ?? [] }
}

/// Un juego jugado en PlayStation.
struct PSNTitleDTO: Decodable, Sendable {
  /// Identificador del juego en la tienda, del estilo `PPSA28038_00`.
  ///
  /// **No es el mismo que el de los trofeos**, que usan `npCommunicationId`
  /// (`NPWR49518_00`). Relacionarlos necesita un endpoint aparte.
  let titleId: String

  let name: String?

  /// El nombre en el idioma pedido. Suele coincidir con `name`.
  let localizedName: String?

  let imageUrl: String?
  let localizedImageUrl: String?

  /// Que clase de contenido es: `ps5_native_game`, `ps4_game`, `pspc_game`,
  /// `ps5_web_based_media_app`...
  let category: String?

  /// Cuantas veces se ha abierto.
  let playCount: Int?

  /// Tiempo jugado, en formato ISO 8601: `PT29H47M44S`.
  let playDuration: String?

  let firstPlayedDateTime: String?
  let lastPlayedDateTime: String?

  /// Si es un juego y no otra cosa.
  ///
  /// La lista trae tambien apps de video: Crunchyroll aparecio con categoria
  /// `ps5_web_based_media_app` y 15 segundos de uso. Meterlas en la biblioteca
  /// la ensuciaria con cosas que el usuario no considera juegos.
  var esJuego: Bool {
    guard let category else { return false }
    return category.contains("game")
  }

  /// El nombre a mostrar, prefiriendo el localizado.
  var nombre: String? {
    let elegido = localizedName ?? name
    return elegido?.isEmpty == false ? elegido : nil
  }

  /// La caratula, prefiriendo la localizada.
  var coverURL: URL? {
    (localizedImageUrl ?? imageUrl).flatMap(URL.init(string:))
  }

  /// Horas jugadas. `nil` si la duracion no se pudo leer.
  var playtimeHours: Double? {
    ISO8601Duration.hours(from: playDuration)
  }

  var lastPlayedAt: Date? { Self.fecha(lastPlayedDateTime) }
  var firstPlayedAt: Date? { Self.fecha(firstPlayedDateTime) }

  /// Las fechas llegan con fracciones de segundo (`...T02:43:03.060000Z`) y a
  /// veces sin ellas, asi que se prueban las dos formas.
  static func fecha(_ texto: String?) -> Date? {
    guard let texto else { return nil }

    let conFracciones = ISO8601DateFormatter()
    conFracciones.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let fecha = conFracciones.date(from: texto) { return fecha }

    let simple = ISO8601DateFormatter()
    simple.formatOptions = [.withInternetDateTime]
    return simple.date(from: texto)
  }
}

// MARK: - Trofeos por juego

/// Respuesta de `/trophy/v1/users/me/titles/trophyTitles?npTitleIds=...`.
///
/// Es la que relaciona los dos mundos: recibe ids de juego y devuelve los sets
/// de trofeos de cada uno.
///
/// **Los resultados no vienen en el orden en que se pidieron.** Hay que
/// indexarlos por `npTitleId`.
struct PSNTrophyMapResponse: Decodable, Sendable {
  let titles: [PSNTitleTrophiesDTO]?

  /// El progreso de cada juego, indexado por su id de tienda.
  ///
  /// Si un juego tiene varios sets de trofeos se toma el mas avanzado: es el
  /// que el usuario reconoce como "lo que llevo".
  var progresoPorTitleID: [String: PSNTrophyTitleDTO] {
    (titles ?? []).reduce(into: [:]) { resultado, entrada in
      let mejor = (entrada.trophyTitles ?? []).max { ($0.progress ?? 0) < ($1.progress ?? 0) }
      guard let mejor else { return }
      resultado[entrada.npTitleId] = mejor
    }
  }
}

/// Los sets de trofeos de un juego.
struct PSNTitleTrophiesDTO: Decodable, Sendable {
  let npTitleId: String

  /// Puede venir vacio: hay juegos sin trofeos.
  let trophyTitles: [PSNTrophyTitleDTO]?
}

/// Un set de trofeos.
struct PSNTrophyTitleDTO: Decodable, Sendable {
  let npCommunicationId: String?
  let trophyTitleName: String?

  /// Porcentaje conseguido, de 0 a 100. Ya viene calculado por Sony.
  let progress: Int?

  let earnedTrophies: PSNTrophyCountsDTO?
  let definedTrophies: PSNTrophyCountsDTO?
}

/// Cuantos trofeos hay de cada tipo.
struct PSNTrophyCountsDTO: Decodable, Sendable {
  let bronze: Int?
  let silver: Int?
  let gold: Int?
  let platinum: Int?

  var total: Int {
    (bronze ?? 0) + (silver ?? 0) + (gold ?? 0) + (platinum ?? 0)
  }
}
