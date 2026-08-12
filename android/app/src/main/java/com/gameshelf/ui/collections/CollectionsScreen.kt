package com.gameshelf.ui.collections

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.domain.GameCollection
import com.gameshelf.domain.format.PlaytimeFormatter
import com.gameshelf.ui.common.EstadoVacio
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.library.GameRow
import com.gameshelf.ui.theme.composeColor
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Las carpetas del usuario.
 *
 * Es lo que ninguna tienda permite: juntar en un mismo grupo juegos de Steam,
 * PSN y Epic.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CollectionsScreen(alAbrirColeccion: (UUID) -> Unit, alCrear: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: CollectionsViewModel = viewModel(factory = container.viewModelFactory)
  val colecciones by vm.collections.collectAsStateWithLifecycle()

  var aBorrar by remember { mutableStateOf<GameCollection?>(null) }
  val ambito = rememberCoroutineScope()

  Scaffold(
    topBar = { TopAppBar(title = { Text(stringResource(R.string.tab_collections)) }) },
    floatingActionButton = {
      FloatingActionButton(onClick = alCrear) {
        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.action_new_collection))
      }
    },
  ) { relleno ->
    if (colecciones.isEmpty()) {
      EstadoVacio(
        icono = Icons.Default.Folder,
        titulo = stringResource(R.string.collections_empty),
        descripcion = stringResource(R.string.collections_empty_detail),
        modifier = Modifier.padding(relleno),
        accion = {
          OutlinedButton(onClick = alCrear) {
            Text(stringResource(R.string.action_new_collection))
          }
        },
      )
      return@Scaffold
    }

    LazyColumn(Modifier.padding(relleno).fillMaxSize()) {
      items(colecciones, key = { it.id }) { coleccion ->
        val indice = colecciones.indexOf(coleccion)

        FilaDeColeccion(
          coleccion = coleccion,
          puedeSubir = indice > 0,
          puedeBajar = indice < colecciones.lastIndex,
          alAbrir = { alAbrirColeccion(coleccion.id) },
          alSubir = { vm.move(colecciones, indice, indice - 1) },
          alBajar = { vm.move(colecciones, indice, indice + 1) },
          alBorrar = { aBorrar = coleccion },
        )
        HorizontalDivider()
      }
    }
  }

  // Borrar una coleccion no borra juegos, pero eso no es obvio: se dice antes
  // de hacerlo para que nadie dude.
  aBorrar?.let { coleccion ->
    AlertDialog(
      onDismissRequest = { aBorrar = null },
      title = { Text(stringResource(R.string.collection_delete_title, coleccion.name)) },
      text = { Text(stringResource(R.string.collection_delete_message)) },
      confirmButton = {
        TextButton(onClick = {
          ambito.launch { vm.delete(coleccion) }
          aBorrar = null
        }) { Text(stringResource(R.string.action_delete)) }
      },
      dismissButton = {
        TextButton(onClick = { aBorrar = null }) { Text(stringResource(R.string.action_cancel)) }
      },
    )
  }
}

@Composable
private fun FilaDeColeccion(
  coleccion: GameCollection,
  puedeSubir: Boolean,
  puedeBajar: Boolean,
  alAbrir: () -> Unit,
  alSubir: () -> Unit,
  alBajar: () -> Unit,
  alBorrar: () -> Unit,
) {
  val contexto = LocalContext.current

  Row(
    Modifier
      .fillMaxWidth()
      .clickable(onClick = alAbrir)
      .padding(horizontal = 16.dp, vertical = 12.dp),
    horizontalArrangement = Arrangement.spacedBy(12.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      coleccion.symbol.vector,
      contentDescription = null,
      tint = coleccion.color.composeColor,
      modifier = Modifier.size(28.dp),
    )

    Column(Modifier.weight(1f)) {
      Text(coleccion.name, style = MaterialTheme.typography.bodyLarge)
      Text(
        pluralStringResource(
          R.plurals.collection_game_count,
          coleccion.gameCount,
          coleccion.gameCount,
        ) + " · " + PlaytimeFormatter.short(contexto, coleccion.totalPlaytimeHours),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }

    // Reordenar con botones y no arrastrando: el arrastre es dificil de usar
    // con un lector de pantalla, y estas dos flechas funcionan igual para
    // todos.
    IconButton(onClick = alSubir, enabled = puedeSubir) {
      Icon(
        Icons.Default.ArrowUpward,
        contentDescription = stringResource(R.string.action_move_up),
      )
    }
    IconButton(onClick = alBajar, enabled = puedeBajar) {
      Icon(
        Icons.Default.ArrowDownward,
        contentDescription = stringResource(R.string.action_move_down),
      )
    }
    IconButton(onClick = alBorrar) {
      Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.action_delete))
    }
  }
}

/** Lo que hay dentro de una coleccion. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CollectionDetailScreen(
  collectionId: UUID,
  alAbrirJuego: (UUID) -> Unit,
  alEditar: () -> Unit,
  alVolver: () -> Unit,
) {
  val container = LocalAppContainer.current
  val vm: CollectionsViewModel = viewModel(factory = container.viewModelFactory)

  val coleccion by remember(collectionId) { vm.observeCollection(collectionId) }
    .collectAsStateWithLifecycle(initialValue = null)

  val actual = coleccion

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(actual?.name.orEmpty()) },
        navigationIcon = {
          IconButton(onClick = alVolver) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.action_back),
            )
          }
        },
        actions = {
          IconButton(onClick = alEditar) {
            Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.action_edit))
          }
        },
      )
    },
  ) { relleno ->
    if (actual == null || actual.isEmpty) {
      EstadoVacio(
        icono = Icons.Default.Folder,
        titulo = stringResource(R.string.collection_empty),
        descripcion = stringResource(R.string.collection_empty_detail),
        modifier = Modifier.padding(relleno),
      )
      return@Scaffold
    }

    LazyColumn(Modifier.padding(relleno).fillMaxSize()) {
      items(actual.games, key = { it.id }) { juego ->
        GameRow(game = juego, onClick = { alAbrirJuego(juego.id) })
      }
    }
  }
}
