//
//  LibraryEmptyStateView.swift
//  GameShelf
//

import SwiftUI

/// Que se muestra cuando la biblioteca no tiene ningun juego.
///
/// Es una vista propia y no una parte de `LibraryView` por dos razones: esa
/// pantalla ya pasaba del limite de tamaño que marca SwiftLint, y asi las
/// dependencias quedan explicitas (recibe el estado y que hacer al reintentar)
/// en vez de leer propiedades privadas de otra vista.
struct LibraryEmptyStateView: View {
  let state: LibraryViewModel.State

  /// Si la ultima sincronizacion correcta no trajo ningun juego.
  let syncReturnedNoGames: Bool

  let onSync: () -> Void

  var body: some View {
    switch state {
    case .syncing:
      ProgressView("Trayendo tu biblioteca…")
        .controlSize(.large)

    case .failed(let mensaje, let sugerencia):
      ContentUnavailableView {
        Label("No se pudo sincronizar", systemImage: "exclamationmark.triangle")
      } description: {
        Text([mensaje, sugerencia].compactMap { $0 }.joined(separator: "\n\n"))
      } actions: {
        botonPrincipal("Reintentar")
      }

    case .succeeded where syncReturnedNoGames:
      // Sincronizo bien pero Steam no devolvio nada. La causa mas comun es un
      // perfil privado, y la API no permite distinguirlo de una biblioteca
      // realmente vacia.
      ContentUnavailableView {
        Label("Steam no devolvio juegos", systemImage: "lock")
      } description: {
        Text(
          """
          La sincronizacion funciono, pero tu biblioteca llego vacia.

          Suele pasar cuando el perfil de Steam es privado. En Steam, revisa \
          Perfil > Editar perfil > Privacidad y deja "Detalles del juego" en \
          publico.
          """
        )
      } actions: {
        botonPrincipal("Volver a intentar")
      }

    case .idle, .succeeded:
      ContentUnavailableView {
        Label("Sin juegos todavia", systemImage: "gamecontroller")
      } description: {
        Text("Trae tu biblioteca de Steam para empezar.")
      } actions: {
        botonPrincipal("Sincronizar con Steam")
      }
    }
  }

  private func botonPrincipal(_ titulo: LocalizedStringKey) -> some View {
    Button(titulo, action: onSync)
      .buttonStyle(.borderedProminent)
  }
}

#Preview("Sin juegos") {
  LibraryEmptyStateView(state: .idle, syncReturnedNoGames: false) {}
}

#Preview("Error") {
  LibraryEmptyStateView(
    state: .failed(
      message: "No hay conexion a internet.",
      suggestion: "Revisa tu conexion y vuelve a intentar."
    ),
    syncReturnedNoGames: false
  ) {}
}

#Preview("Perfil privado") {
  LibraryEmptyStateView(
    state: .succeeded(created: 0, updated: 0),
    syncReturnedNoGames: true
  ) {}
}
