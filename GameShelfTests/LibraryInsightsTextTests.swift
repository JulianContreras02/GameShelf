//
//  LibraryInsightsTextTests.swift
//  GameShelfTests
//

import Testing

@testable import GameShelf

@Suite("Textos de la sugerencia")
struct BacklogSuggestionTextTests {

  // En espanol el singular no es solo quitar la "s": cambia el articulo ("los"
  // -> "el") y el verbo ("estan" -> "esta"). Estas pruebas existen porque la
  // primera version decia "Marcar 1 juegos" y "los 1 juegos".

  @Test("Con un solo candidato todo va en singular")
  func singular() {
    #expect(LibraryInsights.backlogSuggestionTitle(count: 1) == "Marcar 1 juego como pendiente")
    #expect(LibraryInsights.backlogConfirmationAction(count: 1) == "Marcar 1 juego")
    #expect(LibraryInsights.backlogConfirmationTitle(count: 1) == "Marcar como pendiente")
    #expect(LibraryInsights.backlogResultMessage(count: 1) == "Se marco 1 juego como pendiente.")
    #expect(LibraryInsights.backlogSuggestionSubtitle(count: 1) == "Tiene 0 horas y todavia no esta marcado")

    let mensaje = LibraryInsights.backlogConfirmationMessage(count: 1)
    #expect(mensaje.contains("Se marcara como pendiente el juego"))
    #expect(!mensaje.contains("los 1"))
    #expect(!mensaje.contains("1 juegos"))
  }

  @Test("Con varios candidatos todo va en plural")
  func plural() {
    #expect(LibraryInsights.backlogSuggestionTitle(count: 29) == "Marcar 29 juegos como pendientes")
    #expect(LibraryInsights.backlogConfirmationAction(count: 29) == "Marcar 29 juegos")
    #expect(LibraryInsights.backlogConfirmationTitle(count: 29) == "Marcar como pendientes")
    #expect(LibraryInsights.backlogResultMessage(count: 29) == "Se marcaron 29 juegos como pendientes.")
    #expect(LibraryInsights.backlogConfirmationMessage(count: 29).contains("los 29 juegos"))
    #expect(LibraryInsights.backlogSuggestionSubtitle(count: 29) == "Tienen 0 horas y todavia no estan marcados")
  }

  @Test("Todos los textos avisan que no se pisa lo que el usuario clasifico")
  func aclaraQueNoPisaNada() {
    for cantidad in [1, 2, 29] {
      let mensaje = LibraryInsights.backlogConfirmationMessage(count: cantidad)
      #expect(mensaje.contains("No se tocan los que ya clasificaste a mano."))
    }
  }
}
