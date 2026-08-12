package com.gameshelf.ui.detail

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.domain.Game
import com.gameshelf.domain.TrophyKind
import com.gameshelf.domain.format.LastPlayedFormatter
import com.gameshelf.domain.format.PlaytimeFormatter
import com.gameshelf.ui.collections.GameCollectionsPicker
import com.gameshelf.ui.common.Chip
import com.gameshelf.ui.common.EstadoVacio
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.tags.GameTagsEditor
import kotlinx.coroutines.launch
import java.util.UUID

/** La ficha de un juego: lo que dicen las tiendas y lo que puso el usuario. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun GameDetailScreen(gameId: UUID, alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val contexto = LocalContext.current
  val ambito = rememberCoroutineScope()

  val statusVM: GameStatusViewModel = viewModel(factory = container.viewModelFactory)
  val notesVM: GameNotesViewModel = viewModel(factory = container.viewModelFactory)

  val juego by remember(gameId) { container.store.observeGame(gameId) }
    .collectAsStateWithLifecycle(initialValue = null)

  val actual = juego

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(actual?.name.orEmpty(), maxLines = 1) },
        navigationIcon = {
          IconButton(onClick = alVolver) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.action_back),
            )
          }
        },
        actions = {
          actual?.storeLink()?.let { enlace ->
            IconButton(onClick = {
              contexto.startActivity(Intent(Intent.ACTION_VIEW, enlace.toUri()))
            }) {
              Icon(
                Icons.AutoMirrored.Filled.OpenInNew,
                contentDescription = stringResource(R.string.action_open_in_store),
              )
            }
          }
        },
      )
    },
  ) { relleno ->
    if (actual == null) {
      // Pasa un instante al abrir, y para siempre si el juego se borro desde
      // otra pantalla. En los dos casos lo honesto es decirlo.
      EstadoVacio(
        icono = Icons.AutoMirrored.Filled.ArrowBack,
        titulo = stringResource(R.string.detail_not_found),
        modifier = Modifier.padding(relleno),
      )
      return@Scaffold
    }

    LazyColumn(
      Modifier.padding(relleno).fillMaxSize(),
      contentPadding = PaddingValues(16.dp),
      verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
      item { Cabecera(actual) }

      item {
        PlayStatusPicker(
          actual = actual.status,
          alElegir = { nuevo -> ambito.launch { statusVM.setStatus(nuevo, actual) } },
        )
      }

      item { SeccionDeTiendas(actual) }

      actual.trophyBreakdown?.let { desglose ->
        item { TrophyBreakdownCard(desglose) }
      }

      item { GameCollectionsPicker(juego = actual) }

      item { GameTagsEditor(juego = actual) }

      item {
        GameNotesEditor(
          notas = actual.notes,
          alGuardar = { texto -> ambito.launch { notesVM.save(texto, actual) } },
        )
      }
    }
  }
}

@Composable
private fun Cabecera(juego: Game) {
  val contexto = LocalContext.current

  Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
    if (juego.coverImageURL != null) {
      AsyncImage(
        model = juego.coverImageURL,
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier
          .fillMaxWidth()
          .aspectRatio(460f / 215f)
          .clip(RoundedCornerShape(12.dp)),
      )
    }

    Text(juego.name, style = MaterialTheme.typography.headlineSmall)

    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
      DatoDeCabecera(
        stringResource(R.string.detail_playtime),
        PlaytimeFormatter.short(contexto, juego.playtimeHours),
      )
      DatoDeCabecera(
        stringResource(R.string.detail_last_played),
        LastPlayedFormatter.text(contexto, juego.lastPlayedAt),
      )
    }

    if (juego.isComingSoon()) {
      Chip(texto = stringResource(R.string.detail_coming_soon))
    }
  }
}

@Composable
private fun DatoDeCabecera(etiqueta: String, valor: String) {
  Column {
    Text(
      etiqueta,
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Text(valor, style = MaterialTheme.typography.bodyLarge)
  }
}

/**
 * En que tiendas esta el juego, y cuanto se jugo en cada una.
 *
 * Se muestran todas y no solo la suma porque es justo lo que ninguna tienda
 * ensena: el mismo juego con las horas de Steam y las de PlayStation juntas.
 */
@Composable
private fun SeccionDeTiendas(juego: Game) {
  val contexto = LocalContext.current

  Card {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Text(stringResource(R.string.detail_stores), style = MaterialTheme.typography.titleMedium)

      juego.storeEntries.forEachIndexed { indice, entrada ->
        if (indice > 0) HorizontalDivider()

        Row(
          Modifier.fillMaxWidth(),
          horizontalArrangement = Arrangement.SpaceBetween,
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Column {
            Text(entrada.store.displayName, style = MaterialTheme.typography.bodyLarge)
            Text(
              LastPlayedFormatter.text(contexto, entrada.lastPlayedAt),
              style = MaterialTheme.typography.bodySmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
          }

          Text(
            PlaytimeFormatter.short(contexto, entrada.playtimeHours),
            style = MaterialTheme.typography.bodyMedium,
          )
        }
      }

      if (juego.storeEntries.isEmpty()) {
        Text(
          stringResource(R.string.detail_no_stores),
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }
  }
}

/**
 * El desglose de trofeos.
 *
 * El porcentaje y los conteos vienen de la **misma** lista, nunca mezclados:
 * ver la documentacion de `Game.trophyBreakdown` para por que eso importa.
 */
@Composable
private fun TrophyBreakdownCard(desglose: com.gameshelf.domain.TrophyBreakdown) {
  Card {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Text(stringResource(R.string.detail_trophies), style = MaterialTheme.typography.titleMedium)
        desglose.progress?.let {
          Text(
            stringResource(R.string.trophy_progress_percent, it),
            style = MaterialTheme.typography.titleMedium,
          )
        }
      }

      desglose.progress?.let {
        LinearProgressIndicator(
          progress = { it / 100f },
          modifier = Modifier.fillMaxWidth(),
        )
      }

      TrophyKind.entries.forEach { tipo ->
        val total = desglose.defined.count(tipo)
        if (total == 0) return@forEach

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
          Text(stringResource(tipo.displayNameRes), style = MaterialTheme.typography.bodyMedium)
          Text(
            stringResource(
              R.string.trophy_earned_of_total,
              desglose.earned.count(tipo),
              total,
            ),
            style = MaterialTheme.typography.bodyMedium,
          )
        }
      }

      Text(
        stringResource(R.string.trophy_platinum_explanation),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
  }
}
