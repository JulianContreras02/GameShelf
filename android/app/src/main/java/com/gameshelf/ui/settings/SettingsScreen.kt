package com.gameshelf.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.data.secrets.AppSecrets
import com.gameshelf.ui.accounts.EpicAccountViewModel
import com.gameshelf.ui.accounts.PSNAccountViewModel

/**
 * Ajustes: las cuentas conectadas y el estado de la configuracion.
 *
 * Lo primero que ensena, si aplica, es que claves faltan. Es la contraparte de
 * la promesa del README: **si falta una clave el proyecto compila igual** y la
 * app lo dice, en vez de fallar a mitad de una pantalla sin explicar por que.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
  alConectarPSN: () -> Unit,
  alConectarEpic: () -> Unit,
  alAbrirDeseos: () -> Unit,
) {
  val container = LocalAppContainer.current
  val psn: PSNAccountViewModel = viewModel(factory = container.viewModelFactory)
  val epic: EpicAccountViewModel = viewModel(factory = container.viewModelFactory)

  val estadoPSN by psn.state.collectAsStateWithLifecycle()
  val estadoEpic by epic.state.collectAsStateWithLifecycle()
  val nombreEpic by epic.displayName.collectAsStateWithLifecycle()

  val faltantes = remember { AppSecrets.missingKeys() }

  Scaffold(
    topBar = { TopAppBar(title = { Text(stringResource(R.string.tab_settings)) }) },
  ) { relleno ->
    Column(
      Modifier
        .padding(relleno)
        .fillMaxSize()
        .verticalScroll(rememberScrollState())
        .padding(16.dp),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      if (faltantes.isNotEmpty()) {
        Card {
          Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
              stringResource(R.string.settings_missing_keys),
              style = MaterialTheme.typography.titleMedium,
            )
            faltantes.forEach { clave ->
              Text("· ${clave.configName}", style = MaterialTheme.typography.bodyMedium)
            }
            Text(
              stringResource(R.string.settings_missing_keys_detail),
              style = MaterialTheme.typography.bodySmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }
        }
      }

      Text(stringResource(R.string.settings_accounts), style = MaterialTheme.typography.titleMedium)

      Card {
        Column {
          FilaDeCuenta(
            titulo = stringResource(R.string.settings_playstation),
            detalle = if (estadoPSN.isConnected) {
              stringResource(R.string.settings_connected)
            } else {
              stringResource(R.string.settings_not_connected)
            },
            conectado = estadoPSN.isConnected,
            onClick = alConectarPSN,
          )

          HorizontalDivider()

          FilaDeCuenta(
            titulo = stringResource(R.string.settings_epic),
            detalle = when {
              estadoEpic.isConnected && nombreEpic != null -> nombreEpic!!
              estadoEpic.isConnected -> stringResource(R.string.settings_connected)
              else -> stringResource(R.string.settings_not_connected)
            },
            conectado = estadoEpic.isConnected,
            onClick = alConectarEpic,
          )
        }
      }

      Text(stringResource(R.string.settings_sections), style = MaterialTheme.typography.titleMedium)

      Card {
        FilaDeCuenta(
          titulo = stringResource(R.string.tab_wishlist),
          detalle = stringResource(R.string.settings_wishlist_detail),
          conectado = false,
          onClick = alAbrirDeseos,
        )
      }

      Text(
        stringResource(R.string.settings_about),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
  }
}

@Composable
private fun FilaDeCuenta(
  titulo: String,
  detalle: String,
  conectado: Boolean,
  onClick: () -> Unit,
) {
  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = onClick)
      .padding(16.dp),
    horizontalArrangement = Arrangement.spacedBy(12.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Column(Modifier.weight(1f)) {
      Text(titulo, style = MaterialTheme.typography.bodyLarge)
      Text(
        detalle,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }

    if (conectado) {
      Icon(
        Icons.Default.CheckCircle,
        contentDescription = null,
        tint = MaterialTheme.colorScheme.primary,
      )
    }

    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
  }
}
