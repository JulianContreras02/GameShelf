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
import com.gameshelf.ui.accounts.EpicAccountViewModel
import com.gameshelf.ui.accounts.ITADKeyViewModel
import com.gameshelf.ui.accounts.PSNAccountViewModel
import com.gameshelf.ui.accounts.SteamAccountViewModel

/**
 * Ajustes: las cuentas conectadas y lo que habilita cada una.
 *
 * Antes esta pantalla abria con un aviso de que claves faltaban en el archivo
 * de configuracion. Ya no existe: cada cuenta pide lo suyo al conectarse, asi
 * que una app recien instalada no tiene nada "mal configurado", solo cuentas
 * sin conectar. Lo que era una tarea de compilacion es ahora parte de usar la
 * app.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
  alConectarSteam: () -> Unit,
  alConectarPSN: () -> Unit,
  alConectarEpic: () -> Unit,
  alConfigurarPrecios: () -> Unit,
  alAbrirDeseos: () -> Unit,
) {
  val container = LocalAppContainer.current
  val steam: SteamAccountViewModel = viewModel(factory = container.viewModelFactory)
  val psn: PSNAccountViewModel = viewModel(factory = container.viewModelFactory)
  val epic: EpicAccountViewModel = viewModel(factory = container.viewModelFactory)
  val precios: ITADKeyViewModel = viewModel(factory = container.viewModelFactory)

  val estadoSteam by steam.state.collectAsStateWithLifecycle()
  val nombreSteam by steam.personaName.collectAsStateWithLifecycle()
  val estadoPSN by psn.state.collectAsStateWithLifecycle()
  val estadoEpic by epic.state.collectAsStateWithLifecycle()
  val nombreEpic by epic.displayName.collectAsStateWithLifecycle()
  val hayClaveDePrecios by precios.hasKey.collectAsStateWithLifecycle()

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
      Text(stringResource(R.string.settings_accounts), style = MaterialTheme.typography.titleMedium)

      Card {
        Column {
          FilaDeCuenta(
            titulo = stringResource(R.string.settings_steam),
            detalle = when {
              estadoSteam.isConnected && nombreSteam != null -> nombreSteam!!
              estadoSteam.isConnected -> stringResource(R.string.settings_connected)
              else -> stringResource(R.string.settings_not_connected)
            },
            conectado = estadoSteam.isConnected,
            onClick = alConectarSteam,
          )

          HorizontalDivider()

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
        Column {
          FilaDeCuenta(
            titulo = stringResource(R.string.tab_wishlist),
            detalle = stringResource(R.string.settings_wishlist_detail),
            conectado = false,
            onClick = alAbrirDeseos,
          )

          HorizontalDivider()

          FilaDeCuenta(
            titulo = stringResource(R.string.settings_prices),
            detalle = if (hayClaveDePrecios) {
              stringResource(R.string.itad_prices_enabled)
            } else {
              stringResource(R.string.settings_prices_detail)
            },
            conectado = hayClaveDePrecios,
            onClick = alConfigurarPrecios,
          )
        }
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
