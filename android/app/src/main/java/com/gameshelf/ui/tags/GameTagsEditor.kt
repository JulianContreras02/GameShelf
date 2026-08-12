package com.gameshelf.ui.tags

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.InputChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.domain.Game
import com.gameshelf.domain.GameTag
import kotlinx.coroutines.launch

/**
 * Editor de etiquetas de un juego.
 *
 * A diferencia de las colecciones, las etiquetas se escriben al vuelo. Lo que
 * resuelve esta pantalla es que escribir "RPG" aqui y "rpg" en otro juego no
 * cree dos etiquetas distintas: el autocompletado ensena la que ya existe
 * antes de que el usuario invente una copia.
 */
@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun GameTagsEditor(juego: Game, modifier: Modifier = Modifier) {
  val container = LocalAppContainer.current
  val vm: TagsViewModel = viewModel(factory = container.viewModelFactory)
  val ambito = rememberCoroutineScope()

  val todas by vm.tags.collectAsStateWithLifecycle()
  var texto by remember { mutableStateOf("") }
  var error by remember { mutableStateOf<String?>(null) }

  val sugerencias = remember(texto, todas, juego.tags) {
    TagsViewModel.suggestions(texto, todas, juego.tags)
  }

  val crearia = remember(texto, todas) { TagsViewModel.wouldCreateNew(texto, todas) }

  Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(stringResource(R.string.detail_tags), style = MaterialTheme.typography.titleMedium)

    if (juego.tags.isNotEmpty()) {
      FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        juego.tags.forEach { etiqueta ->
          InputChip(
            selected = true,
            onClick = { ambito.launch { vm.removeTag(etiqueta, juego) } },
            label = { Text(etiqueta.name) },
            trailingIcon = {
              Icon(
                Icons.Default.Close,
                contentDescription = stringResource(R.string.action_remove_tag, etiqueta.name),
                modifier = Modifier.size(16.dp),
              )
            },
          )
        }
      }
    }

    OutlinedTextField(
      value = texto,
      onValueChange = {
        texto = it.take(GameTag.MAX_NAME_LENGTH)
        error = null
      },
      modifier = Modifier.fillMaxWidth(),
      placeholder = { Text(stringResource(R.string.detail_tags_placeholder)) },
      singleLine = true,
      isError = error != null,
      supportingText = error?.let { { Text(it) } },
      keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
        imeAction = ImeAction.Done,
      ),
      keyboardActions = androidx.compose.foundation.text.KeyboardActions(
        onDone = { agregar(texto) { ambito.launch { vm.addTag(texto, juego); texto = "" } } },
      ),
    )

    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      // "Crear ..." solo aparece cuando de verdad no existe: ofrecerlo siempre
      // haria que el usuario creara duplicados sin darse cuenta.
      if (crearia) {
        AssistChip(
          onClick = { ambito.launch { vm.addTag(texto, juego); texto = "" } },
          label = { Text(stringResource(R.string.detail_tags_create, texto.trim())) },
          leadingIcon = {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
          },
        )
      }

      sugerencias.forEach { etiqueta ->
        AssistChip(
          onClick = { ambito.launch { vm.addTag(etiqueta.name, juego); texto = "" } },
          label = { Text(etiqueta.name) },
        )
      }
    }
  }
}

/** Solo agrega si hay algo escrito. */
private inline fun agregar(texto: String, bloque: () -> Unit) {
  if (texto.isNotBlank()) bloque()
}
