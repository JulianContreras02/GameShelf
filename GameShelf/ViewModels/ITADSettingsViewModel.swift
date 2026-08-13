//
//  ITADSettingsViewModel.swift
//  GameShelf
//

import Foundation

/// La clave de IsThereAnyDeal: guardarla, borrarla y saber si ya esta.
///
/// A diferencia de las cuentas de tienda, ITAD no tiene un "conectado" o
/// "desconectado" de verdad: es solo una clave de API sin dueño ni sesion. No
/// se verifica contra la red al guardarla porque no hay un endpoint liviano
/// para eso, y una clave invalida ya la maneja la wishlist mostrando la lista
/// sin precios.
@Observable
@MainActor
final class ITADSettingsViewModel {

  private(set) var hasAPIKey: Bool

  private let keychain: KeychainStoring

  init(keychain: KeychainStoring = KeychainStore()) {
    self.keychain = keychain
    self.hasAPIKey = ITADService.hasAPIKey(in: keychain)
  }

  func save(apiKey: String) {
    let limpia = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !limpia.isEmpty else { return }

    try? ITADService.save(apiKey: limpia, to: keychain)
    hasAPIKey = ITADService.hasAPIKey(in: keychain)
  }

  func remove() {
    try? ITADService.removeAPIKey(from: keychain)
    hasAPIKey = ITADService.hasAPIKey(in: keychain)
  }
}
