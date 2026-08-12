package com.gameshelf.ui.wishlist

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.gameshelf.R
import com.gameshelf.data.itad.GamePrices
import com.gameshelf.ui.common.Chip

/**
 * El precio de un juego de la lista de deseos.
 *
 * Lo importante que ensena no es el descuento sino si esta en su **minimo
 * historico**: un 50% no dice nada si el juego ya estuvo al 75%. Por eso esa
 * marca va destacada y el porcentaje va discreto.
 */
@Composable
fun WishlistPriceLabel(precios: GamePrices, modifier: Modifier = Modifier) {
  val oferta = precios.best ?: run {
    Text(
      stringResource(R.string.wishlist_no_price),
      style = MaterialTheme.typography.labelMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      modifier = modifier,
    )
    return
  }

  val actual = oferta.price.formatted()
  val minimo = precios.historicalLow?.formatted()

  // La fila entera se anuncia junta: leer "19,99 15,99 -20%" suelto no se
  // entiende.
  val descripcion = buildString {
    append(stringResource(R.string.wishlist_price_now, actual))
    if (oferta.discountPercent > 0) {
      append(", ")
      append(stringResource(R.string.wishlist_price_discount, oferta.discountPercent))
    }
    if (precios.isAtHistoricalLow) {
      append(", ")
      append(stringResource(R.string.wishlist_historical_low))
    }
  }

  Row(
    modifier = modifier.semantics(mergeDescendants = true) { contentDescription = descripcion },
    horizontalArrangement = Arrangement.spacedBy(8.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Text(actual, style = MaterialTheme.typography.titleSmall)

    if (oferta.discountPercent > 0) {
      Text(
        oferta.regular.formatted(),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textDecoration = TextDecoration.LineThrough,
      )
      Chip(texto = "-${oferta.discountPercent}%")
    }

    if (precios.isAtHistoricalLow) {
      Chip(
        texto = stringResource(R.string.wishlist_historical_low),
        color = MaterialTheme.colorScheme.primaryContainer,
        contenido = MaterialTheme.colorScheme.onPrimaryContainer,
      )
    } else if (minimo != null) {
      Text(
        stringResource(R.string.wishlist_lowest_was, minimo),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }

    Text(
      oferta.shopName,
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}
