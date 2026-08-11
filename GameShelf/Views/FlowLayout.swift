//
//  FlowLayout.swift
//  GameShelf
//

import SwiftUI

/// Acomoda las vistas en fila y salta de linea cuando no caben.
///
/// SwiftUI no trae nada asi: `HStack` desborda y `LazyVGrid` obliga a columnas
/// de ancho fijo, que se ve mal con etiquetas de distinto largo.
///
/// Importa para accesibilidad: con Dynamic Type grande las etiquetas crecen, y
/// asi se reacomodan en vez de recortarse.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let anchoMaximo = proposal.width ?? .infinity
    let filas = acomodar(subviews: subviews, anchoMaximo: anchoMaximo)

    let alto = filas.reduce(0) { total, fila in
      total + fila.alto + (fila.esUltima ? 0 : spacing)
    }
    let ancho = filas.map(\.ancho).max() ?? 0

    return CGSize(width: min(ancho, anchoMaximo), height: alto)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    let filas = acomodar(subviews: subviews, anchoMaximo: bounds.width)
    var posicionY = bounds.minY

    for fila in filas {
      var posicionX = bounds.minX
      for indice in fila.indices {
        let medida = subviews[indice].sizeThatFits(.unspecified)
        subviews[indice].place(
          at: CGPoint(x: posicionX, y: posicionY),
          proposal: ProposedViewSize(medida)
        )
        posicionX += medida.width + spacing
      }
      posicionY += fila.alto + spacing
    }
  }

  // MARK: - Apoyo

  private struct Fila {
    var indices: [Int] = []
    var ancho: CGFloat = 0
    var alto: CGFloat = 0
    var esUltima = false
  }

  private func acomodar(subviews: Subviews, anchoMaximo: CGFloat) -> [Fila] {
    var filas: [Fila] = []
    var actual = Fila()

    for indice in subviews.indices {
      let medida = subviews[indice].sizeThatFits(.unspecified)
      let anchoConEsta = actual.indices.isEmpty
        ? medida.width
        : actual.ancho + spacing + medida.width

      if anchoConEsta > anchoMaximo, !actual.indices.isEmpty {
        filas.append(actual)
        actual = Fila()
        actual.indices = [indice]
        actual.ancho = medida.width
        actual.alto = medida.height
      } else {
        actual.indices.append(indice)
        actual.ancho = anchoConEsta
        actual.alto = max(actual.alto, medida.height)
      }
    }

    if !actual.indices.isEmpty {
      filas.append(actual)
    }
    if !filas.isEmpty {
      filas[filas.count - 1].esUltima = true
    }

    return filas
  }
}
