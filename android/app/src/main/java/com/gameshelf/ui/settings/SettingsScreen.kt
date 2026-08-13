package com.gameshelf.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.VideogameAsset
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
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
import com.gameshelf.ui.common.PantallaPrincipal

/**
 * Ajustes: las cuentas conectadas y lo que habilita cada una.
 *
 * Antes esta pantalla abria con un aviso de que claves faltaban en el archivo
 * de configuracion. Ya no existe: cada cuenta pide lo suyo al conectarse, asi
 * que una app recien instalada no tiene nada "mal configurado", solo cuentas
 * sin conectar. Lo que era una tarea de compilacion es ahora parte de usar la
 * app.
 */
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

  val sinConectar = stringResource(R.string.settings_not_connected)
  val conectado = stringResource(R.string.settings_connected)

  PantallaPrincipal(titulo = stringResource(R.string.tab_settings)) { relleno ->
    Column(
      Modifier
        .padding(relleno)
        .fillMaxSize()
        .verticalScroll(rememberScrollState())
        .padding(horizontal = 16.dp)
        .padding(bottom = 24.dp),
      verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      TituloDeGrupo(stringResource(R.string.settings_accounts))

      Grupo {
        FilaDeCuenta(
          icono = Icons.Default.Storefront,
          titulo = stringResource(R.string.settings_steam),
          detalle = nombreSteam.takeIf { estadoSteam.isConnected }
            ?: if (estadoSteam.isConnected) conectado else sinConectar,
          activo = estadoSteam.isConnected,
          onClick = alConectarSteam,
        )

        Separador()

        FilaDeCuenta(
          icono = Icons.Default.SportsEsports,
          titulo = stringResource(R.string.settings_playstation),
          detalle = if (estadoPSN.isConnected) conectado else sinConectar,
          activo = estadoPSN.isConnected,
          onClick = alConectarPSN,
        )

        Separador()

        FilaDeCuenta(
          icono = Icons.Default.VideogameAsset,
          titulo = stringResource(R.string.settings_epic),
          detalle = nombreEpic.takeIf { estadoEpic.isConnected }
            ?: if (estadoEpic.isConnected) conectado else sinConectar,
          activo = estadoEpic.isConnected,
          onClick = alConectarEpic,
        )
      }

      TituloDeGrupo(stringResource(R.string.settings_sections))

      Grupo {
        FilaDeCuenta(
          icono = Icons.Default.FavoriteBorder,
          titulo = stringResource(R.string.tab_wishlist),
          detalle = stringResource(R.string.settings_wishlist_detail),
          activo = false,
          onClick = alAbrirDeseos,
        )

        Separador()

        FilaDeCuenta(
          icono = Icons.Default.LocalOffer,
          titulo = stringResource(R.string.settings_prices),
          detalle = if (hayClaveDePrecios) {
            stringResource(R.string.itad_prices_enabled)
          } else {
            stringResource(R.string.settings_prices_detail)
          },
          activo = hayClaveDePrecios,
          onClick = alConfigurarPrecios,
        )
      }

      Text(
        stringResource(R.string.settings_about),
        Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
  }
}

/**
 * Encabezado de un grupo de ajustes.
 *
 * Va en el color primario y en labelLarge, no en titleMedium como antes: un
 * encabezado del mismo tamano que el titulo de las filas que agrupa no separa
 * nada, solo anade ruido.
 */
@Composable
private fun TituloDeGrupo(texto: String) {
  Text(
    texto,
    Modifier.padding(start = 4.dp, top = 16.dp, bottom = 4.dp),
    style = MaterialTheme.typography.labelLarge,
    color = MaterialTheme.colorScheme.primary,
  )
}

/**
 * Una tarjeta que agrupa filas relacionadas.
 *
 * Sin elevacion y con el color de contenedor: en Material 3 la profundidad se
 * da con el tono de la superficie, no con sombras, porque una sombra sobre
 * fondo oscuro no se ve.
 */
@Composable
private fun Grupo(contenido: @Composable () -> Unit) {
  Card(
    Modifier.fillMaxWidth(),
    colors = CardDefaults.cardColors(
      containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
    ),
    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
  ) {
    Column { contenido() }
  }
}

/** Linea entre filas, sangrada para que no corte el icono. */
@Composable
private fun Separador() {
  HorizontalDivider(
    Modifier.padding(start = 68.dp),
    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
  )
}

/**
 * Una fila de ajustes.
 *
 * El icono va dentro de una pastilla de color, que cambia segun si la cuenta
 * esta conectada. Es lo que permite ver el estado de las tres cuentas de un
 * vistazo, sin leer los subtitulos uno por uno.
 */
@Composable
private fun FilaDeCuenta(
  icono: ImageVector,
  titulo: String,
  detalle: String,
  activo: Boolean,
  onClick: () -> Unit,
) {
  ListItem(
    modifier = Modifier.clickable(onClick = onClick),
    colors = ListItemDefaults.colors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    leadingContent = {
      val fondo = if (activo) {
        MaterialTheme.colorScheme.primaryContainer
      } else {
        MaterialTheme.colorScheme.surfaceContainerHighest
      }

      Box(
        Modifier
          .size(40.dp)
          .background(fondo, RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center,
      ) {
        Icon(
          icono,
          contentDescription = null,
          modifier = Modifier.size(20.dp),
          tint = if (activo) {
            MaterialTheme.colorScheme.onPrimaryContainer
          } else {
            MaterialTheme.colorScheme.onSurfaceVariant
          },
        )
      }
    },
    headlineContent = { Text(titulo, style = MaterialTheme.typography.bodyLarge) },
    supportingContent = {
      Text(
        detalle,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    },
    trailingContent = {
      if (activo) {
        Icon(
          Icons.Default.CheckCircle,
          contentDescription = null,
          tint = MaterialTheme.colorScheme.primary,
          modifier = Modifier.size(20.dp),
        )
      } else {
        Icon(
          Icons.AutoMirrored.Filled.KeyboardArrowRight,
          contentDescription = null,
          tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    },
  )
}
