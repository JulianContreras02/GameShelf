package com.gameshelf

import com.gameshelf.data.repository.GameStore
import com.gameshelf.domain.Game
import com.gameshelf.domain.GameCollection
import com.gameshelf.domain.GameTag
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.StoreEntry
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import java.util.UUID

/**
 * Un almacen en memoria, para probar los sincronizadores sin base de datos.
 *
 * En iOS esto no hacia falta porque los tests levantaban un `ModelContainer`
 * en memoria. Room tambien lo permite, pero necesita Android; con esto los
 * sincronizadores se prueban en la JVM, que es donde tienen que estar los
 * tests de logica.
 */
class FakeGameStore(iniciales: List<Game> = emptyList()) : GameStore {

  private val juegos = MutableStateFlow(iniciales.associateBy { it.id })
  private val colecciones = MutableStateFlow(emptyMap<UUID, GameCollection>())
  private val etiquetas = MutableStateFlow(emptyMap<UUID, GameTag>())
  private val enlacesDeColeccion = mutableSetOf<Pair<UUID, UUID>>()
  private val enlacesDeEtiqueta = mutableSetOf<Pair<UUID, UUID>>()

  /** Cuantas veces se escribio. Sirve para comprobar que un sync no reescribe de mas. */
  var escrituras = 0
    private set

  override fun observeGames(): Flow<List<Game>> = juegos.map { it.values.toList() }

  override fun observeGame(id: UUID): Flow<Game?> = juegos.map { it[id] }

  override suspend fun allGames(): List<Game> = juegos.value.values.toList()

  override suspend fun game(id: UUID): Game? = juegos.value[id]

  override suspend fun gameCount(): Int = juegos.value.size

  override suspend fun save(game: Game) {
    escrituras++
    juegos.value = juegos.value + (game.id to game)
  }

  override suspend fun saveAll(games: List<Game>) = games.forEach { save(it) }

  override suspend fun delete(id: UUID) {
    juegos.value = juegos.value - id
  }

  override suspend fun setStatus(id: UUID, status: PlayStatus) {
    juegos.value[id]?.let { save(it.copy(status = status)) }
  }

  override suspend fun setNotes(id: UUID, notes: String) {
    juegos.value[id]?.let { save(it.copy(notes = notes)) }
  }

  override suspend fun entries(store: Store): List<StoreEntry> =
    juegos.value.values.flatMap { juego -> juego.storeEntries.filter { it.store == store } }

  override suspend fun clearWishlisted(entryId: UUID) {
    val juego = juegos.value.values.firstOrNull { j -> j.storeEntries.any { it.id == entryId } }
      ?: return

    save(
      juego.copy(
        storeEntries = juego.storeEntries.map {
          if (it.id == entryId) it.copy(wishlistedAt = null) else it
        },
      ),
    )
  }

  override fun observeCollections(): Flow<List<GameCollection>> =
    colecciones.map { it.values.sortedBy { c -> c.sortOrder } }

  override fun observeCollection(id: UUID): Flow<GameCollection?> = colecciones.map { it[id] }

  override suspend fun allCollections(): List<GameCollection> =
    colecciones.value.values.sortedBy { it.sortOrder }

  override suspend fun saveCollection(collection: GameCollection) {
    colecciones.value = colecciones.value + (collection.id to collection)
  }

  override suspend fun saveCollections(collections: List<GameCollection>) =
    collections.forEach { saveCollection(it) }

  override suspend fun deleteCollection(id: UUID) {
    colecciones.value = colecciones.value - id
    enlacesDeColeccion.removeAll { it.second == id }
  }

  override suspend fun nextCollectionSortOrder(): Int =
    (colecciones.value.values.maxOfOrNull { it.sortOrder } ?: -1) + 1

  override suspend fun link(gameId: UUID, collectionId: UUID) {
    enlacesDeColeccion += gameId to collectionId
  }

  override suspend fun unlink(gameId: UUID, collectionId: UUID) {
    enlacesDeColeccion -= gameId to collectionId
  }

  override fun observeTags(): Flow<List<GameTag>> = etiquetas.map { it.values.toList() }

  override suspend fun allTags(): List<GameTag> = etiquetas.value.values.toList()

  override suspend fun saveTag(tag: GameTag) {
    etiquetas.value = etiquetas.value + (tag.id to tag)
  }

  override suspend fun deleteTag(id: UUID) {
    etiquetas.value = etiquetas.value - id
    enlacesDeEtiqueta.removeAll { it.second == id }
  }

  override suspend fun linkTag(gameId: UUID, tagId: UUID) {
    enlacesDeEtiqueta += gameId to tagId
  }

  override suspend fun unlinkTag(gameId: UUID, tagId: UUID) {
    enlacesDeEtiqueta -= gameId to tagId
  }

  override suspend fun deleteOrphanTags() {
    val usadas = enlacesDeEtiqueta.map { it.second }.toSet()
    etiquetas.value = etiquetas.value.filterKeys { it in usadas }
  }

  /** Si un juego esta en una coleccion, para las comprobaciones de los tests. */
  fun estaEnColeccion(gameId: UUID, collectionId: UUID): Boolean =
    (gameId to collectionId) in enlacesDeColeccion
}
