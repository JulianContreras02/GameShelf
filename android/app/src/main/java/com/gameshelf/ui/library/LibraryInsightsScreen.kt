package com.gameshelf.ui.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.domain.format.PlaytimeFormatter
import com.gameshelf.ui.common.EstadoVacio
import com.gameshelf.ui.common.vector
import kotlinx.coroutines.launch
import java.util.UUID
import kotlin.math.roundToInt

/**
 * Lo que la app deduce sola de la biblioteca.
 *
 * Complementa el estado manual en vez de reemplazarlo: con cientos de juegos,
 * marcarlos uno a uno no escala, pero las horas que reporta Steam ya dicen
 * mucho.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryInsightsScreen(alAbrirJuego: (UUID) -> Unit, alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: LibraryViewModel = viewModel(factory = container.viewModelFactory)
  val juegos by vm.allGames.collectAsStateWithLifecycle()
  val contexto = LocalContext.current
  val ambito = rememberCoroutineScope()
  val avisos = remember { SnackbarHostState() }

  val resumen = remember(juegos) { LibraryInsights.summary(juegos) }
  val secciones = remember(juegos) { LibraryInsights.sections(juegos) }
  val concentracion = remember(juegos) { LibraryInsights.concentration(juegos) }
  val candidatos = remember(juegos) { LibraryInsights.candidatesForBacklog(juegos) }

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(stringResource(R.string.insights_title)) },
        navigationIcon = {
          IconButton(onClick = alVolver) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.action_back),
            )
          }
        },
      )
    },
    snackbarHost = { SnackbarHost(avisos) },
  ) { relleno ->
    if (resumen.isEmpty) {
      EstadoVacio(
        icono = Icons.Default.BarChart,
        titulo = stringResource(R.string.insights_empty),
        descripcion = stringResource(R.string.insights_empty_detail),
        modifier = Modifier.padding(relleno),
      )
      return@Scaffold
    }

    LazyColumn(
      Modifier.padding(relleno).fillMaxSize(),
      contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      item {
        Card {
          Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
              stringResource(R.string.insights_summary),
              style = MaterialTheme.typography.titleMedium,
            )

            Dato(
              stringResource(R.string.insights_total_games),
              resumen.totalGames.toString(),
            )
            Dato(
              stringResource(R.string.insights_total_hours),
              PlaytimeFormatter.short(contexto, resumen.totalHours),
            )
            Dato(
              stringResource(R.string.insights_average_hours),
              PlaytimeFormatter.short(contexto, resumen.averageHoursPerPlayedGame),
            )

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
              Dato(
                stringResource(R.string.insights_unplayed),
                stringResource(
                  R.string.insights_unplayed_value,
                  resumen.unplayedCount,
                  (resumen.unplayedFraction * 100).roundToInt(),
                ),
              )
              LinearProgressIndicator(
                progress = { resumen.unplayedFraction.toFloat() },
                modifier = Modifier.fillMaxWidth(),
              )
            }
          }
        }
      }

      if (concentracion.gamesForHalfTheTime > 0) {
        item {
          Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
              Text(
                stringResource(R.string.insights_concentration),
                style = MaterialTheme.typography.titleMedium,
              )
              Text(
                pluralStringResource(
                  R.plurals.insights_half_the_time,
                  concentracion.gamesForHalfTheTime,
                  concentracion.gamesForHalfTheTime,
                ),
                style = MaterialTheme.typography.bodyMedium,
              )
              Dato(
                stringResource(R.string.insights_top_game_share),
                "${(concentracion.topGameShare * 100).roundToInt()}%",
              )
              Dato(
                stringResource(R.string.insights_top_five_share),
                "${(concentracion.topFiveShare * 100).roundToInt()}%",
              )
            }
          }
        }
      }

      // La sugerencia solo aparece si hay algo que sugerir: un boton que no
      // haria nada es peor que ningun boton.
      if (candidatos.isNotEmpty()) {
        item {
          Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
              Text(
                pluralStringResource(
                  R.plurals.insights_mark_backlog,
                  candidatos.size,
                  candidatos.size,
                ),
                style = MaterialTheme.typography.titleSmall,
              )
              Text(
                stringResource(R.string.insights_mark_backlog_criteria),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
              OutlinedButton(onClick = {
                ambito.launch {
                  val cuantos = vm.markCandidatesAsBacklog()
                  avisos.showSnackbar(
                    contexto.resources.getQuantityString(
                      R.plurals.insights_marked_backlog, cuantos, cuantos,
                    ),
                  )
                }
              }) {
                Text(stringResource(R.string.action_apply))
              }
            }
          }
        }
      }

      items(secciones, key = { it.id }) { seccion ->
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
          Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            Icon(
              seccion.kind.icon.vector,
              contentDescription = null,
              modifier = Modifier.size(20.dp),
            )
            Text(
              stringResource(seccion.kind.titleRes),
              style = MaterialTheme.typography.titleMedium,
            )
            if (seccion.hasMore) {
              Text(
                stringResource(R.string.insights_section_more, seccion.totalCount),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
          }

          Text(
            stringResource(seccion.kind.explanationRes),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )

          LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(seccion.games, key = { it.id }) { juego ->
              GameChipRow(game = juego, onClick = { alAbrirJuego(juego.id) })
            }
          }
        }
      }
    }
  }
}

@Composable
private fun Dato(etiqueta: String, valor: String) {
  Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
    Text(
      etiqueta,
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Text(valor, style = MaterialTheme.typography.bodyMedium)
  }
}
