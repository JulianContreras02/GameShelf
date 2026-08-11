//
//  LibraryView+Previews.swift
//  GameShelf
//
//  Las vistas previas viven aparte para que LibraryView no crezca de mas:
//  SwiftLint avisa por encima de 400 lineas y el aviso era correcto.
//

import SwiftData
import SwiftUI

// MARK: - Vistas previas

/// Contenedor en memoria con juegos de ejemplo, solo para las vistas previas.
@MainActor
private func contenedorDeEjemplo() -> ModelContainer? {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  guard let contenedor = try? ModelContainer(
    for: Game.self, StoreEntry.self, configurations: config
  ) else {
    return nil
  }

  struct Ejemplo {
    let nombre: String
    let horas: Double
    let appID: String
  }

  let ejemplos = [
    Ejemplo(nombre: "Red Dead Redemption 2", horas: 227.9, appID: "1174180"),
    Ejemplo(nombre: "Hollow Knight", horas: 1.5, appID: "367520"),
    Ejemplo(nombre: "Un juego sin jugar", horas: 0, appID: "413150")
  ]

  for ejemplo in ejemplos {
    let juego = Game(
      name: ejemplo.nombre,
      coverImageURL:
        "https://cdn.cloudflare.steamstatic.com/steam/apps/\(ejemplo.appID)/header.jpg",
      playtimeHours: ejemplo.horas
    )
    juego.storeEntries = [StoreEntry(store: .steam, storeGameID: ejemplo.appID)]
    contenedor.mainContext.insert(juego)
  }

  return contenedor
}

/// Servicio inerte para las vistas previas: no sale a la red.
private struct PreviewSteamService: SteamServicing {
  var error: Error?

  func fetchOwnedGames() async throws -> [SteamGameDTO] {
    if let error { throw error }
    return []
  }
}

/// UserDefaults aislado para que las vistas previas no toquen los del sistema.
@MainActor
private func defaultsDePrueba() -> UserDefaults {
  UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard
}

#Preview("Con juegos") {
  if let contenedor = contenedorDeEjemplo() {
    LibraryView(
      viewModel: LibraryViewModel(
        service: PreviewSteamService(),
        defaults: defaultsDePrueba()
      )
    )
    .modelContainer(contenedor)
  } else {
    Text("No se pudo crear el contenedor de ejemplo")
  }
}

#Preview("Vacia") {
  LibraryView(
    viewModel: LibraryViewModel(
      service: PreviewSteamService(),
      defaults: defaultsDePrueba()
    )
  )
  .modelContainer(for: [Game.self, StoreEntry.self], inMemory: true)
}

#Preview("Error de red") {
  LibraryView(
    viewModel: LibraryViewModel(
      service: PreviewSteamService(error: NetworkError.noConnection),
      defaults: defaultsDePrueba()
    )
  )
  .modelContainer(for: [Game.self, StoreEntry.self], inMemory: true)
}
