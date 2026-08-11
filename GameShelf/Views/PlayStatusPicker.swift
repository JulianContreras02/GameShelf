//
//  PlayStatusPicker.swift
//  GameShelf
//

import SwiftUI

/// Color de cada estado.
///
/// Vive aparte del modelo para que `PlayStatus` no dependa de SwiftUI.
extension PlayStatus {
  var tint: Color {
    switch self {
    case .backlog: .gray
    case .playing: .green
    case .finished: .blue
    case .abandoned: .orange
    case .wishlist: .pink
    }
  }
}

/// Etiqueta con el icono y el nombre de un estado.
struct PlayStatusLabel: View {
  let status: PlayStatus
  var compact = false

  var body: some View {
    Label {
      Text(status.displayName)
    } icon: {
      Image(systemName: status.symbolName)
        .foregroundStyle(status.tint)
    }
    .font(compact ? .caption.weight(.medium) : .body)
  }
}

/// Etiqueta redondeada, para mostrar el estado dentro de una fila.
struct PlayStatusBadge: View {
  let status: PlayStatus

  var body: some View {
    Label(status.displayName, systemImage: status.symbolName)
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(status.tint.opacity(0.18), in: Capsule())
      .foregroundStyle(status.tint)
      .accessibilityLabel("Estado: \(status.displayName)")
  }
}

/// Menu para elegir el estado de un juego.
///
/// Se usa como `contextMenu` en las listas y como menu en la ficha, para que
/// cambiar el estado se sienta igual en los dos sitios.
struct PlayStatusMenu: View {
  let actual: PlayStatus
  let alElegir: (PlayStatus) -> Void

  var body: some View {
    ForEach(PlayStatus.displayOrder, id: \.self) { estado in
      Button {
        alElegir(estado)
      } label: {
        if estado == actual {
          Label("\(estado.displayName) ✓", systemImage: estado.symbolName)
        } else {
          Label(estado.displayName, systemImage: estado.symbolName)
        }
      }
    }
  }
}

#Preview("Etiquetas") {
  VStack(alignment: .leading, spacing: 16) {
    ForEach(PlayStatus.displayOrder, id: \.self) { estado in
      HStack(spacing: 16) {
        PlayStatusBadge(status: estado)
        Text(estado.explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
  .padding()
}
