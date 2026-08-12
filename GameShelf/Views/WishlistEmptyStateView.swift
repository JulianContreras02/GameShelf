//
//  WishlistEmptyStateView.swift
//  GameShelf
//

import SwiftUI

/// Que mostrar cuando la lista de deseos esta vacia.
///
/// Son cuatro situaciones distintas y el usuario tiene que poder distinguirlas,
/// sobre todo la de la lista privada: es la unica que se arregla en Steam y no
/// en la app.
struct WishlistEmptyStateView: View {
  let state: WishlistViewModel.State
  let devolvioListaVacia: Bool
  let alSincronizar: () -> Void
  let alAgregarAMano: () -> Void

  var body: some View {
    switch state {
    case .syncing:
      ContentUnavailableView {
        Label("Trayendo tu lista de deseos…", systemImage: "hourglass")
      }

    case .failed(let mensaje, let sugerencia):
      ContentUnavailableView {
        Label("No se pudo sincronizar", systemImage: "exclamationmark.triangle")
      } description: {
        VStack(spacing: 8) {
          Text(mensaje)
          if let sugerencia {
            Text(sugerencia).font(.footnote)
          }
        }
      } actions: {
        botones(principal: "Reintentar")
      }

    case .succeeded where devolvioListaVacia:
      // Steam responde `{"response":{}}` tanto si la lista esta vacia como si
      // es privada: no hay forma de saber cual de las dos. Se explican las dos
      // en vez de adivinar y arriesgarse a mandar al usuario a cambiar una
      // configuracion que ya estaba bien.
      ContentUnavailableView {
        Label("Steam no devolvio nada", systemImage: "lock")
      } description: {
        Text(
          """
          Puede ser que tu lista de deseos este vacia, o que sea privada: Steam \
          responde igual en los dos casos.

          Si crees que deberia traer algo, en Steam revisa Perfil > Editar \
          perfil > Privacidad y deja "Lista de deseos" en publico.
          """
        )
      } actions: {
        botones(principal: "Reintentar")
      }

    case .idle, .succeeded:
      ContentUnavailableView {
        Label("Sin nada en la lista", systemImage: "heart")
      } description: {
        Text("Trae tu lista de deseos de Steam, o agrega juegos a mano.")
      } actions: {
        botones(principal: "Sincronizar con Steam")
      }
    }
  }

  @ViewBuilder
  private func botones(principal: LocalizedStringKey) -> some View {
    VStack(spacing: 12) {
      Button(principal, action: alSincronizar)
        .buttonStyle(.borderedProminent)
        .disabled(state.isSyncing)

      Button("Agregar a mano", action: alAgregarAMano)
    }
  }
}
