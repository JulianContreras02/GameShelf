package com.gameshelf.ui.progress

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.domain.PlayStatus
import com.gameshelf.ui.common.EstadoVacio
import com.gameshelf.ui.common.PantallaPrincipal
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.detail.GameStatusViewModel
import com.gameshelf.ui.library.GameRow
import com.gameshelf.ui.library.LibraryViewModel
import java.util.UUID

/**
 * La biblioteca vista por estado de progreso.
 *
 * Es la contraparte manual de los grupos automaticos: alli la app deduce, aca
 * manda lo que dijo el usuario. Se ensenan **todos** los estados aunque esten
 * en cero, para que la pantalla no cambie de forma segun lo que haya.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun GameProgressScreen(alAbrirJuego: (UUID) -> Unit) {
  val container = LocalAppContainer.current
  val vm: LibraryViewModel = viewModel(factory = container.viewModelFactory)
  val juegos by vm.allGames.collectAsStateWithLifecycle()

  var elegido by remember { mutableStateOf(PlayStatus.PLAYING) }

  val conteos = remember(juegos) { GameStatusViewModel.counts(juegos) }
  val visibles = remember(juegos, elegido) { GameStatusViewModel.games(juegos, elegido) }

  PantallaPrincipal(titulo = stringResource(R.string.tab_progress)) { relleno ->
    Column(Modifier.padding(relleno).fillMaxSize()) {
      FlowRow(
        Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
      ) {
        PlayStatus.displayOrder.forEach { estado ->
          FilterChip(
            selected = estado == elegido,
            onClick = { elegido = estado },
            label = {
              Text("${stringResource(estado.displayNameRes)} (${conteos[estado] ?: 0})")
            },
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
        stringResource(elegido.explanationRes),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
      )

      Spacer(Modifier.height(8.dp))

      if (visibles.isEmpty()) {
        EstadoVacio(
          icono = Icons.Default.BarChart,
          titulo = stringResource(R.string.progress_empty, stringResource(elegido.displayNameRes)),
          descripcion = stringResource(R.string.progress_empty_detail),
        )
        return@Column
      }

      LazyColumn(Modifier.fillMaxSize()) {
        items(visibles, key = { it.id }) { juego ->
          GameRow(game = juego, onClick = { alAbrirJuego(juego.id) })
        }
      }
    }
  }
}
