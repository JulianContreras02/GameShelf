//
//  LibraryInsights.swift
//  GameShelf
//

import Foundation

/// Clasifica la biblioteca sola, a partir de lo que ya sabe la app.
///
/// Complementa el estado manual (#16) en vez de reemplazarlo: con 118 juegos,
/// marcarlos uno a uno no escala, pero las horas que reporta Steam ya dicen
/// mucho.
///
/// Es un tipo sin estado, con funciones puras: la clasificacion se prueba sin
/// levantar pantalla ni base de datos.
enum LibraryInsights {

  /// Por debajo de cuantas horas se considera que un juego solo se "probo".
  static let barelyTriedThreshold: Double = 1

  /// Cuantos juegos se muestran en cada seccion destacada.
  static let sectionLimit = 10

  // MARK: - Resumen

  /// Numeros generales de la biblioteca.
  struct Summary: Equatable {
    var totalGames: Int = 0
    var totalHours: Double = 0
    var unplayedCount: Int = 0
    var barelyTriedCount: Int = 0
    var recentlyPlayedCount: Int = 0

    /// Que parte de la biblioteca nunca se toco, de 0 a 1.
    ///
    /// Con la biblioteca vacia devuelve 0 y no un valor invalido: nadie tiene
    /// "0% sin jugar" de cero juegos, pero es mejor que dividir por cero.
    var unplayedFraction: Double {
      guard totalGames > 0 else { return 0 }
      return Double(unplayedCount) / Double(totalGames)
    }

    /// Horas promedio por juego jugado.
    ///
    /// Se calcula sobre los que si se jugaron: incluir los de 0 h hundiria el
    /// promedio y no diria nada util.
    var averageHoursPerPlayedGame: Double {
      let jugados = totalGames - unplayedCount
      guard jugados > 0 else { return 0 }
      return totalHours / Double(jugados)
    }

    var isEmpty: Bool { totalGames == 0 }
  }

  /// Calcula el resumen.
  static func summary(for juegos: [Game]) -> Summary {
    var resumen = Summary()
    resumen.totalGames = juegos.count

    for juego in juegos {
      resumen.totalHours += juego.playtimeHours

      if juego.isUnplayed {
        resumen.unplayedCount += 1
      } else if juego.playtimeHours < barelyTriedThreshold {
        resumen.barelyTriedCount += 1
      }

      if juego.isRecentlyPlayed {
        resumen.recentlyPlayedCount += 1
      }
    }

    return resumen
  }

  // MARK: - Secciones automaticas

  /// Que clase de grupo automatico es.
  enum SectionKind: String, CaseIterable {
    case recentlyPlayed
    case mostPlayed
    case barelyTried
    case neverPlayed

    var title: String {
      switch self {
      case .recentlyPlayed: "Jugados hace poco"
      case .mostPlayed: "Los que mas juegas"
      case .barelyTried: "Apenas probados"
      case .neverPlayed: "Nunca jugados"
      }
    }

    var explanation: String {
      switch self {
      case .recentlyPlayed: "Con partidas en las ultimas dos semanas"
      case .mostPlayed: "Donde se te va la mayor parte del tiempo"
      case .barelyTried: "Menos de una hora: los abriste y ahi quedaron"
      case .neverPlayed: "Los tienes pero nunca los abriste"
      }
    }

    var symbolName: String {
      switch self {
      case .recentlyPlayed: "flame"
      case .mostPlayed: "trophy"
      case .barelyTried: "hourglass"
      case .neverPlayed: "shippingbox"
      }
    }
  }

  /// Un grupo de juegos que la app arma sola.
  struct Section: Identifiable, Equatable {
    let kind: SectionKind
    let games: [Game]

    /// Cuantos hay en total, aunque solo se muestren los primeros.
    let totalCount: Int

    var id: String { kind.rawValue }
    var isEmpty: Bool { games.isEmpty }

    /// Si hay mas de los que se estan mostrando.
    var hasMore: Bool { totalCount > games.count }
  }

  /// Arma todas las secciones, dejando fuera las que quedarian vacias.
  static func sections(for juegos: [Game], limit: Int = sectionLimit) -> [Section] {
    SectionKind.allCases
      .map { section(of: $0, for: juegos, limit: limit) }
      .filter { !$0.isEmpty }
  }

  /// Arma una seccion concreta.
  static func section(
    of kind: SectionKind,
    for juegos: [Game],
    limit: Int = sectionLimit
  ) -> Section {
    let coincidencias = games(of: kind, in: juegos)
    return Section(
      kind: kind,
      games: Array(coincidencias.prefix(limit)),
      totalCount: coincidencias.count
    )
  }

  /// Todos los juegos de una categoria, ya ordenados.
  static func games(of kind: SectionKind, in juegos: [Game]) -> [Game] {
    switch kind {
    case .recentlyPlayed:
      juegos
        .filter(\.isRecentlyPlayed)
        .sorted { $0.recentPlaytimeHours > $1.recentPlaytimeHours }

    case .mostPlayed:
      juegos
        .filter { !$0.isUnplayed }
        .sorted { $0.playtimeHours > $1.playtimeHours }

    case .barelyTried:
      juegos
        .filter { !$0.isUnplayed && $0.playtimeHours < barelyTriedThreshold }
        .sorted { $0.playtimeHours < $1.playtimeHours }

    case .neverPlayed:
      juegos
        .filter(\.isUnplayed)
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
  }

  // MARK: - Distribucion del tiempo

  /// Cuanto del tiempo total concentran unos pocos juegos.
  struct Concentration: Equatable {
    /// Cuantos juegos hacen falta para llegar a la mitad de las horas.
    var gamesForHalfTheTime: Int = 0

    /// Que parte del tiempo se lleva el juego con mas horas, de 0 a 1.
    var topGameShare: Double = 0

    /// Que parte del tiempo se llevan los cinco con mas horas, de 0 a 1.
    var topFiveShare: Double = 0
  }

  /// Calcula como se reparte el tiempo jugado.
  ///
  /// Sin horas registradas devuelve todo en cero, en vez de dividir por cero.
  static func concentration(for juegos: [Game]) -> Concentration {
    let horas = juegos.map(\.playtimeHours).filter { $0 > 0 }.sorted(by: >)
    let total = horas.reduce(0, +)

    guard total > 0 else { return Concentration() }

    var resultado = Concentration()
    resultado.topGameShare = (horas.first ?? 0) / total
    resultado.topFiveShare = horas.prefix(5).reduce(0, +) / total

    var acumulado: Double = 0
    for (indice, valor) in horas.enumerated() {
      acumulado += valor
      if acumulado >= total / 2 {
        resultado.gamesForHalfTheTime = indice + 1
        break
      }
    }

    return resultado
  }

  // MARK: - Sugerencia

  /// Juegos con 0 horas que **no** estan ya marcados como pendientes.
  ///
  /// Son los candidatos a marcar en lote. Se excluyen los que el usuario ya
  /// clasifico a mano: si marco como terminado un juego que jugo en consola,
  /// cambiarselo seria pisar su decision.
  static func candidatesForBacklog(in juegos: [Game]) -> [Game] {
    juegos
      .filter { $0.isUnplayed && $0.status != .backlog }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  // MARK: - Textos de la sugerencia
  //
  // Viven aca y no dentro de la vista por dos razones: el singular en espanol
  // cambia el articulo y el verbo, no solo la "s" final ("los 2 juegos ... no lo
  // estan" contra "el juego ... no lo esta"), asi que conviene poder probarlo; y
  // cuando se haga la traduccion (#67) todos los textos estan en un solo sitio.

  /// Titulo del boton que ofrece marcar los candidatos como pendientes.
  static func backlogSuggestionTitle(count: Int) -> String {
    count == 1
      ? "Marcar 1 juego como pendiente"
      : "Marcar \(count) juegos como pendientes"
  }

  /// Titulo del dialogo de confirmacion.
  static func backlogConfirmationTitle(count: Int) -> String {
    count == 1 ? "Marcar como pendiente" : "Marcar como pendientes"
  }

  /// Segunda linea del boton, con el criterio que se uso para elegirlos.
  static func backlogSuggestionSubtitle(count: Int) -> String {
    count == 1
      ? "Tiene 0 horas y todavia no esta marcado"
      : "Tienen 0 horas y todavia no estan marcados"
  }

  /// Texto del boton que confirma la accion dentro del dialogo.
  static func backlogConfirmationAction(count: Int) -> String {
    count == 1 ? "Marcar 1 juego" : "Marcar \(count) juegos"
  }

  /// Explicacion de lo que va a pasar, en el dialogo de confirmacion.
  static func backlogConfirmationMessage(count: Int) -> String {
    let queCambia = count == 1
      ? "Se marcara como pendiente el juego con 0 horas que todavia no lo esta."
      : "Se marcaran como pendientes los \(count) juegos con 0 horas que todavia no lo estan."
    return queCambia + " No se tocan los que ya clasificaste a mano."
  }

  /// Confirmacion de lo que se cambio, ya con la accion hecha.
  static func backlogResultMessage(count: Int) -> String {
    count == 1
      ? "Se marco 1 juego como pendiente."
      : "Se marcaron \(count) juegos como pendientes."
  }
}
