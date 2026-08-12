package com.gameshelf.data.repository

import com.gameshelf.data.local.GameCollectionCrossRef
import com.gameshelf.data.local.GameShelfDatabase
import com.gameshelf.data.local.GameTagCrossRef
import com.gameshelf.data.local.toDomain
import com.gameshelf.data.local.toEntity
import com.gameshelf.domain.Game
import com.gameshelf.domain.GameCollection
import com.gameshelf.domain.GameTag
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.StoreEntry
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.UUID

/**
 * La puerta de entrada a los datos guardados.
 *
 * Es el papel que en iOS hacia `ModelContext`: los ViewModels y los
 * sincronizadores hablan con esto y no con Room. Tenerlo detras de una capa
 * propia es lo que permite que los sincronizadores se prueben sin base de
 * datos, pasandoles una implementacion falsa.
 */
interface GameStore {
  fun observeGames(): Flow<List<Game>>
  fun observeGame(id: UUID): Flow<Game?>
  suspend fun allGames(): List<Game>
  suspend fun game(id: UUID): Game?
  suspend fun gameCount(): Int

  /** Guarda el juego y sus entradas de tienda de una sola vez. */
  suspend fun save(game: Game)

  suspend fun saveAll(games: List<Game>)
  suspend fun delete(id: UUID)

  // Campos personales. Van sueltos para dejar claro que ninguna
  // sincronizacion pasa por aca.
  suspend fun setStatus(id: UUID, status: PlayStatus)
  suspend fun setNotes(id: UUID, notes: String)

  suspend fun entries(store: Store): List<StoreEntry>
  suspend fun clearWishlisted(entryId: UUID)

  // Colecciones
  fun observeCollections(): Flow<List<GameCollection>>
  fun observeCollection(id: UUID): Flow<GameCollection?>
  suspend fun allCollections(): List<GameCollection>
  suspend fun saveCollection(collection: GameCollection)
  suspend fun saveCollections(collections: List<GameCollection>)
  suspend fun deleteCollection(id: UUID)
  suspend fun nextCollectionSortOrder(): Int
  suspend fun link(gameId: UUID, collectionId: UUID)
  suspend fun unlink(gameId: UUID, collectionId: UUID)

  // Etiquetas
  fun observeTags(): Flow<List<GameTag>>
  suspend fun allTags(): List<GameTag>
  suspend fun saveTag(tag: GameTag)
  suspend fun deleteTag(id: UUID)
  suspend fun linkTag(gameId: UUID, tagId: UUID)
  suspend fun unlinkTag(gameId: UUID, tagId: UUID)
  suspend fun deleteOrphanTags()
}

/** Implementacion sobre Room. */
class GameRepository(private val db: GameShelfDatabase) : GameStore {

  private val games = db.gameDao()
  private val collections = db.collectionDao()
  private val tags = db.tagDao()

  override fun observeGames(): Flow<List<Game>> =
    games.observeAll().map { filas -> filas.map { it.toDomain() } }

  override fun observeGame(id: UUID): Flow<Game?> =
    games.observeById(id).map { it?.toDomain() }

  override suspend fun allGames(): List<Game> = games.getAll().map { it.toDomain() }

  override suspend fun game(id: UUID): Game? = games.getById(id)?.toDomain()

  override suspend fun gameCount(): Int = games.count()

  override suspend fun save(game: Game) {
    games.upsertAggregate(
      game = game.toEntity(),
      entries = game.storeEntries.map { it.toEntity(game.id) },
    )
  }

  override suspend fun saveAll(games: List<Game>) {
    // Se escribe juego a juego y no en un solo lote porque cada uno arrastra
    // sus entradas: el agregado es la unidad que tiene que quedar coherente.
    games.forEach { save(it) }
  }

  override suspend fun delete(id: UUID) = games.deleteGameById(id)

  override suspend fun setStatus(id: UUID, status: PlayStatus) = games.updateStatus(id, status)

  override suspend fun setNotes(id: UUID, notes: String) = games.updateNotes(id, notes)

  override suspend fun entries(store: Store): List<StoreEntry> =
    games.getEntries(store).map { it.toDomain() }

  override suspend fun clearWishlisted(entryId: UUID) = games.clearWishlisted(entryId)

  override fun observeCollections(): Flow<List<GameCollection>> =
    collections.observeAll().map { filas -> filas.map { it.toDomain() } }

  override fun observeCollection(id: UUID): Flow<GameCollection?> =
    collections.observeById(id).map { it?.toDomain() }

  override suspend fun allCollections(): List<GameCollection> =
    collections.getAll().map { it.toDomain() }

  override suspend fun saveCollection(collection: GameCollection) =
    collections.upsert(collection.toEntity())

  override suspend fun saveCollections(collections: List<GameCollection>) =
    this.collections.upsertAll(collections.map { it.toEntity() })

  override suspend fun deleteCollection(id: UUID) = collections.deleteById(id)

  override suspend fun nextCollectionSortOrder(): Int = collections.maxSortOrder() + 1

  override suspend fun link(gameId: UUID, collectionId: UUID) =
    collections.link(GameCollectionCrossRef(gameId, collectionId))

  override suspend fun unlink(gameId: UUID, collectionId: UUID) =
    collections.unlink(gameId, collectionId)

  override fun observeTags(): Flow<List<GameTag>> =
    tags.observeAll().map { filas -> filas.map { it.toDomain() } }

  override suspend fun allTags(): List<GameTag> = tags.getAll().map { it.toDomain() }

  override suspend fun saveTag(tag: GameTag) = tags.upsert(tag.toEntity())

  override suspend fun deleteTag(id: UUID) = tags.deleteById(id)

  override suspend fun linkTag(gameId: UUID, tagId: UUID) =
    tags.link(GameTagCrossRef(gameId, tagId))

  override suspend fun unlinkTag(gameId: UUID, tagId: UUID) = tags.unlink(gameId, tagId)

  override suspend fun deleteOrphanTags() {
    tags.deleteOrphans()
  }
}
