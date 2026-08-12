package com.gameshelf.ui.accounts

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.gameshelf.LocalAppContainer
import com.gameshelf.R
import com.gameshelf.data.epic.EpicAuthService
import com.gameshelf.data.psn.PSNAuthService
import com.gameshelf.ui.common.AvisoDeFallo
import com.gameshelf.ui.common.userMessage
import com.gameshelf.ui.common.userRecovery

/**
 * Conectar la cuenta de PlayStation.
 *
 * El rodeo es de Sony, no de la app: no hay un "iniciar sesion" para
 * aplicaciones de terceros, solo copiar un codigo desde el navegador con la
 * sesion ya iniciada. Por eso la pantalla ofrece los dos enlaces **en orden**:
 * sin el primero, el segundo responde un error que parece de direccion mala
 * cuando en realidad falta iniciar sesion.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PSNConnectScreen(alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: PSNAccountViewModel = viewModel(factory = container.viewModelFactory)
  val contexto = LocalContext.current

  val estado by vm.state.collectAsStateWithLifecycle()
  val estadoBiblioteca by vm.libraryState.collectAsStateWithLifecycle()
  val reconectarEn by vm.reconnectBy.collectAsStateWithLifecycle()

  var codigo by remember { mutableStateOf("") }

  PantallaDeConexion(
    titulo = stringResource(R.string.settings_playstation),
    alVolver = alVolver,
    pasos = listOf(
      Paso(stringResource(R.string.psn_step_1), PSNAuthService.SIGN_IN_URL),
      Paso(stringResource(R.string.psn_step_2), PSNAuthService.NPSSO_URL),
      Paso(stringResource(R.string.psn_step_3), null),
    ),
    aviso = stringResource(R.string.psn_token_lifetime),
    etiquetaDelCampo = stringResource(R.string.psn_code_label),
    codigo = codigo,
    alCambiarCodigo = { codigo = it },
    trabajando = estado.isWorking,
    conectado = estado.isConnected,
    detalleConectado = reconectarEn?.let {
      stringResource(R.string.account_reconnect_by, it.toString())
    },
    mensajeDeError = when (estado) {
      is PSNAccountViewModel.State.NecesitaTokenNuevo ->
        (estado as PSNAccountViewModel.State.NecesitaTokenNuevo).error
      is PSNAccountViewModel.State.Fallo ->
        (estado as PSNAccountViewModel.State.Fallo).error
      else -> null
    },
    sincronizando = estadoBiblioteca.isSyncing,
    resultadoDeSync = (estadoBiblioteca as? PSNAccountViewModel.LibraryState.Succeeded)?.let {
      stringResource(R.string.account_sync_result, it.created, it.updated, it.merged)
    },
    alConectar = { vm.connect(codigo) },
    alDesconectar = vm::disconnect,
    alSincronizar = vm::syncLibrary,
  )
}

/**
 * Conectar la cuenta de Epic.
 *
 * Lleva la advertencia de la propia pagina de Epic: ese codigo **da acceso
 * completo a la cuenta**. Aca se guarda cifrado y no se manda a ningun
 * servidor, pero el usuario merece saberlo antes de pegarlo.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EpicConnectScreen(alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: EpicAccountViewModel = viewModel(factory = container.viewModelFactory)

  val estado by vm.state.collectAsStateWithLifecycle()
  val estadoBiblioteca by vm.libraryState.collectAsStateWithLifecycle()
  val nombre by vm.displayName.collectAsStateWithLifecycle()

  var codigo by remember { mutableStateOf("") }

  PantallaDeConexion(
    titulo = stringResource(R.string.settings_epic),
    alVolver = alVolver,
    pasos = listOf(
      Paso(stringResource(R.string.epic_step_1), EpicAuthService.LOGIN_URL),
      Paso(stringResource(R.string.epic_step_2), EpicAuthService.CODE_URL),
      Paso(stringResource(R.string.epic_step_3), null),
    ),
    aviso = stringResource(R.string.epic_warning),
    etiquetaDelCampo = stringResource(R.string.epic_code_label),
    codigo = codigo,
    alCambiarCodigo = { codigo = it },
    trabajando = estado.isWorking,
    conectado = estado.isConnected,
    detalleConectado = nombre,
    mensajeDeError = when (estado) {
      is EpicAccountViewModel.State.NecesitaCodigoNuevo ->
        (estado as EpicAccountViewModel.State.NecesitaCodigoNuevo).error
      is EpicAccountViewModel.State.Fallo ->
        (estado as EpicAccountViewModel.State.Fallo).error
      else -> null
    },
    sincronizando = estadoBiblioteca.isSyncing,
    resultadoDeSync = (estadoBiblioteca as? EpicAccountViewModel.LibraryState.Succeeded)?.let {
      stringResource(R.string.account_sync_result, it.created, it.updated, it.merged)
    },
    alConectar = { vm.connect(codigo) },
    alDesconectar = vm::disconnect,
    alSincronizar = vm::syncLibrary,
  )
}

/** Un paso de las instrucciones, con su enlace si lo tiene. */
private data class Paso(val texto: String, val url: String?)

/**
 * La forma que comparten las dos pantallas de conexion.
 *
 * PSN y Epic piden lo mismo (abrir un enlace, copiar un codigo, pegarlo) y
 * fallan de la misma manera. Tener una sola pantalla evita que arreglar algo
 * en una deje la otra a medias.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PantallaDeConexion(
  titulo: String,
  alVolver: () -> Unit,
  pasos: List<Paso>,
  aviso: String,
  etiquetaDelCampo: String,
  codigo: String,
  alCambiarCodigo: (String) -> Unit,
  trabajando: Boolean,
  conectado: Boolean,
  detalleConectado: String?,
  mensajeDeError: Throwable?,
  sincronizando: Boolean,
  resultadoDeSync: String?,
  alConectar: () -> Unit,
  alDesconectar: () -> Unit,
  alSincronizar: () -> Unit,
) {
  val contexto = LocalContext.current

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(titulo) },
        navigationIcon = {
          IconButton(onClick = alVolver) {
            Icon(
              Icons.AutoMirrored.Filled.ArrowBack,
              contentDescription = stringResource(R.string.action_back),
            )
          }
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
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      if (mensajeDeError != null) {
        AvisoDeFallo(
          mensaje = mensajeDeError.userMessage(contexto, R.string.error_sync_generic),
          sugerencia = mensajeDeError.userRecovery(contexto),
        )
      }

      if (conectado) {
        Card {
          Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
              stringResource(R.string.settings_connected),
              style = MaterialTheme.typography.titleMedium,
            )
            detalleConectado?.let {
              Text(
                it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
              )
            }
            resultadoDeSync?.let { Text(it, style = MaterialTheme.typography.bodySmall) }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
              Button(onClick = alSincronizar, enabled = !sincronizando) {
                if (sincronizando) {
                  CircularProgressIndicator(Modifier.size(18.dp))
                } else {
                  Text(stringResource(R.string.action_sync_library))
                }
              }
              TextButton(onClick = alDesconectar) {
                Text(stringResource(R.string.action_disconnect))
              }
            }
          }
        }
      }

      Text(stringResource(R.string.account_how_to), style = MaterialTheme.typography.titleMedium)

      pasos.forEachIndexed { indice, paso ->
        Row(
          Modifier.fillMaxWidth(),
          horizontalArrangement = Arrangement.spacedBy(8.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text("${indice + 1}.", style = MaterialTheme.typography.bodyMedium)
          Text(paso.texto, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)

          if (paso.url != null) {
            IconButton(onClick = {
              contexto.startActivity(Intent(Intent.ACTION_VIEW, paso.url.toUri()))
            }) {
              Icon(
                Icons.AutoMirrored.Filled.OpenInNew,
                contentDescription = stringResource(R.string.action_open_link),
              )
            }
          }
        }
      }

      Card {
        Text(
          aviso,
          Modifier.padding(16.dp),
          style = MaterialTheme.typography.bodySmall,
        )
      }

      OutlinedTextField(
        value = codigo,
        onValueChange = alCambiarCodigo,
        modifier = Modifier.fillMaxWidth(),
        label = { Text(etiquetaDelCampo) },
        singleLine = true,
      )

      Button(
        onClick = alConectar,
        enabled = codigo.isNotBlank() && !trabajando,
        modifier = Modifier.fillMaxWidth(),
      ) {
        if (trabajando) {
          CircularProgressIndicator(Modifier.size(18.dp))
        } else {
          Text(stringResource(R.string.action_connect))
        }
      }
    }
  }
}
