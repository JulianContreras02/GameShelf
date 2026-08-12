//
//  LocalizationTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Bundles de cada idioma, para leer las traducciones sin cambiarle el idioma
/// al simulador.
///
/// Hace falta el bundle y no basta con un `Locale`: el parametro `locale:` de
/// `String(localized:)` decide como se formatean numeros y fechas, pero **no**
/// que idioma se usa. Eso lo decide el bundle. Con `locale:` a secas, pedir
/// ingles devolvia espanol y una prueba de traduccion no probaba nada.
enum IdiomaDePrueba {
  static let espanol = bundle("es")
  static let ingles = bundle("en")

  private static func bundle(_ codigo: String) -> Bundle {
    guard let ruta = Bundle.main.path(forResource: codigo, ofType: "lproj"),
          let bundle = Bundle(path: ruta)
    else {
      // Si esto pasa, el idioma no se esta compilando en la app y todas las
      // pruebas de abajo estarian comparando espanol contra espanol.
      fatalError("Falta el idioma '\(codigo)' en la app")
    }
    return bundle
  }
}

@Suite("Localizacion: la app trae los dos idiomas")
struct LocalizationBundleTests {

  @Test("Espanol e ingles se compilan dentro de la app")
  func idiomasDisponibles() {
    let idiomas = Bundle.main.localizations
    #expect(idiomas.contains("es"))
    #expect(idiomas.contains("en"))
  }

  @Test("El idioma base es espanol")
  func baseEsEspanol() {
    #expect(Bundle.main.developmentLocalization == "es")
  }

  @Test("Los dos bundles devuelven textos distintos")
  func noEsElMismoBundle() {
    #expect(String(localized: "Pendiente", bundle: IdiomaDePrueba.espanol) == "Pendiente")
    #expect(String(localized: "Pendiente", bundle: IdiomaDePrueba.ingles) == "Backlog")
  }
}

@Suite("Localizacion: estados y colores")
struct LocalizationEnumTests {

  // Se usan las claves en espanol tal cual y no `estado.displayName`: esa
  // propiedad ya viene traducida al idioma del simulador, asi que buscarla como
  // clave fallaria si el simulador estuviera en ingles.

  @Test("Los cinco estados estan traducidos")
  func estados() {
    let esperado = [
      "Pendiente": "Backlog",
      "Jugando": "Playing",
      "Terminado": "Finished",
      "Abandonado": "Abandoned",
      "Lista de deseos": "Wishlist"
    ]

    #expect(esperado.count == PlayStatus.allCases.count, "Falta cubrir un estado nuevo")

    for (espanol, ingles) in esperado {
      #expect(String(localized: String.LocalizationValue(espanol), bundle: IdiomaDePrueba.ingles) == ingles)
    }
  }

  @Test("Los nueve colores estan traducidos")
  func colores() {
    let esperado = [
      "Azul": "Blue",
      "Verde": "Green",
      "Naranja": "Orange",
      "Rosa": "Pink",
      "Morado": "Purple",
      "Rojo": "Red",
      "Turquesa": "Teal",
      "Amarillo": "Yellow",
      "Gris": "Gray"
    ]

    #expect(esperado.count == CollectionColor.allCases.count, "Falta cubrir un color nuevo")

    for (espanol, ingles) in esperado {
      #expect(String(localized: String.LocalizationValue(espanol), bundle: IdiomaDePrueba.ingles) == ingles)
    }
  }
}

@Suite("Localizacion: plurales del catalogo")
struct LocalizationPluralTests {

  // Estas pruebas son el motivo de que los textos con numero pasen por el
  // catalogo: las reglas de plural las pone cada idioma, no un `if` en Swift.

  @Test("La sugerencia de pendientes pluraliza en espanol")
  func sugerenciaEnEspanol() {
    let bundle = IdiomaDePrueba.espanol
    #expect(
      LibraryInsights.backlogSuggestionTitle(count: 1, bundle: bundle)
        == "Marcar 1 juego como pendiente"
    )
    #expect(
      LibraryInsights.backlogSuggestionTitle(count: 29, bundle: bundle)
        == "Marcar 29 juegos como pendientes"
    )
    #expect(LibraryInsights.backlogConfirmationAction(count: 1, bundle: bundle) == "Marcar 1 juego")
    #expect(LibraryInsights.backlogConfirmationAction(count: 29, bundle: bundle) == "Marcar 29 juegos")
    #expect(
      LibraryInsights.backlogResultMessage(count: 1, bundle: bundle)
        == "Se marco 1 juego como pendiente."
    )
    #expect(
      LibraryInsights.backlogResultMessage(count: 29, bundle: bundle)
        == "Se marcaron 29 juegos como pendientes."
    )
  }

  @Test("La sugerencia de pendientes pluraliza en ingles")
  func sugerenciaEnIngles() {
    let bundle = IdiomaDePrueba.ingles
    #expect(
      LibraryInsights.backlogSuggestionTitle(count: 1, bundle: bundle)
        == "Mark 1 game as backlog"
    )
    #expect(
      LibraryInsights.backlogSuggestionTitle(count: 29, bundle: bundle)
        == "Mark 29 games as backlog"
    )
    #expect(LibraryInsights.backlogConfirmationAction(count: 1, bundle: bundle) == "Mark 1 game")
    #expect(
      LibraryInsights.backlogResultMessage(count: 1, bundle: bundle)
        == "1 game marked as backlog."
    )
    #expect(
      LibraryInsights.backlogResultMessage(count: 29, bundle: bundle)
        == "29 games marked as backlog."
    )
  }

  @Test("El aviso de confirmacion pluraliza y conserva la aclaracion")
  func avisoDeConfirmacion() {
    let uno = LibraryInsights.backlogConfirmationMessage(count: 1, bundle: IdiomaDePrueba.espanol)
    let varios = LibraryInsights.backlogConfirmationMessage(count: 29, bundle: IdiomaDePrueba.espanol)

    #expect(uno.hasPrefix("Se marcara 1 juego como pendiente."))
    #expect(varios.hasPrefix("Se marcaran 29 juegos como pendientes."))
    for mensaje in [uno, varios] {
      #expect(mensaje.hasSuffix("No se tocan los que ya clasificaste a mano."))
    }

    let enIngles = LibraryInsights.backlogConfirmationMessage(count: 1, bundle: IdiomaDePrueba.ingles)
    #expect(enIngles.hasPrefix("1 game will be marked as backlog."))
  }

  @Test("El criterio de la sugerencia no depende de la cantidad")
  func subtituloSinNumero() {
    #expect(
      LibraryInsights.backlogSuggestionSubtitle(bundle: IdiomaDePrueba.espanol)
        == "Solo los que tienen 0 horas y ningun estado puesto por ti"
    )
    #expect(
      LibraryInsights.backlogSuggestionSubtitle(bundle: IdiomaDePrueba.ingles)
        == "Only the ones with 0 hours and no status set by you"
    )
  }

  @Test("El tiempo para VoiceOver concuerda en singular")
  func tiempoAccesible() {
    let espanol = IdiomaDePrueba.espanol
    // Antes de pasar por el catalogo esto decia "1 hora jugadas": el switch a
    // mano cambiaba el sustantivo pero no el participio.
    #expect(PlaytimeFormatter.accessible(hours: 1, bundle: espanol) == "1 hora jugada")
    #expect(PlaytimeFormatter.accessible(hours: 2, bundle: espanol) == "2 horas jugadas")
    #expect(PlaytimeFormatter.accessible(hours: 1.0 / 60, bundle: espanol) == "1 minuto jugado")
    #expect(PlaytimeFormatter.accessible(hours: 0.5, bundle: espanol) == "30 minutos jugados")

    let ingles = IdiomaDePrueba.ingles
    #expect(PlaytimeFormatter.accessible(hours: 1, bundle: ingles) == "1 hour played")
    #expect(PlaytimeFormatter.accessible(hours: 2, bundle: ingles) == "2 hours played")
    #expect(PlaytimeFormatter.accessible(hours: 0.5, bundle: ingles) == "30 minutes played")
  }

  @Test("La ultima partida se dice en los dos idiomas")
  func ultimaPartida() throws {
    let hoy = Date()
    let calendario = Calendar(identifier: .gregorian)
    let hace3 = try #require(calendario.date(byAdding: .day, value: -3, to: hoy))

    #expect(LastPlayedFormatter.text(for: nil, bundle: IdiomaDePrueba.espanol) == "Nunca")
    #expect(LastPlayedFormatter.text(for: nil, bundle: IdiomaDePrueba.ingles) == "Never")
    #expect(
      LastPlayedFormatter.text(for: hace3, relativeTo: hoy, bundle: IdiomaDePrueba.espanol)
        == "Hace 3 dias"
    )
    #expect(
      LastPlayedFormatter.text(for: hace3, relativeTo: hoy, bundle: IdiomaDePrueba.ingles)
        == "3 days ago"
    )
  }

  @Test("Sin jugar se traduce")
  func sinJugar() {
    #expect(PlaytimeFormatter.short(hours: 0, bundle: IdiomaDePrueba.espanol) == "Sin jugar")
    #expect(PlaytimeFormatter.short(hours: 0, bundle: IdiomaDePrueba.ingles) == "Not played")
  }
}

@Suite("Localizacion: errores")
struct LocalizationErrorTests {

  @Test("Todos los errores de red tienen mensaje en ingles")
  func erroresDeRed() {
    let casos: [NetworkError] = [
      .noConnection,
      .invalidResponse,
      .httpError(statusCode: 500),
      .decodingFailed(description: "x"),
      .invalidURL("x")
    ]

    for caso in casos {
      let descripcion = caso.errorDescription ?? ""
      #expect(!descripcion.isEmpty, "Falta mensaje en \(caso)")
    }

    #expect(
      String(localized: "No hay conexion a internet.", bundle: IdiomaDePrueba.ingles)
        == "There is no internet connection."
    )
    #expect(
      String(localized: "Revisa que tu API key sea correcta y siga vigente.", bundle: IdiomaDePrueba.ingles)
        == "Check that your API key is correct and still valid."
    )
  }

  @Test("El error de secretos que faltan esta traducido")
  func secretosQueFaltan() {
    #expect(
      String(localized: "Falta configurar las claves.", bundle: IdiomaDePrueba.ingles)
        == "The keys are not set up yet."
    )
  }
}
