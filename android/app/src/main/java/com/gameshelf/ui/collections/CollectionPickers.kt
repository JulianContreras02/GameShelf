package com.gameshelf.ui.collections

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.domain.Game
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.theme.composeColor
import kotlinx.coroutines.launch

/**
 * Las colecciones a las que pertenece un juego, dentro de su ficha.
 *
 * Se marcan y desmarcan en el sitio, sin abrir otra pantalla: meter un juego
 * en una carpeta es una accion de un toque y no merece un formulario.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GameCollectionsPicker(juego: Game, modifier: Modifier = Modifier) {
  val container = LocalAppContainer.current
  val vm: CollectionsViewModel = viewModel(factory = container.viewModelFactory)
  val ambito = rememberCoroutineScope()

  val colecciones by vm.collections.collectAsStateWithLifecycle()

  Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(stringResource(R.string.detail_collections), style = MaterialTheme.typography.titleMedium)

    if (colecciones.isEmpty()) {
      Text(
        stringResource(R.string.detail_no_collections),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      return@Column
    }

    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      colecciones.forEach { coleccion ->
        val dentro = juego.collections.any { it.id == coleccion.id }

        FilterChip(
          selected = dentro,
          onClick = { ambito.launch { vm.toggle(juego, coleccion) } },
          label = { Text(coleccion.name) },
          leadingIcon = {
            Icon(
              coleccion.symbol.vector,
              contentDescription = null,
              tint = coleccion.color.composeColor,
              modifier = Modifier.size(18.dp),
            )
          },
        )
      }
    }
  }
}

/**
 * Hoja para meter varios juegos en una coleccion de una vez.
 *
 * Aparece al salir del modo seleccion de la biblioteca. Solo agrega: quitar en
 * lote se hace desde la propia coleccion, que es donde el usuario ve lo que
 * hay dentro.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BulkAddToCollectionSheet(juegos: List<Game>, alCerrar: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: CollectionsViewModel = viewModel(factory = container.viewModelFactory)
  val ambito = rememberCoroutineScope()
  val estadoHoja = rememberModalBottomSheetState(skipPartiallyExpanded = true)

  val colecciones by vm.collections.collectAsStateWithLifecycle()

  ModalBottomSheet(onDismissRequest = alCerrar, sheetState = estadoHoja) {
    Column(
      Modifier
        .verticalScroll(rememberScrollState())
        .padding(horizontal = 24.dp)
        .padding(bottom = 32.dp),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      Text(
        pluralStringResource(R.plurals.bulk_add_title, juegos.size, juegos.size),
        style = MaterialTheme.typography.titleLarge,
      )

      if (colecciones.isEmpty()) {
        Text(
          stringResource(R.string.detail_no_collections),
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }

      colecciones.forEach { coleccion ->
        Row(
          Modifier
            .fillMaxWidth()
            .clickable {
              ambito.launch {
                vm.add(juegos, coleccion)
                alCerrar()
              }
            }
            .padding(vertical = 12.dp),
          horizontalArrangement = Arrangement.spacedBy(12.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Icon(
            coleccion.symbol.vector,
            contentDescription = null,
            tint = coleccion.color.composeColor,
          )
          Text(coleccion.name, Modifier.weight(1f))
          Text(
            coleccion.gameCount.toString(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
        }
      }

      TextButton(onClick = alCerrar) { Text(stringResource(R.string.action_cancel)) }
    }
  }
}
