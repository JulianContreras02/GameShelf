package com.gameshelf.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import com.gameshelf.domain.Store
import kotlinx.coroutines.flow.Flow
import java.time.Instant
import java.util.UUID

@Dao
interface GameDao {

  @Transaction
  @Query("SELECT * FROM games ORDER BY name COLLATE NOCASE")
  fun observeAll(): Flow<List<GameWithRelations>>

  @Transaction
  @Query("SELECT * FROM games WHERE id = :id")
  fun observeById(id: UUID): Flow<GameWithRelations?>

  @Transaction
  @Query("SELECT * FROM games")
  suspend fun getAll(): List<GameWithRelations>

  @Transaction
  @Query("SELECT * FROM games WHERE id = :id")
  suspend fun getById(id: UUID): GameWithRelations?

  @Query("SELECT * FROM store_entries WHERE store = :store")
  suspend fun getEntries(store: Store): List<StoreEntryEntity>

  @Query("SELECT COUNT(*) FROM games")
  suspend fun count(): Int

  @Upsert
  suspend fun upsertGame(game: GameEntity)

  @Upsert
  suspend fun upsertGames(games: List<GameEntity>)

  @Upsert
  suspend fun upsertEntries(entries: List<StoreEntryEntity>)

  @Query("DELETE FROM store_entries WHERE game_id = :gameId AND store = :store")
  suspend fun deleteEntries(gameId: UUID, store: Store)

  @Delete
  suspend fun deleteGame(game: GameEntity)

  @Query("DELETE FROM games WHERE id = :id")
  suspend fun deleteGameById(id: UUID)

  // --- Campos personales -------------------------------------------------
  //
  // Van como updates de una sola columna y no reescribiendo el juego entero a
  // proposito: son los datos del usuario, y tocarlos por separado deja claro
  // que una sincronizacion nunca pasa por aca.

  @Query("UPDATE games SET status = :status WHERE id = :id")
  suspend fun updateStatus(id: UUID, status: com.gameshelf.domain.PlayStatus)

  @Query("UPDATE games SET notes = :notes WHERE id = :id")
  suspend fun updateNotes(id: UUID, notes: String)

  @Query("UPDATE games SET playtime_hours = :hours WHERE id = :id")
  suspend fun updatePlaytime(id: UUID, hours: Double)

  @Query("UPDATE store_entries SET wishlisted_at = NULL WHERE id = :entryId")
  suspend fun clearWishlisted(entryId: UUID)

  @Query("UPDATE store_entries SET last_synced_at = :at WHERE id = :entryId")
  suspend fun touchSynced(entryId: UUID, at: Instant)

  /**
   * Guarda un juego con sus entradas de tienda de una sola vez.
   *
   * Va en una transaccion porque un juego a medio escribir (sin sus entradas)
   * se veria en la biblioteca como un juego sin tienda ni horas.
   */
  @Transaction
  suspend fun upsertAggregate(game: GameEntity, entries: List<StoreEntryEntity>) {
    upsertGame(game)
    if (entries.isNotEmpty()) upsertEntries(entries)
  }
}

@Dao
interface CollectionDao {

  @Transaction
  @Query("SELECT * FROM collections ORDER BY sort_order, created_at")
  fun observeAll(): Flow<List<CollectionWithGames>>

  @Transaction
  @Query("SELECT * FROM collections WHERE id = :id")
  fun observeById(id: UUID): Flow<CollectionWithGames?>

  @Transaction
  @Query("SELECT * FROM collections ORDER BY sort_order, created_at")
  suspend fun getAll(): List<CollectionWithGames>

  @Query("SELECT COALESCE(MAX(sort_order), -1) FROM collections")
  suspend fun maxSortOrder(): Int

  @Upsert
  suspend fun upsert(collection: CollectionEntity)

  @Upsert
  suspend fun upsertAll(collections: List<CollectionEntity>)

  @Query("DELETE FROM collections WHERE id = :id")
  suspend fun deleteById(id: UUID)

  @Insert(onConflict = OnConflictStrategy.IGNORE)
  suspend fun link(ref: GameCollectionCrossRef)

  @Query("DELETE FROM game_collection_cross_ref WHERE game_id = :gameId AND collection_id = :collectionId")
  suspend fun unlink(gameId: UUID, collectionId: UUID)

  @Query("SELECT COUNT(*) FROM game_collection_cross_ref WHERE game_id = :gameId AND collection_id = :collectionId")
  suspend fun isLinked(gameId: UUID, collectionId: UUID): Int
}

@Dao
interface TagDao {

  @Transaction
  @Query("SELECT * FROM tags ORDER BY name COLLATE NOCASE")
  fun observeAll(): Flow<List<TagWithGames>>

  @Transaction
  @Query("SELECT * FROM tags ORDER BY name COLLATE NOCASE")
  suspend fun getAll(): List<TagWithGames>

  @Upsert
  suspend fun upsert(tag: TagEntity)

  @Query("DELETE FROM tags WHERE id = :id")
  suspend fun deleteById(id: UUID)

  /**
   * Borra las etiquetas que ya no usa ningun juego.
   *
   * Una etiqueta huerfana no la puede ver ni borrar el usuario desde ninguna
   * pantalla, asi que se limpia sola al quitarla del ultimo juego.
   */
  @Query("DELETE FROM tags WHERE id NOT IN (SELECT tag_id FROM game_tag_cross_ref)")
  suspend fun deleteOrphans(): Int

  @Insert(onConflict = OnConflictStrategy.IGNORE)
  suspend fun link(ref: GameTagCrossRef)

  @Query("DELETE FROM game_tag_cross_ref WHERE game_id = :gameId AND tag_id = :tagId")
  suspend fun unlink(gameId: UUID, tagId: UUID)
}
