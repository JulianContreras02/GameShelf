package com.gameshelf.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.gameshelf.R
import kotlinx.coroutines.delay

/**
 * Editor de las notas personales de un juego.
 *
 * Las notas son el dato mas irrecuperable de la app: un juego borrado se
 * vuelve a sincronizar, pero lo que escribio el usuario no. Por eso se guardan
 * solas, sin boton, un momento despues de dejar de escribir. Ese retardo es lo
 * que evita una escritura en disco por cada tecla.
 */
@Composable
fun GameNotesEditor(
  notas: String,
  alGuardar: (String) -> Unit,
  modifier: Modifier = Modifier,
) {
  var texto by rememberSaveable(notas) { mutableStateOf(notas) }

  // Guardado automatico con retardo. Se reinicia con cada pulsacion, asi que
  // solo se escribe cuando el usuario de verdad se detiene.
  LaunchedEffect(texto) {
    if (texto == notas) return@LaunchedEffect
    delay(RETARDO_DE_GUARDADO)
    alGuardar(texto)
  }

  Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(stringResource(R.string.detail_notes), style = MaterialTheme.typography.titleMedium)

    OutlinedTextField(
      value = texto,
      onValueChange = { nuevo ->
        // Se corta al escribir y no solo al guardar: asi el contador nunca
        // ensena un numero que despues no se va a respetar.
        texto = nuevo.take(GameNotesViewModel.MAX_LENGTH)
      },
      modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp),
      placeholder = { Text(stringResource(R.string.detail_notes_placeholder)) },
    )

    if (GameNotesViewModel.shouldShowCounter(texto)) {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        Text(
          stringResource(
            R.string.detail_notes_counter,
            texto.length,
            GameNotesViewModel.MAX_LENGTH,
          ),
          style = MaterialTheme.typography.labelSmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }
  }
}

/** Cuanto se espera tras la ultima tecla antes de guardar. */
private const val RETARDO_DE_GUARDADO = 800L
