package com.gameshelf.ui.wishlist

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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Sort
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError
import com.gameshelf.domain.Game
import com.gameshelf.ui.common.AvisoDeFallo
import com.gameshelf.ui.common.EstadoVacio
import com.gameshelf.ui.common.userMessage
import com.gameshelf.ui.common.userRecovery
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.library.GameRow
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * La lista de deseos, con precios si IsThereAnyDeal responde.
 *
 * Los precios son un extra: si su servicio falla, la lista se ensena igual.
 * Perder la lista por no poder consultar un descuento seria el peor negocio.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WishlistScreen(alAbrirJuego: (UUID) -> Unit, alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: WishlistViewModel = viewModel(factory = container.viewModelFactory)
  val contexto = LocalContext.current
  val ambito = rememberCoroutineScope()

  val juegos by vm.games.collectAsStateWithLifecycle()
  val estado by vm.state.collectAsStateWithLifecycle()
  val estadoPrecios by vm.pricesState.collectAsStateWithLifecycle()
  val precios by vm.prices.collectAsStateWithLifecycle()
  val orden by vm.sortOrder.collectAsStateWithLifecycle()
  val sinJuegos by vm.lastSyncReturnedNoGames.collectAsStateWithLifecycle()

  var agregandoAMano by remember { mutableStateOf(false) }
  var aBorrar by remember { mutableStateOf<Game?>(null) }
  var menuDeOrden by remember { mutableStateOf(false) }

  // Los precios se piden cuando ya se sabe que juegos hay. Volver a pedirlos
  // en cada recomposicion gastaria la cuota de la API sin ganar nada.
  LaunchedEffect(juegos.size) { if (juegos.isNotEmpty()) vm.loadPrices() }

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(stringResource(R.string.tab_wishlist)) },
        navigationIcon = {
          IconButton(onClick = alVolver) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.action_back),
            )
          }
        },
        actions = {
          Box {
            IconButton(onClick = { menuDeOrden = true }) {
              Icon(
                Icons.Default.Sort,
                contentDescription = stringResource(R.string.action_sort_by),
              )
            }
            DropdownMenu(expanded = menuDeOrden, onDismissRequest = { menuDeOrden = false }) {
              WishlistSortOrder.entries.forEach { opcion ->
                DropdownMenuItem(
                  text = { Text(stringResource(opcion.displayNameRes)) },
                  leadingIcon = { Icon(opcion.icon.vector, contentDescription = null) },
                  onClick = {
                    vm.setSortOrder(opcion)
                    menuDeOrden = false
                  },
                )
              }
            }
          }

          if (estado.isSyncing) {
            CircularProgressIndicator(Modifier.size(24.dp))
          } else {
            IconButton(onClick = vm::sync) {
              Icon(
                Icons.Default.Refresh,
                contentDescription = stringResource(R.string.action_sync),
              )
            }
          }
        },
      )
    },
    floatingActionButton = {
      FloatingActionButton(onClick = { agregandoAMano = true }) {
        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.wishlist_add_manual))
      }
    },
  ) { relleno ->
    if (juegos.isEmpty()) {
      WishlistEmptyState(
        estado = estado,
        sinJuegos = sinJuegos,
        alSincronizar = vm::sync,
        modifier = Modifier.padding(relleno),
      )
      return@Scaffold
    }

    LazyColumn(Modifier.padding(relleno).fillMaxSize()) {
      if (estado is WishlistViewModel.State.Failed) {
        val fallo = estado as WishlistViewModel.State.Failed
        item {
          AvisoDeFallo(
            mensaje = fallo.error.userMessage(contexto, R.string.error_sync_generic),
            sugerencia = fallo.error.userRecovery(contexto),
            alReintentar = vm::sync,
          )
        }
      }

      // Que los precios fallen no tapa la lista: se avisa en una linea y se
      // sigue.
      if (estadoPrecios is WishlistViewModel.PricesState.Failed) {
        val fallo = estadoPrecios as WishlistViewModel.PricesState.Failed
        item {
          AvisoDeFallo(
            mensaje = fallo.error.userMessage(contexto, R.string.error_prices_generic),
          )
        }
      }

      // Con un orden que depende de precios, hay que decir que todavia estan
      // en camino: si no, la lista parece desordenada sin motivo.
      if (orden.needsPrices && estadoPrecios.isLoading) {
        item {
          Text(
            stringResource(R.string.wishlist_loading_prices),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(16.dp),
          )
        }
      }

      item {
        val enMinimo = vm.countAtHistoricalLow(juegos)
        if (enMinimo > 0) {
          Text(
            stringResource(R.string.wishlist_at_historical_low, enMinimo),
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(16.dp),
          )
          HorizontalDivider()
        }
      }

      items(juegos, key = { it.id }) { juego ->
        Row(
          Modifier.fillMaxWidth(),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Column(Modifier.weight(1f)) {
            GameRow(game = juego, onClick = { alAbrirJuego(juego.id) })

            juego.steamAppID?.let { appID ->
              precios[appID]?.let { precio ->
                WishlistPriceLabel(
                  precios = precio,
                  modifier = Modifier.padding(start = 16.dp, bottom = 8.dp),
                )
              }
            }
          }

          // Solo los agregados a mano se pueden borrar aca: ver
          // WishlistViewModel.canDelete.
          if (WishlistViewModel.canDelete(juego)) {
            IconButton(onClick = { aBorrar = juego }) {
              Icon(
                Icons.Default.Delete,
                contentDescription = stringResource(R.string.action_delete),
              )
            }
          }
        }
        HorizontalDivider()
      }
    }
  }

  if (agregandoAMano) {
    WishlistManualAddDialog(
      alAgregar = { nombre ->
        ambito.launch {
          runCatching { vm.addManually(nombre) }
        }
      },
      alCerrar = { agregandoAMano = false },
    )
  }

  aBorrar?.let { juego ->
    AlertDialog(
      onDismissRequest = { aBorrar = null },
      title = { Text(stringResource(R.string.wishlist_delete_title, juego.name)) },
      confirmButton = {
        TextButton(onClick = {
          vm.delete(juego)
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
private fun WishlistEmptyState(
  estado: WishlistViewModel.State,
  sinJuegos: Boolean,
  alSincronizar: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val contexto = LocalContext.current

  when {
    estado is WishlistViewModel.State.Failed -> EstadoVacio(
      icono = Icons.Default.FavoriteBorder,
      titulo = estado.error.userMessage(contexto, R.string.error_sync_generic),
      descripcion = estado.error.userRecovery(contexto),
      modifier = modifier,
      accion = {
        OutlinedButton(onClick = alSincronizar) { Text(stringResource(R.string.action_retry)) }
      },
    )

    // Steam responde igual con la lista vacia y con la lista privada: se
    // explican las dos posibilidades en vez de afirmar una.
    sinJuegos -> EstadoVacio(
      icono = Icons.Default.FavoriteBorder,
      titulo = stringResource(R.string.wishlist_empty_after_sync),
      descripcion = stringResource(R.string.wishlist_empty_after_sync_detail),
      modifier = modifier,
      accion = {
        OutlinedButton(onClick = alSincronizar) { Text(stringResource(R.string.action_retry)) }
      },
    )

    else -> EstadoVacio(
      icono = Icons.Default.FavoriteBorder,
      titulo = stringResource(R.string.wishlist_empty),
      descripcion = stringResource(R.string.wishlist_empty_detail),
      modifier = modifier,
      accion = {
        OutlinedButton(onClick = alSincronizar) { Text(stringResource(R.string.action_sync)) }
      },
    )
  }
}

/** Dialogo para agregar un juego que no esta en Steam, o cuando su API falla. */
@Composable
private fun WishlistManualAddDialog(alAgregar: (String) -> Unit, alCerrar: () -> Unit) {
  var nombre by remember { mutableStateOf("") }

  AlertDialog(
    onDismissRequest = alCerrar,
    title = { Text(stringResource(R.string.wishlist_add_manual)) },
    text = {
      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
          stringResource(R.string.wishlist_add_manual_detail),
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
          value = nombre,
          onValueChange = { nombre = it },
          label = { Text(stringResource(R.string.wishlist_game_name)) },
          singleLine = true,
        )
      }
    },
    confirmButton = {
      TextButton(
        enabled = nombre.isNotBlank(),
        onClick = {
          alAgregar(nombre)
          alCerrar()
        },
      ) { Text(stringResource(R.string.action_add)) }
    },
    dismissButton = {
      TextButton(onClick = alCerrar) { Text(stringResource(R.string.action_cancel)) }
    },
  )
}
