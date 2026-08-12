//
//  WishlistPriceLabel.swift
//  GameShelf
//

import SwiftUI

/// El precio de un juego dentro de una fila de la lista de deseos.
///
/// Muestra tres cosas y en este orden de importancia: lo que cuesta ahora, si
/// esta en su minimo historico, y donde. El precio normal tachado solo aparece
/// cuando hay descuento, para no repetir el mismo numero dos veces.
struct WishlistPriceLabel: View {
  let prices: GamePrices

  var body: some View {
    if let mejor = prices.best {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(mejor.price.formatted())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(prices.isAtHistoricalLow ? Color.green : Color.primary)

          if mejor.discountPercent > 0 {
            Text(mejor.regular.formatted())
              .font(.caption)
              .foregroundStyle(.secondary)
              .strikethrough()

            DescuentoBadge(porcentaje: mejor.discountPercent)
          }
        }

        HStack(spacing: 6) {
          if prices.isAtHistoricalLow {
            // Es la senal que de verdad importa: un 50% no dice nada si el
            // juego ya estuvo al 75%.
            Label("Minimo historico", systemImage: "arrow.down.to.line")
              .font(.caption2.weight(.medium))
              .foregroundStyle(.green)
          }

          Text(mejor.shopName)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(etiquetaAccesible(mejor))
    }
  }

  private func etiquetaAccesible(_ mejor: GameDeal) -> String {
    var partes = [mejor.price.formatted()]

    if mejor.discountPercent > 0 {
      partes.append(
        String(
          localized: "\(mejor.discountPercent) % de descuento",
          comment: "Descuento, para VoiceOver"
        )
      )
    }
    if prices.isAtHistoricalLow {
      partes.append(String(localized: "Minimo historico", comment: "El precio mas bajo de siempre"))
    }
    partes.append(String(localized: "en \(mejor.shopName)", comment: "En que tienda esta la oferta"))

    return partes.joined(separator: ", ")
  }
}

/// La etiqueta de "-50%".
struct DescuentoBadge: View {
  let porcentaje: Int

  var body: some View {
    Text(verbatim: "-\(porcentaje)%")
      .font(.caption2.weight(.bold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.green.opacity(0.18), in: Capsule())
      .foregroundStyle(.green)
      // El numero ya se lee en la etiqueta de la fila completa.
      .accessibilityHidden(true)
  }
}
