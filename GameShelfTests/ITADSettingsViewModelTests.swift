//
//  ITADSettingsViewModelTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

@MainActor
@Suite("ITAD: guardar la clave desde Ajustes")
struct ITADSettingsViewModelTests {

  @Test("Guardar deja hasAPIKey en true y la clave en el llavero")
  func guarda() throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = ITADSettingsViewModel(keychain: llavero)

    viewModel.save(apiKey: "MI_CLAVE")

    #expect(viewModel.hasAPIKey)
    #expect(try llavero.string(for: "itad.apiKey") == "MI_CLAVE")
  }

  @Test("Quita espacios de los bordes antes de guardar")
  func quitaEspacios() throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = ITADSettingsViewModel(keychain: llavero)

    viewModel.save(apiKey: "  MI_CLAVE  ")

    #expect(try llavero.string(for: "itad.apiKey") == "MI_CLAVE")
  }

  @Test("Una clave vacia no se guarda")
  func claveVacia() throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = ITADSettingsViewModel(keychain: llavero)

    viewModel.save(apiKey: "   ")

    #expect(!viewModel.hasAPIKey)
    #expect(try llavero.string(for: "itad.apiKey") == nil)
  }

  @Test("Borrar la quita del llavero")
  func borra() throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = ITADSettingsViewModel(keychain: llavero)
    viewModel.save(apiKey: "MI_CLAVE")

    viewModel.remove()

    #expect(!viewModel.hasAPIKey)
    #expect(try llavero.string(for: "itad.apiKey") == nil)
  }

  @Test("Al arrancar recuerda si ya habia una clave guardada")
  func recuerdaLoGuardado() {
    let llavero = InMemoryKeychainStore(valoresIniciales: ["itad.apiKey": "CLAVE"])

    let viewModel = ITADSettingsViewModel(keychain: llavero)

    #expect(viewModel.hasAPIKey)
  }

  @Test("Sin nada guardado arranca sin clave")
  func arranqueLimpio() {
    let viewModel = ITADSettingsViewModel(keychain: InMemoryKeychainStore())

    #expect(!viewModel.hasAPIKey)
  }
}
