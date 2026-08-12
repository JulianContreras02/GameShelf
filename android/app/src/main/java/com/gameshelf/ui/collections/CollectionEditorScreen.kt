package com.gameshelf.ui.collections

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.data.net.UserFacingError
import com.gameshelf.domain.CollectionColor
import com.gameshelf.domain.CollectionSymbol
import com.gameshelf.domain.GameCollection
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.theme.composeColor
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Formulario de una coleccion: nombre, icono y color.
 *
 * Sirve para crear y para editar. Con [collectionId] a `null`, crea.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CollectionEditorScreen(collectionId: UUID?, alCerrar: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: CollectionsViewModel = viewModel(factory = container.viewModelFactory)
  val contexto = LocalContext.current
  val ambito = rememberCoroutineScope()

  val existente by remember(collectionId) {
    collectionId?.let { vm.observeCollection(it) }
      ?: kotlinx.coroutines.flow.flowOf<GameCollection?>(null)
  }.collectAsStateWithLifecycle(initialValue = null)

  var nombre by remember { mutableStateOf("") }
  var simbolo by remember { mutableStateOf(GameCollection.DEFAULT_SYMBOL) }
  var color by remember { mutableStateOf(CollectionColor.DEFAULT) }
  var error by remember { mutableStateOf<String?>(null) }
  var yaCargado by remember { mutableStateOf(false) }

  // Los valores de la coleccion existente se copian una sola vez: si se
  // copiaran en cada recomposicion, escribir en el campo no haria nada porque
  // el valor guardado lo pisaria en el acto.
  LaunchedEffect(existente) {
    val actual = existente
    if (actual != null && !yaCargado) {
      nombre = actual.name
      simbolo = actual.symbol
      color = actual.color
      yaCargado = true
    }
  }

  Scaffold(
    topBar = {
      TopAppBar(
        title = {
          Text(
            stringResource(
              if (collectionId == null) R.string.collection_new else R.string.collection_edit,
            ),
          )
        },
        navigationIcon = {
          IconButton(onClick = alCerrar) {
            Icon(Icons.Default.Close, contentDescription = stringResource(R.string.action_cancel))
          }
        },
        actions = {
          TextButton(onClick = {
            ambito.launch {
              try {
                val actual = existente
                if (actual == null) {
                  vm.create(nombre, simbolo, color)
                } else {
                  vm.rename(actual, nombre)
                  vm.updateAppearance(actual, simbolo, color)
                }
                alCerrar()
              } catch (e: Throwable) {
                error = (e as? UserFacingError)?.message(contexto) ?: e.message
              }
            }
          }) { Text(stringResource(R.string.action_save)) }
        },
      )
    },
  ) { relleno ->
    Column(
      Modifier
        .padding(relleno)
        .fillMaxSize()
        .verticalScroll(rememberScrollState())
        .padding(16.dp),
      verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
      OutlinedTextField(
        value = nombre,
        onValueChange = {
          nombre = it.take(CollectionsViewModel.MAX_NAME_LENGTH)
          error = null
        },
        modifier = Modifier.fillMaxWidth(),
        label = { Text(stringResource(R.string.collection_name)) },
        singleLine = true,
        isError = error != null,
        supportingText = error?.let { { Text(it) } },
      )

      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.collection_icon), style = MaterialTheme.typography.titleSmall)

        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
          CollectionsViewModel.availableSymbols.forEach { opcion ->
            val elegido = opcion == simbolo
            IconButton(onClick = { simbolo = opcion }) {
              Icon(
                opcion.vector,
                contentDescription = null,
                tint = if (elegido) {
                  color.composeColor
                } else {
                  MaterialTheme.colorScheme.onSurfaceVariant
                },
              )
            }
          }
        }
      }

      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.collection_color), style = MaterialTheme.typography.titleSmall)

        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
          CollectionColor.entries.forEach { opcion ->
            MuestraDeColor(
              color = opcion,
              elegido = opcion == color,
              alElegir = { color = opcion },
            )
          }
        }
      }
    }
  }
}

@Composable
private fun MuestraDeColor(color: CollectionColor, elegido: Boolean, alElegir: () -> Unit) {
  Box(
    Modifier
      .size(40.dp)
      .clip(CircleShape)
      .background(color.composeColor)
      .border(
        width = if (elegido) 3.dp else 0.dp,
        color = if (elegido) MaterialTheme.colorScheme.onSurface else Color.Transparent,
        shape = CircleShape,
      )
      .clickable(onClick = alElegir),
    contentAlignment = Alignment.Center,
  ) {
    if (elegido) {
      Icon(
        Icons.Default.Check,
        // El nombre del color va en la marca de "elegido" y no en cada
        // muestra: asi el lector de pantalla dice cual esta puesto sin recitar
        // los nueve.
        contentDescription = stringResource(color.displayNameRes),
        tint = Color.White,
      )
    }
  }
}
