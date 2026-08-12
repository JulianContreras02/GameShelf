package com.gameshelf.data.sync

import com.gameshelf.domain.Game
import com.gameshelf.domain.Store
import com.gameshelf.domain.normalizedForSearch

/**
 * Encuentra si un juego que llega de una tienda ya esta guardado.
 *
 * Es la deduplicacion que hace que tener varias tiendas sirva de algo: si Red
 * Dead Redemption 2 esta en Steam y en PlayStation, la biblioteca muestra
 * **un** juego con las horas de los dos, no dos filas repetidas.
 *
 * Vive aparte porque la usan los tres conectores. Estaba escrita dentro del
 * sincronizador de PSN y copiarla para Epic habria sido la tercera version de
 * la misma idea.
 *
 * Se indexa en memoria a partir de los juegos ya cargados, igual que en iOS:
 * es mas rapido que una consulta por juego.
 */
class LibraryMatcher(private val store: Store, juegos: List<Game>) {

  /** Juegos que ya tienen una entrada de esta tienda, por su id de tienda. */
  private val porIDDeTienda: MutableMap<String, Game> = buildMap {
    juegos.forEach { juego ->
      juego.storeEntries.filter { it.store == store }.forEach { entrada ->
        // Si hubiera duplicados por un fallo previo, gana el primero: asi no
        // se crean todavia mas copias.
        putIfAbsent(entrada.storeGameID, juego)
      }
    }
  }.toMutableMap()

  /** Todos los juegos guardados, por su nombre normalizado. */
  private val porNombre: MutableMap<String, Game> = buildMap {
    juegos.forEach { juego -> putIfAbsent(juego.name.normalizedForSearch, juego) }
  }.toMutableMap()

  /** Como se reconocio un juego que llega. */
  sealed interface Coincidencia {
    /** Ya estaba, y con esta misma tienda. */
    data class MismaTienda(val juego: Game) : Coincidencia

    /** Ya estaba, pero venido de otra tienda. Hay que sumarle esta. */
    data class OtraTienda(val juego: Game) : Coincidencia

    /** No estaba: hay que crearlo. */
    data object Nuevo : Coincidencia
  }

  /**
   * Busca un juego por su id de tienda y, si no, por su nombre.
   *
   * La comparacion por nombre ignora mayusculas y tildes, la misma regla que
   * usan la busqueda y las etiquetas.
   */
  fun buscar(storeGameID: String, nombre: String): Coincidencia {
    porIDDeTienda[storeGameID]?.let { return Coincidencia.MismaTienda(it) }
    porNombre[nombre.normalizedForSearch]?.let { return Coincidencia.OtraTienda(it) }
    return Coincidencia.Nuevo
  }

  /**
   * Registra un juego, para que el siguiente de la misma tanda lo encuentre en
   * vez de crear otro igual.
   *
   * Se llama tanto al crear uno nuevo como al actualizar uno existente, y esa
   * segunda parte es obligatoria aca aunque en iOS no lo fuera. Alla el mapper
   * mutaba el objeto guardado, asi que el indice ya apuntaba a la version
   * fresca; aca devuelve una copia, y sin re-indexarla el siguiente juego de
   * la misma tanda trabajaria sobre la version vieja y perderia lo anterior.
   * Pasa de verdad: PSN lista el mismo juego dos veces cuando existe en
   * consola y en PC.
   */
  fun registrar(juego: Game) {
    porNombre[juego.name.normalizedForSearch] = juego
    juego.storeEntries.filter { it.store == store }.forEach { entrada ->
      porIDDeTienda[entrada.storeGameID] = juego
    }
  }
}
