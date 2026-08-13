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
import com.gameshelf.data.itad.ITADService
import com.gameshelf.data.psn.PSNAuthService
import com.gameshelf.data.steam.SteamAuthService
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
    campos = listOf(
      Campo(stringResource(R.string.psn_code_label), codigo) { codigo = it },
    ),
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
    campos = listOf(
      Campo(stringResource(R.string.epic_code_label), codigo) { codigo = it },
    ),
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

/**
 * Conectar la cuenta de Steam.
 *
 * Es la unica de las tres que pide dos cosas, y conviene saber por que. Steam
 * **no tiene OAuth para su Web API**: la clave se genera a mano en su web y no
 * hay ningun flujo por el que una app de terceros la consiga sola. El SteamID,
 * en cambio, si se deduce: basta con la URL del perfil, que es lo que el
 * usuario tiene a la vista, y la app la traduce al numero que la API pide.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SteamConnectScreen(alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: SteamAccountViewModel = viewModel(factory = container.viewModelFactory)

  val estado by vm.state.collectAsStateWithLifecycle()
  val estadoBiblioteca by vm.libraryState.collectAsStateWithLifecycle()
  val nombre by vm.personaName.collectAsStateWithLifecycle()

  var clave by remember { mutableStateOf("") }
  var perfil by remember { mutableStateOf("") }

  PantallaDeConexion(
    titulo = stringResource(R.string.settings_steam),
    alVolver = alVolver,
    pasos = listOf(
      Paso(stringResource(R.string.steam_step_1), SteamAuthService.API_KEY_URL),
      Paso(stringResource(R.string.steam_step_2), SteamAuthService.PROFILE_URL),
      Paso(stringResource(R.string.steam_step_3), null),
    ),
    aviso = stringResource(R.string.steam_key_notice),
    campos = listOf(
      Campo(stringResource(R.string.steam_key_label), clave) { clave = it },
      Campo(stringResource(R.string.steam_profile_label), perfil) { perfil = it },
    ),
    trabajando = estado.isWorking,
    conectado = estado.isConnected,
    detalleConectado = nombre,
    mensajeDeError = (estado as? SteamAccountViewModel.State.Fallo)?.error,
    sincronizando = estadoBiblioteca.isSyncing,
    resultadoDeSync = (estadoBiblioteca as? SteamAccountViewModel.LibraryState.Succeeded)?.let {
      stringResource(R.string.account_sync_result_steam, it.created, it.updated)
    },
    alConectar = { vm.connect(clave, perfil) },
    alDesconectar = vm::disconnect,
    alSincronizar = vm::syncLibrary,
  )
}

/**
 * Guardar la clave de IsThereAnyDeal, que habilita los precios.
 *
 * Reusa la misma pantalla aunque no sea una cuenta: la forma es identica (abrir
 * un enlace, copiar algo, pegarlo) y no hay biblioteca que sincronizar, asi que
 * el boton de sincronizar se oculta.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ITADKeyScreen(alVolver: () -> Unit) {
  val container = LocalAppContainer.current
  val vm: ITADKeyViewModel = viewModel(factory = container.viewModelFactory)

  val guardada by vm.hasKey.collectAsStateWithLifecycle()
  var clave by remember { mutableStateOf("") }

  PantallaDeConexion(
    titulo = stringResource(R.string.settings_prices),
    alVolver = alVolver,
    pasos = listOf(
      Paso(stringResource(R.string.itad_step_1), ITADService.API_KEY_URL),
      Paso(stringResource(R.string.itad_step_2), null),
    ),
    tituloDeLosPasos = stringResource(R.string.itad_how_to),
    aviso = stringResource(R.string.itad_optional_notice),
    campos = listOf(
      Campo(stringResource(R.string.itad_key_label), clave) { clave = it },
    ),
    trabajando = false,
    conectado = guardada,
    detalleConectado = stringResource(R.string.itad_prices_enabled),
    mensajeDeError = null,
    alConectar = {
      vm.save(clave)
      clave = ""
    },
    alDesconectar = vm::clear,
  )
}

/** Un paso de las instrucciones, con su enlace si lo tiene. */
private data class Paso(val texto: String, val url: String?)

/**
 * Un campo que el usuario tiene que llenar.
 *
 * Es una lista y no un solo campo porque Steam pide dos cosas (la clave y el
 * perfil) mientras que PSN y Epic piden una. Modelarlo como lista deja una sola
 * pantalla para las cuatro conexiones en vez de una variante por cada forma.
 */
private data class Campo(
  val etiqueta: String,
  val valor: String,
  val alCambiar: (String) -> Unit,
)

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
  /** Encabezado de los pasos. Se cambia donde no se conecta una cuenta. */
  tituloDeLosPasos: String = stringResource(R.string.account_how_to),
  aviso: String,
  campos: List<Campo>,
  trabajando: Boolean,
  conectado: Boolean,
  detalleConectado: String?,
  mensajeDeError: Throwable?,
  sincronizando: Boolean = false,
  resultadoDeSync: String? = null,
  alConectar: () -> Unit,
  alDesconectar: () -> Unit,
  /** `null` en las conexiones que no traen biblioteca, como la de precios. */
  alSincronizar: (() -> Unit)? = null,
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
              if (alSincronizar != null) {
                Button(onClick = alSincronizar, enabled = !sincronizando) {
                  if (sincronizando) {
                    CircularProgressIndicator(Modifier.size(18.dp))
                  } else {
                    Text(stringResource(R.string.action_sync_library))
                  }
                }
              }
              TextButton(onClick = alDesconectar) {
                Text(stringResource(R.string.action_disconnect))
              }
            }
          }
        }
      }

      Text(tituloDeLosPasos, style = MaterialTheme.typography.titleMedium)

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

      campos.forEach { campo ->
        OutlinedTextField(
          value = campo.valor,
          onValueChange = campo.alCambiar,
          modifier = Modifier.fillMaxWidth(),
          label = { Text(campo.etiqueta) },
          singleLine = true,
        )
      }

      Button(
        onClick = alConectar,
        enabled = campos.all { it.valor.isNotBlank() } && !trabajando,
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
