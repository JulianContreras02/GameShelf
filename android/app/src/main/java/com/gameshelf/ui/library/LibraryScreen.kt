package com.gameshelf.ui.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CreateNewFolder
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.data.steam.SteamAuthError
import com.gameshelf.domain.Game
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.format.LastPlayedFormatter
import com.gameshelf.ui.collections.BulkAddToCollectionSheet
import com.gameshelf.ui.common.AvisoDeFallo
import com.gameshelf.ui.common.EstadoVacio
import com.gameshelf.ui.common.userMessage
import com.gameshelf.ui.common.userRecovery
import com.gameshelf.ui.common.vector
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Pantalla principal: la biblioteca de juegos.
 *
 * Todo lo que puede fallar (hablar con Steam, guardar) pasa por
 * [LibraryViewModel]. Ver `docs/decisiones/001-arquitectura.md`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
  alAbrirJuego: (UUID) -> Unit,
  alAbrirInsights: () -> Unit,
  alAbrirDeseos: () -> Unit,
) {
  val container = LocalAppContainer.current
  val vm: LibraryViewModel = viewModel(factory = container.viewModelFactory)
  val ambito = rememberCoroutineScope()

  val todos by vm.allGames.collectAsStateWithLifecycle()
  val visibles by vm.games.collectAsStateWithLifecycle()
  val consulta by vm.query.collectAsStateWithLifecycle()
  val estado by vm.state.collectAsStateWithLifecycle()
  val ultimaSync by vm.lastSyncedAt.collectAsStateWithLifecycle()
  val sinJuegosEnLaUltima by vm.lastSyncReturnedNoGames.collectAsStateWithLifecycle()
  val colecciones by vm.collections.collectAsStateWithLifecycle()
  val etiquetas by vm.tags.collectAsStateWithLifecycle()

  var modoSeleccion by remember { mutableStateOf(false) }
  var seleccionados by remember { mutableStateOf(emptySet<UUID>()) }
  var mostrandoFiltros by remember { mutableStateOf(false) }
  var agregandoAColeccion by remember { mutableStateOf(false) }

  // Primera sincronizacion automatica: la biblioteca aparece sola al abrir por
  // primera vez, sin tener que tocar nada.
  LaunchedEffect(Unit) { vm.syncIfNeeded() }

  // Al cambiar la busqueda se limpia la seleccion: si no, se podrian mover
  // juegos que ya no estan a la vista.
  LaunchedEffect(consulta.search) { seleccionados = emptySet() }

  val juegosSeleccionados = remember(todos, seleccionados) {
    todos.filter { it.id in seleccionados }
  }

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(stringResource(R.string.tab_library)) },
        navigationIcon = {
          if (todos.isNotEmpty()) {
            MenuDeOpciones(
              filtroActivo = consulta.filter.isActive,
              modoSeleccion = modoSeleccion,
              haySeleccion = seleccionados.isNotEmpty(),
              ordenActual = consulta.sort,
              alOrdenar = vm::setSort,
              alFiltrar = { mostrandoFiltros = true },
              alQuitarFiltros = vm::clearFilters,
              alSeleccionar = { modoSeleccion = true },
              alAgregarAColeccion = { agregandoAColeccion = true },
            )
          }
        },
        actions = {
          when {
            modoSeleccion -> TextButton(onClick = {
              seleccionados = emptySet()
              modoSeleccion = false
            }) { Text(stringResource(R.string.action_done)) }

            estado.isSyncing -> CircularProgressIndicator(Modifier.size(24.dp))

            else -> {
              IconButton(onClick = alAbrirDeseos) {
                Icon(
                  Icons.Default.FavoriteBorder,
                  contentDescription = stringResource(R.string.tab_wishlist),
                )
              }
              IconButton(onClick = alAbrirInsights) {
                Icon(
                  Icons.Default.BarChart,
                  contentDescription = stringResource(R.string.insights_title),
                )
              }
              IconButton(onClick = vm::sync) {
                Icon(
                  Icons.Default.Refresh,
                  contentDescription = stringResource(R.string.action_sync),
                )
              }
            }
          }
        },
      )
    },
  ) { relleno ->
    Column(Modifier.padding(relleno).fillMaxSize()) {
      OutlinedTextField(
        value = consulta.search,
        onValueChange = vm::setSearch,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        placeholder = { Text(stringResource(R.string.library_search_placeholder)) },
        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
        trailingIcon = {
          if (consulta.search.isNotEmpty()) {
            IconButton(onClick = { vm.setSearch("") }) {
              Icon(
                Icons.Default.Close,
                contentDescription = stringResource(R.string.action_clear_search),
              )
            }
          }
        },
        singleLine = true,
      )

      when {
        todos.isEmpty() -> LibraryEmptyState(
          estado = estado,
          syncReturnedNoGames = sinJuegosEnLaUltima,
          alReintentar = vm::sync,
        )

        // Hay juegos, pero ninguno coincide con la busqueda: es un caso
        // distinto de "todavia no tienes juegos" y merece su propio mensaje.
        visibles.isEmpty() -> EstadoVacio(
          icono = Icons.Default.Search,
          titulo = stringResource(R.string.library_no_results),
          descripcion = stringResource(R.string.library_no_results_detail, consulta.search),
          accion = {
            OutlinedButton(onClick = { vm.setSearch("") }) {
              Text(stringResource(R.string.action_clear_search))
            }
          },
        )

        else -> ListaDeJuegos(
          juegos = visibles,
          total = todos.size,
          consulta = consulta,
          estado = estado,
          ultimaSync = ultimaSync?.let { fecha ->
            stringResource(
              R.string.library_updated,
              LastPlayedFormatter.text(LocalContextCompat(), fecha).lowercase(),
            )
          },
          modoSeleccion = modoSeleccion,
          seleccionados = seleccionados,
          alReintentar = vm::sync,
          alTocar = { juego ->
            if (modoSeleccion) {
              seleccionados = if (juego.id in seleccionados) {
                seleccionados - juego.id
              } else {
                seleccionados + juego.id
              }
            } else {
              alAbrirJuego(juego.id)
            }
          },
          alCambiarEstado = { juego, nuevo -> vm.setStatus(juego.id, nuevo) },
        )
      }
    }
  }

  if (mostrandoFiltros) {
    GameFiltersSheet(
      filtro = consulta.filter,
      colecciones = colecciones,
      etiquetas = etiquetas,
      resultados = visibles.size,
      alCambiar = vm::setFilter,
      alCerrar = { mostrandoFiltros = false },
    )
  }

  if (agregandoAColeccion) {
    BulkAddToCollectionSheet(
      juegos = juegosSeleccionados,
      alCerrar = {
        // Al cerrar la hoja se sale del modo seleccion: dejarlo activo con los
        // mismos juegos marcados confunde sobre si ya se agregaron.
        agregandoAColeccion = false
        seleccionados = emptySet()
        modoSeleccion = false
      },
    )
  }
}

@Composable
private fun ListaDeJuegos(
  juegos: List<Game>,
  total: Int,
  consulta: GameQuery,
  estado: LibraryViewModel.State,
  ultimaSync: String?,
  modoSeleccion: Boolean,
  seleccionados: Set<UUID>,
  alReintentar: () -> Unit,
  alTocar: (Game) -> Unit,
  alCambiarEstado: (Game, PlayStatus) -> Unit,
) {
  val contexto = LocalContextCompat()

  LazyColumn(Modifier.fillMaxSize()) {
    // Si la red falla pero hay datos guardados, se avisa sin tapar la
    // biblioteca: los datos viejos siguen siendo utiles.
    if (estado is LibraryViewModel.State.Failed) {
      item {
        AvisoDeFallo(
          mensaje = estado.error.userMessage(contexto, R.string.error_sync_generic),
          sugerencia = estado.error.userRecovery(contexto),
          alReintentar = alReintentar,
        )
      }
    }

    item {
      Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
      ) {
        Text(
          textoEncabezado(modoSeleccion, seleccionados.size, consulta, juegos.size, total),
          style = MaterialTheme.typography.labelLarge,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (ultimaSync != null && !modoSeleccion) {
          Text(
            ultimaSync,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
        }
      }
      HorizontalDivider()
    }

    items(juegos, key = { it.id }) { juego ->
      GameRow(
        game = juego,
        seleccionado = if (modoSeleccion) juego.id in seleccionados else null,
        onClick = { alTocar(juego) },
        onLongClick = { alCambiarEstado(juego, siguienteEstado(juego.status)) },
      )
    }
  }
}

/**
 * Que dice el encabezado de la lista.
 *
 * Con la lista recortada hay que decir cuantos se ven **y** cuantos hay, o
 * parece que faltan juegos.
 */
@Composable
private fun textoEncabezado(
  modoSeleccion: Boolean,
  seleccionados: Int,
  consulta: GameQuery,
  visibles: Int,
  total: Int,
): String = when {
  modoSeleccion && seleccionados == 0 -> stringResource(R.string.library_select_games)
  modoSeleccion -> stringResource(R.string.library_selected_count, seleccionados)
  !consulta.isNarrowing -> stringResource(R.string.library_game_count, total)
  consulta.search.isNotBlank() -> stringResource(R.string.library_result_count, visibles)
  else -> stringResource(R.string.library_visible_of_total, visibles, total)
}

/**
 * El estado que sigue en el recorrido natural de un juego.
 *
 * Sirve para el gesto rapido de la lista. El menu completo esta en la ficha:
 * aca solo se ofrece el paso siguiente, que es el que se quiere el 90% de las
 * veces.
 */
private fun siguienteEstado(actual: PlayStatus): PlayStatus {
  val orden = PlayStatus.displayOrder
  val indice = orden.indexOf(actual)
  return orden[(indice + 1) % orden.size]
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MenuDeOpciones(
  filtroActivo: Boolean,
  modoSeleccion: Boolean,
  haySeleccion: Boolean,
  ordenActual: GameSortOrder,
  alOrdenar: (GameSortOrder) -> Unit,
  alFiltrar: () -> Unit,
  alQuitarFiltros: () -> Unit,
  alSeleccionar: () -> Unit,
  alAgregarAColeccion: () -> Unit,
) {
  var abierto by remember { mutableStateOf(false) }

  if (modoSeleccion) {
    IconButton(onClick = alAgregarAColeccion, enabled = haySeleccion) {
      Icon(
        Icons.Default.CreateNewFolder,
        contentDescription = stringResource(R.string.action_add_to_collection),
      )
    }
    return
  }

  Box {
    IconButton(onClick = { abierto = true }) {
      Icon(
        if (filtroActivo) Icons.Default.FilterList else Icons.Default.MoreVert,
        contentDescription = stringResource(R.string.action_options),
      )
    }

    DropdownMenu(expanded = abierto, onDismissRequest = { abierto = false }) {
      Text(
        stringResource(R.string.action_sort_by),
        style = MaterialTheme.typography.labelSmall,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )

      GameSortOrder.entries.forEach { orden ->
        DropdownMenuItem(
          text = { Text(stringResource(orden.displayNameRes)) },
          leadingIcon = { Icon(orden.icon.vector, contentDescription = null) },
          trailingIcon = {
            if (orden == ordenActual) Icon(Icons.Default.Checklist, contentDescription = null)
          },
          onClick = {
            alOrdenar(orden)
            abierto = false
          },
        )
      }

      HorizontalDivider()

      DropdownMenuItem(
        text = { Text(stringResource(R.string.action_filter)) },
        leadingIcon = { Icon(Icons.Default.FilterList, contentDescription = null) },
        onClick = {
          alFiltrar()
          abierto = false
        },
      )

      if (filtroActivo) {
        DropdownMenuItem(
          text = { Text(stringResource(R.string.action_clear_filters)) },
          leadingIcon = { Icon(Icons.Default.Close, contentDescription = null) },
          onClick = {
            alQuitarFiltros()
            abierto = false
          },
        )
      }

      DropdownMenuItem(
        text = { Text(stringResource(R.string.action_select_games)) },
        leadingIcon = { Icon(Icons.Default.Checklist, contentDescription = null) },
        onClick = {
          alSeleccionar()
          abierto = false
        },
      )
    }
  }
}

/** Estado vacio de la biblioteca, con el motivo de por que esta vacia. */
@Composable
private fun LibraryEmptyState(
  estado: LibraryViewModel.State,
  syncReturnedNoGames: Boolean,
  alReintentar: () -> Unit,
) {
  val contexto = LocalContextCompat()

  when {
    estado.isSyncing -> EstadoVacio(
      icono = Icons.Default.SportsEsports,
      titulo = stringResource(R.string.library_syncing),
      descripcion = stringResource(R.string.library_syncing_detail),
    )

    // La biblioteca se llena desde las tres tiendas, asi que quedarse sin
    // credenciales de Steam no significa aca "falta Steam" sino "no hay de
    // donde traer juegos". El error de Steam es correcto en su propia pantalla
    // y en la lista de deseos, que si son solo suyas; aca senalaria una sola de
    // las tres. Tampoco se ofrece reintentar: repetir la misma peticion sin
    // credenciales daria el mismo error.
    estado is LibraryViewModel.State.Failed && estado.error is SteamAuthError.SinCredenciales ->
      EstadoVacio(
        icono = Icons.Default.SportsEsports,
        titulo = stringResource(R.string.library_no_accounts),
        descripcion = stringResource(R.string.library_no_accounts_detail),
      )

    estado is LibraryViewModel.State.Failed -> EstadoVacio(
      icono = Icons.Default.SportsEsports,
      titulo = estado.error.userMessage(contexto, R.string.error_sync_generic),
      descripcion = estado.error.userRecovery(contexto),
      accion = {
        OutlinedButton(onClick = alReintentar) { Text(stringResource(R.string.action_retry)) }
      },
    )

    // Steam responde igual con la biblioteca vacia y con el perfil privado, asi
    // que se explican las dos posibilidades en vez de afirmar una.
    syncReturnedNoGames -> EstadoVacio(
      icono = Icons.Default.SportsEsports,
      titulo = stringResource(R.string.library_empty_after_sync),
      descripcion = stringResource(R.string.library_empty_after_sync_detail),
      accion = {
        OutlinedButton(onClick = alReintentar) { Text(stringResource(R.string.action_retry)) }
      },
    )

    else -> EstadoVacio(
      icono = Icons.Default.SportsEsports,
      titulo = stringResource(R.string.library_empty),
      descripcion = stringResource(R.string.library_empty_detail),
      accion = {
        OutlinedButton(onClick = alReintentar) { Text(stringResource(R.string.action_sync)) }
      },
    )
  }
}

/**
 * El `Context` actual, para las funciones de dominio que dan formato a textos.
 *
 * Se envuelve en una funcion propia porque se pide en varios sitios de esta
 * pantalla y `LocalContext.current` dentro de un `when` se lee peor.
 */
@Composable
private fun LocalContextCompat() = androidx.compose.ui.platform.LocalContext.current
