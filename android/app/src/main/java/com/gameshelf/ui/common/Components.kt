package com.gameshelf.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.gameshelf.R

/**
 * Aviso de que la ultima sincronizacion fallo, para poner dentro de una lista.
 *
 * Va como una fila mas y no como pantalla completa a proposito: si la red
 * falla pero hay datos guardados, esos datos siguen sirviendo y taparlos con
 * un error seria peor. Se avisa y se deja seguir.
 */
@Composable
fun AvisoDeFallo(
  mensaje: String,
  modifier: Modifier = Modifier,
  sugerencia: String? = null,
  alReintentar: (() -> Unit)? = null,
) {
  Row(
    modifier = modifier
      .fillMaxWidth()
      .padding(horizontal = 16.dp, vertical = 8.dp)
      .clip(RoundedCornerShape(12.dp))
      .background(AVISO_FONDO)
      .padding(12.dp),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
    verticalAlignment = Alignment.Top,
  ) {
    Icon(
      Icons.Default.Warning,
      contentDescription = null,
      tint = AVISO_ICONO,
      modifier = Modifier.size(20.dp),
    )

    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
      Text(mensaje, style = MaterialTheme.typography.bodySmall)
      Text(
        // Sin sugerencia concreta se dice lo unico util que queda: que lo que
        // se ve sigue sirviendo aunque la ultima sincronizacion fallara.
        text = sugerencia ?: stringResource(R.string.notice_showing_saved_data),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }

    if (alReintentar != null) {
      OutlinedButton(onClick = alReintentar) {
        Text(stringResource(R.string.action_retry))
      }
    }
  }
}

/**
 * Pantalla de "aca no hay nada", con su icono, su explicacion y su salida.
 *
 * Es el equivalente de `ContentUnavailableView`: un estado vacio siempre dice
 * por que esta vacio y que se puede hacer, nunca se queda en blanco.
 */
@Composable
fun EstadoVacio(
  icono: ImageVector,
  titulo: String,
  modifier: Modifier = Modifier,
  descripcion: String? = null,
  accion: (@Composable () -> Unit)? = null,
) {
  Column(
    modifier = modifier
      .fillMaxSize()
      .padding(32.dp),
    verticalArrangement = Arrangement.Center,
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    Icon(
      icono,
      // El icono repite lo que ya dice el titulo: describirlo haria que el
      // lector de pantalla lo leyera dos veces.
      contentDescription = null,
      modifier = Modifier.size(56.dp),
      tint = MaterialTheme.colorScheme.onSurfaceVariant,
    )

    Spacer(Modifier.height(16.dp))

    Text(
      titulo,
      style = MaterialTheme.typography.titleMedium,
      textAlign = TextAlign.Center,
    )

    if (descripcion != null) {
      Spacer(Modifier.height(8.dp))
      Text(
        descripcion,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
      )
    }

    if (accion != null) {
      Spacer(Modifier.height(24.dp))
      accion()
    }
  }
}

/**
 * Una etiqueta pequena, del estilo de las que llevan las tiendas o los estados.
 */
@Composable
fun Chip(
  texto: String,
  modifier: Modifier = Modifier,
  icono: ImageVector? = null,
  color: Color = MaterialTheme.colorScheme.secondaryContainer,
  contenido: Color = MaterialTheme.colorScheme.onSecondaryContainer,
) {
  Row(
    modifier = modifier
      .clip(RoundedCornerShape(8.dp))
      .background(color)
      .padding(horizontal = 8.dp, vertical = 4.dp),
    horizontalArrangement = Arrangement.spacedBy(4.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    if (icono != null) {
      Icon(icono, contentDescription = null, tint = contenido, modifier = Modifier.size(14.dp))
    }
    Text(texto, style = MaterialTheme.typography.labelMedium, color = contenido)
  }
}

/**
 * Envoltorio para lo que ya esta descrito por su vecino.
 *
 * Sirve para que el lector de pantalla no repita un dato que la fila entera ya
 * anuncia.
 */
@Composable
fun SinLeer(contenido: @Composable () -> Unit) {
  Column(Modifier.clearAndSetSemantics {}) { contenido() }
}

private val AVISO_FONDO = Color(0x1FE36209)
private val AVISO_ICONO = Color(0xFFE36209)
