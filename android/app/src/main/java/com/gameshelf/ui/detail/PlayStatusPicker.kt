package com.gameshelf.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.size
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.gameshelf.R
import com.gameshelf.domain.PlayStatus
import com.gameshelf.ui.common.vector

/**
 * Selector del estado de un juego.
 *
 * Debajo del selector se explica que significa el estado elegido. No es
 * decoracion: "Abandonado" y "Pendiente" se confunden facil, y la frase evita
 * que el usuario tenga que adivinar la diferencia.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PlayStatusPicker(
  actual: PlayStatus,
  alElegir: (PlayStatus) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(stringResource(R.string.detail_status), style = MaterialTheme.typography.titleMedium)

    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      PlayStatus.displayOrder.forEach { estado ->
        FilterChip(
          selected = estado == actual,
          onClick = { alElegir(estado) },
          label = { Text(stringResource(estado.displayNameRes)) },
          leadingIcon = {
            Icon(
              estado.iconName.vector,
              contentDescription = null,
              modifier = Modifier.size(18.dp),
            )
          },
        )
      }
    }

    Text(
      stringResource(actual.explanationRes),
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}
