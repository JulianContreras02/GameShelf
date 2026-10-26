//
//  XboxLibraryDTOs.swift
//  GameShelf
//

import Foundation

// MARK: - Historial de juegos (TitleHub)

/// Respuesta de `titlehub.xboxlive.com/users/xuid(...)/titles/titlehistory`.
///
/// No viene paginada: trae de una vez hasta `maxItems` juegos.
struct XboxTitleHistoryResponse: Decodable, Sendable {
  let xuid: String?
  let titles: [XboxTitleDTO]?

  /// Solo los juegos, sin las apps.
  var juegos: [XboxTitleDTO] { (titles ?? []).filter(\.esJuego) }
}

/// Un juego del historial de Xbox.
///
/// Es un **historial**, no la lista de lo comprado: solo aparece lo que se
/// abrio alguna vez, en consola o en PC. Un juego comprado y nunca abierto no
/// sale, a diferencia de Steam y Epic.
struct XboxTitleDTO: Decodable, Sendable {
  /// Identificador del juego, del estilo `1560034050`. Llega como texto.
  let titleId: String

  let name: String?

  /// `Game` o `App`. El historial mezcla los dos.
  let type: String?

  /// Donde se jugo: `XboxOne`, `XboxSeries`, `PC`, `Win32`, `Xbox360`...
  let devices: [String]?

  /// La imagen principal. Suele ser cuadrada.
  let displayImage: String?

  /// Todas las imagenes del juego, por tipo. Solo vienen si se pide la
  /// decoracion `image`.
  let images: [XboxImageDTO]?

  /// El identificador que piden las estadisticas (`userstats`). Solo viene si
  /// se pide la decoracion `scid`, y no lo tienen todos: los juegos de PC sin
  /// Xbox Live, por ejemplo, no tienen estadisticas.
  let serviceConfigId: String?

  let achievement: XboxAchievementSummaryDTO?
  let titleHistory: XboxTitleHistoryDTO?

  /// Si es un juego y no otra cosa.
  ///
  /// Igual que en PSN, el historial trae tambien apps (la de video, la de
  /// musica...), y meterlas en la biblioteca la ensuciaria.
  var esJuego: Bool { type == "Game" }

  /// El nombre a mostrar. `nil` si llego vacio.
  var nombre: String? {
    guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return name
  }

  /// La caratula, prefiriendo una apaisada.
  ///
  /// La app ensena las caratulas con la proporcion del header de Steam
  /// (460×215). La mas parecida de Xbox es `TitledHeroArt`: 16:9 y con el
  /// nombre del juego encima, como el header. Despues `SuperHeroArt`, la misma
  /// sin nombre, y `BoxArt`, que es cuadrada. Si no hay ninguna, sirve
  /// `displayImage`: mejor una imagen con otra proporcion que un hueco gris.
  var coverURL: URL? {
    for tipo in ["TitledHeroArt", "SuperHeroArt", "BoxArt"] {
      if let imagen = images?.first(where: { $0.type == tipo }), let url = Self.urlSegura(imagen.url) {
        return url
      }
    }
    return Self.urlSegura(displayImage)
  }

  var lastPlayedAt: Date? { Self.fecha(titleHistory?.lastTimePlayed) }

  /// Pasa una imagen a HTTPS.
  ///
  /// Xbox manda las imagenes con `http://`, y iOS no carga nada que no sea
  /// HTTPS (App Transport Security): sin esto, todas las caratulas de Xbox
  /// saldrian en gris. `images-eds.xboxlive.com` tiene su version segura en
  /// otro host, el mismo que usan las fotos de perfil de Xbox.
  static func urlSegura(_ texto: String?) -> URL? {
    guard let texto, !texto.isEmpty, var componentes = URLComponents(string: texto) else { return nil }

    if componentes.scheme == "http" {
      componentes.scheme = "https"
    }
    if componentes.host == "images-eds.xboxlive.com" {
      componentes.host = "images-eds-ssl.xboxlive.com"
    }
    return componentes.url
  }

  /// Las fechas llegan con siete digitos de fraccion
  /// (`"2020-10-08T01:55:12.4411936Z"`), mas de los que admite
  /// `ISO8601DateFormatter`. Se quita la fraccion, igual que con el
  /// vencimiento del XSTS: nadie necesita la ultima partida al microsegundo.
  static func fecha(_ texto: String?) -> Date? {
    guard let texto, !texto.isEmpty else { return nil }

    var limpio = texto
    if let punto = texto.firstIndex(of: ".") {
      // Lo que queda tras los digitos es la zona horaria: "Z" en todo lo visto.
      let zona = texto[punto...].dropFirst().drop { $0.isNumber }
      limpio = String(texto[..<punto]) + zona
    }
    return ISO8601DateFormatter().date(from: limpio)
  }
}

/// Una imagen del juego.
struct XboxImageDTO: Decodable, Sendable {
  let url: String?

  /// `TitledHeroArt`, `SuperHeroArt`, `BoxArt`, `Poster`, `Screenshot`...
  let type: String?
}

/// El resumen de logros de un juego.
struct XboxAchievementSummaryDTO: Decodable, Sendable {
  let currentAchievements: Int?

  /// **No es fiable**: en los datos de referencia llega en 0 aunque
  /// `currentAchievements` diga 22. Por eso no se usa.
  let totalAchievements: Int?

  let currentGamerscore: Int?
  let totalGamerscore: Int?

  /// Ya viene calculado por Xbox, sobre el Gamerscore.
  let progressPercentage: Double?

  /// El Gamerscore, si el juego tiene logros.
  ///
  /// Un juego sin logros manda todo en 0, y eso es "no aplica", no "0 de 0":
  /// devuelve `nil`.
  var gamerscore: Gamerscore? {
    guard let total = totalGamerscore, total > 0 else { return nil }
    return Gamerscore(earned: currentGamerscore ?? 0, total: total)
  }
}

/// Cuando se jugo por ultima vez.
struct XboxTitleHistoryDTO: Decodable, Sendable {
  let lastTimePlayed: String?
}

// MARK: - Tiempo jugado (userstats)

/// Cuerpo de `userstats.xboxlive.com/batch`, pidiendo los minutos jugados.
///
/// La forma, con un grupo `Hero` y una estadistica por juego, es la que usa
/// OpenXbox/xbox-webapi para un juego. Aca se repite el par por cada juego de
/// la tanda.
struct XboxStatsBatchRequest: Encodable, Sendable {
  let arrangebyfield = "xuid"
  let xuids: [String]
  let groups: [Grupo]
  let stats: [Estadistica]

  struct Grupo: Encodable, Sendable {
    let name = "Hero"
    let scid: String
  }

  struct Estadistica: Encodable, Sendable {
    let name = XboxStatDTO.minutosJugados
    let scid: String
  }

  init(xuid: String, scids: [String]) {
    xuids = [xuid]
    groups = scids.map { Grupo(scid: $0) }
    stats = scids.map { Estadistica(scid: $0) }
  }
}

/// Respuesta de `userstats.xboxlive.com/batch`.
///
/// Trae tambien los grupos `Hero`, que son estadisticas propias de cada juego
/// ("cofres entregados", "distancia navegada"). No hacen falta y no se leen.
struct XboxStatsBatchResponse: Decodable, Sendable {
  let statlistscollection: [XboxStatListDTO]?

  /// Minutos jugados por juego, indexados por su scid en minusculas.
  ///
  /// Se indexa por scid y no por posicion, igual que los trofeos de PSN: nada
  /// garantiza que las respuestas lleguen en el orden en que se pidieron.
  var minutosPorSCID: [String: Double] {
    var resultado: [String: Double] = [:]
    for lista in statlistscollection ?? [] {
      for estadistica in lista.stats ?? [] where estadistica.name == XboxStatDTO.minutosJugados {
        guard let scid = estadistica.scid?.lowercased(), let minutos = estadistica.value else { continue }
        resultado[scid] = max(resultado[scid] ?? 0, minutos)
      }
    }
    return resultado
  }
}

/// Las estadisticas de un usuario.
struct XboxStatListDTO: Decodable, Sendable {
  let stats: [XboxStatDTO]?
}

/// Una estadistica.
struct XboxStatDTO: Decodable, Sendable {
  /// El nombre de la estadistica de tiempo jugado.
  static let minutosJugados = "MinutesPlayed"

  let scid: String?
  let name: String?

  /// El valor, ya como numero.
  ///
  /// Xbox lo manda como texto (`"value": "1220"`) aunque diga que es
  /// `Integer`. Se acepta tambien como numero por si un dia cambia: perder
  /// todas las horas por las comillas seria absurdo.
  let value: Double?

  enum CodingKeys: String, CodingKey {
    case scid, name, value
  }

  init(from decoder: Decoder) throws {
    let contenedor = try decoder.container(keyedBy: CodingKeys.self)
    scid = try contenedor.decodeIfPresent(String.self, forKey: .scid)
    name = try contenedor.decodeIfPresent(String.self, forKey: .name)

    if let texto = try? contenedor.decode(String.self, forKey: .value) {
      value = Double(texto)
    } else {
      value = try? contenedor.decode(Double.self, forKey: .value)
    }
  }
}
