package com.gameshelf.ui.library

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.gameshelf.R
import com.gameshelf.domain.Game
import com.gameshelf.domain.format.PlaytimeFormatter
import com.gameshelf.ui.common.Chip
import com.gameshelf.ui.common.vector
import com.gameshelf.ui.theme.FormaDeCaratula

/**
 * Una fila de la biblioteca.
 *
 * La fila entera se anuncia como un solo elemento para el lector de pantalla,
 * con una frase armada ("Hollow Knight, 12 horas jugadas, Jugando"), en vez de
 * dejar que lea los tres textos sueltos y la caratula. Es la misma decision de
 * accesibilidad que tomaba la version de iOS.
 */
@Composable
fun GameRow(
  game: Game,
  modifier: Modifier = Modifier,
  seleccionado: Boolean? = null,
  onClick: (() -> Unit)? = null,
  onLongClick: (() -> Unit)? = null,
) {
  val context = LocalContext.current
  val horas = PlaytimeFormatter.accessible(context, game.playtimeHours)
  val estado = stringResource(game.status.displayNameRes)

  Row(
    modifier = modifier
      .fillMaxWidth()
      .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
      .padding(horizontal = 16.dp, vertical = 10.dp)
      .semantics(mergeDescendants = true) {
        contentDescription = "${game.name}, $horas, $estado"
      },
    horizontalArrangement = Arrangement.spacedBy(14.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    if (seleccionado != null) {
      Checkbox(checked = seleccionado, onCheckedChange = { onClick?.invoke() })
    }

    Caratula(game)

    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
      // El nombre en titleMedium y no en bodyLarge: es lo que se busca al
      // recorrer la lista, y con el mismo peso que el tiempo jugado los dos
      // compiten por la mirada.
      Text(
        game.name,
        style = MaterialTheme.typography.titleMedium,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
      )

      Text(
        PlaytimeFormatter.short(context, game.playtimeHours),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )

      Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Chip(texto = estado, icono = game.status.iconName.vector)

        game.stores.forEach { tienda ->
          Chip(
            texto = tienda.displayName,
            color = MaterialTheme.colorScheme.surfaceVariant,
            contenido = MaterialTheme.colorScheme.onSurfaceVariant,
          )
        }
      }
    }

    game.trophyProgress?.let { progreso ->
      Text(
        stringResource(R.string.trophy_progress_percent, progreso),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
  }
}

/**
 * La caratula, o un hueco con la inicial si no hay imagen.
 *
 * El hueco lleva la inicial y no un icono generico para que las filas sin
 * caratula sigan distinguiendose unas de otras de un vistazo.
 *
 * Las medidas siguen la proporcion de las cabeceras de Steam (460x215), que es
 * de donde salen casi todas: recortarlas a otra proporcion las deformaria o les
 * cortaria el titulo, que suele ir centrado en la imagen.
 */
@Composable
private fun Caratula(game: Game) {
  Box(
    modifier = Modifier
      .width(ANCHO_CARATULA)
      .height(ALTO_CARATULA)
      .clip(FormaDeCaratula)
      .background(MaterialTheme.colorScheme.surfaceContainerHighest)
      .clearAndSetSemantics {},
    contentAlignment = Alignment.Center,
  ) {
    if (game.coverImageURL != null) {
      AsyncImage(
        model = game.coverImageURL,
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxWidth().height(ALTO_CARATULA),
      )
    } else {
      Text(
        game.name.take(1).uppercase(),
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
    }
  }
}

private val ANCHO_CARATULA = 92.dp
private val ALTO_CARATULA = 43.dp

/** Version compacta para las listas horizontales de las secciones. */
@Composable
fun GameChipRow(game: Game, onClick: () -> Unit, modifier: Modifier = Modifier) {
  val context = LocalContext.current

  Column(
    modifier = modifier
      .width(140.dp)
      .clickable(onClick = onClick)
      .padding(8.dp),
    verticalArrangement = Arrangement.spacedBy(4.dp),
  ) {
    Box(
      Modifier
        .fillMaxWidth()
        .height(66.dp)
        .clip(RoundedCornerShape(8.dp))
        .background(MaterialTheme.colorScheme.surfaceVariant),
      contentAlignment = Alignment.Center,
    ) {
      if (game.coverImageURL != null) {
        AsyncImage(
          model = game.coverImageURL,
          contentDescription = null,
          contentScale = ContentScale.Crop,
          modifier = Modifier.fillMaxWidth().height(66.dp),
        )
      } else {
        Icon(
          game.status.iconName.vector,
          contentDescription = null,
          modifier = Modifier.size(24.dp),
          tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }

    Text(
      game.name,
      style = MaterialTheme.typography.bodySmall,
      maxLines = 2,
      overflow = TextOverflow.Ellipsis,
    )

    Text(
      PlaytimeFormatter.short(context, game.playtimeHours),
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}
