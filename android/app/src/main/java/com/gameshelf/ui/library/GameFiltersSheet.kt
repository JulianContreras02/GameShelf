package com.gameshelf.ui.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.gameshelf.R
import com.gameshelf.domain.GameCollection
import com.gameshelf.domain.GameTag
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store

/**
 * Hoja para acotar la biblioteca.
 *
 * Ensena el numero de resultados en vivo mientras se marcan casillas: sin eso,
 * el usuario descubre que se quedo sin juegos solo al cerrar la hoja.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun GameFiltersSheet(
  filtro: GameFilter,
  colecciones: List<GameCollection>,
  etiquetas: List<GameTag>,
  resultados: Int,
  alCambiar: (GameFilter) -> Unit,
  alCerrar: () -> Unit,
) {
  val estadoHoja = rememberModalBottomSheetState(skipPartiallyExpanded = true)

  ModalBottomSheet(onDismissRequest = alCerrar, sheetState = estadoHoja) {
    Column(
      Modifier
        .verticalScroll(rememberScrollState())
        .padding(horizontal = 24.dp)
        .padding(bottom = 32.dp),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Text(
          stringResource(R.string.filters_title),
          style = MaterialTheme.typography.titleLarge,
        )
        if (filtro.isActive) {
          TextButton(onClick = { alCambiar(GameFilter.NONE) }) {
            Text(stringResource(R.string.action_clear_filters))
          }
        }
      }

      Text(
        stringResource(R.string.filters_result_count, resultados),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )

      Grupo(stringResource(R.string.filters_store)) {
        Store.entries.forEach { tienda ->
          FilterChip(
            selected = tienda in filtro.stores,
            onClick = { alCambiar(filtro.copy(stores = filtro.stores.alternar(tienda))) },
            label = { Text(tienda.displayName) },
          )
        }
      }

      Grupo(stringResource(R.string.filters_status)) {
        PlayStatus.displayOrder.forEach { estado ->
          FilterChip(
            selected = estado in filtro.statuses,
            onClick = { alCambiar(filtro.copy(statuses = filtro.statuses.alternar(estado))) },
            label = { Text(stringResource(estado.displayNameRes)) },
          )
        }
      }

      if (colecciones.isNotEmpty()) {
        Grupo(stringResource(R.string.filters_collection)) {
          colecciones.forEach { coleccion ->
            FilterChip(
              selected = coleccion.id in filtro.collectionIDs,
              onClick = {
                alCambiar(filtro.copy(collectionIDs = filtro.collectionIDs.alternar(coleccion.id)))
              },
              label = { Text(coleccion.name) },
            )
          }
        }
      }

      if (etiquetas.isNotEmpty()) {
        Grupo(stringResource(R.string.filters_tag)) {
          etiquetas.forEach { etiqueta ->
            FilterChip(
              selected = etiqueta.id in filtro.tagIDs,
              onClick = { alCambiar(filtro.copy(tagIDs = filtro.tagIDs.alternar(etiqueta.id))) },
              label = { Text(etiqueta.name) },
            )
          }
        }
      }
    }
  }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Grupo(titulo: String, contenido: @Composable () -> Unit) {
  Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(titulo, style = MaterialTheme.typography.titleSmall)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { contenido() }
  }
}

/**
 * Mete o saca un valor del conjunto.
 *
 * Un conjunto vacio significa "cualquiera", no "ninguno": es lo que hace que
 * desmarcar la ultima casilla vuelva a mostrar toda la biblioteca en vez de
 * dejarla en blanco.
 */
private fun <T> Set<T>.alternar(valor: T): Set<T> =
  if (valor in this) this - valor else this + valor
