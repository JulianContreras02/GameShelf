package com.gameshelf.ui.common

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import com.gameshelf.R

/**
 * El andamio de una seccion principal, con barra superior grande.
 *
 * La barra arranca alta y se encoge al bajar por la lista. Es el patron de
 * Material 3 para pantallas raiz y hace dos cosas a la vez: da un titular
 * legible al entrar y devuelve ese espacio al contenido en cuanto el usuario
 * empieza a leer.
 *
 * Se usa `exitUntilCollapsed` y no `enterAlways`: con este ultimo la barra
 * reaparece entera en cuanto se sube un pixel, que en una lista larga se siente
 * como si el titulo persiguiera al dedo.
 *
 * Solo lo usan las cuatro pestanas. Las pantallas a las que se entra desde
 * ellas llevan [PantallaDeDetalle], que tiene barra pequena: repetir el titular
 * grande en cada nivel haria que toda la app se viera igual de importante.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PantallaPrincipal(
  titulo: String,
  modifier: Modifier = Modifier,
  navegacion: @Composable () -> Unit = {},
  acciones: @Composable RowScope.() -> Unit = {},
  accionFlotante: @Composable () -> Unit = {},
  contenido: @Composable (PaddingValues) -> Unit,
) {
  val comportamiento = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(
    rememberTopAppBarState(),
  )

  Scaffold(
    modifier = modifier.nestedScroll(comportamiento.nestedScrollConnection),
    topBar = {
      LargeTopAppBar(
        title = { Text(titulo, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        navigationIcon = navegacion,
        actions = acciones,
        scrollBehavior = comportamiento,
      )
    },
    floatingActionButton = accionFlotante,
    content = contenido,
  )
}

/**
 * El andamio de una pantalla a la que se entra desde otra.
 *
 * Barra pequena con la flecha de volver. La barra tambien se encoge al bajar,
 * pero desde una altura normal: aca el titulo ya se sabe porque el usuario
 * acaba de tocar la fila que lleva a esta pantalla.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PantallaDeDetalle(
  titulo: String,
  alVolver: () -> Unit,
  modifier: Modifier = Modifier,
  acciones: @Composable RowScope.() -> Unit = {},
  contenido: @Composable (PaddingValues) -> Unit,
) {
  val comportamiento = TopAppBarDefaults.enterAlwaysScrollBehavior(rememberTopAppBarState())

  Scaffold(
    modifier = modifier.nestedScroll(comportamiento.nestedScrollConnection),
    topBar = {
      TopAppBar(
        title = { Text(titulo, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        navigationIcon = {
          IconButton(onClick = alVolver) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.action_back),
            )
          }
        },
        actions = acciones,
        scrollBehavior = comportamiento,
      )
    },
    content = contenido,
  )
}
