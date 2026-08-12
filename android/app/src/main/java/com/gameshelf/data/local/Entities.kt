package com.gameshelf.data.local

import androidx.room.ColumnInfo
import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Junction
import androidx.room.PrimaryKey
import androidx.room.Relation
import com.gameshelf.domain.CollectionColor
import com.gameshelf.domain.CollectionSymbol
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.TrophyCounts
import java.time.Instant
import java.util.UUID

/**
 * Tablas de la base local.
 *
 * Estan separadas de los tipos de dominio a proposito. En iOS, SwiftData
 * anotaba las clases del modelo directamente; aca eso obligaria a que el
 * dominio importara Room y a que las pruebas de logica pura levantaran
 * Android. Los mappers de `EntityMapping.kt` hacen la traduccion.
 */

@Entity(tableName = "games")
data class GameEntity(
  @PrimaryKey val id: UUID,
  val name: String,
  @ColumnInfo(name = "cover_image_url") val coverImageURL: String?,
  @ColumnInfo(name = "release_date") val releaseDate: Instant?,
  @ColumnInfo(name = "playtime_hours") val playtimeHours: Double,
  val notes: String,
  val status: PlayStatus,
  @ColumnInfo(name = "added_at") val addedAt: Instant,
)

/**
 * Entrada de tienda.
 *
 * El borrado en cascada replica la regla `.cascade` de SwiftData: si se borra
 * el juego, sus entradas se van con el porque no tienen sentido por separado.
 */
@Entity(
  tableName = "store_entries",
  foreignKeys = [
    ForeignKey(
      entity = GameEntity::class,
      parentColumns = ["id"],
      childColumns = ["game_id"],
      onDelete = ForeignKey.CASCADE,
    ),
  ],
  indices = [
    Index("game_id"),
    // La sincronizacion busca por tienda + id de tienda en cada juego que
    // llega: sin este indice cada tanda seria un recorrido completo de tabla.
    Index("store", "store_game_id"),
  ],
)
data class StoreEntryEntity(
  @PrimaryKey val id: UUID,
  @ColumnInfo(name = "game_id") val gameId: UUID,
  val store: Store,
  @ColumnInfo(name = "store_game_id") val storeGameID: String,
  @ColumnInfo(name = "store_url") val storeURL: String?,
  @ColumnInfo(name = "playtime_hours") val playtimeHours: Double,
  @ColumnInfo(name = "recent_playtime_hours") val recentPlaytimeHours: Double,
  @ColumnInfo(name = "last_played_at") val lastPlayedAt: Instant?,
  @ColumnInfo(name = "wishlisted_at") val wishlistedAt: Instant?,
  @ColumnInfo(name = "trophy_progress") val trophyProgress: Int?,
  @ColumnInfo(name = "launch_count") val launchCount: Int?,
  @ColumnInfo(name = "earned_trophies") val earnedTrophies: TrophyCounts?,
  @ColumnInfo(name = "defined_trophies") val definedTrophies: TrophyCounts?,
  @ColumnInfo(name = "coming_soon") val comingSoon: Boolean,
  @ColumnInfo(name = "last_synced_at") val lastSyncedAt: Instant?,
)

@Entity(tableName = "collections")
data class CollectionEntity(
  @PrimaryKey val id: UUID,
  val name: String,
  val symbol: CollectionSymbol,
  val color: CollectionColor,
  @ColumnInfo(name = "sort_order") val sortOrder: Int,
  @ColumnInfo(name = "created_at") val createdAt: Instant,
)

@Entity(tableName = "tags")
data class TagEntity(
  @PrimaryKey val id: UUID,
  val name: String,
  @ColumnInfo(name = "created_at") val createdAt: Instant,
)

/**
 * Tabla puente juego <-> coleccion.
 *
 * El cascade va sobre las filas de esta tabla, nunca sobre los juegos ni sobre
 * las colecciones: borrar una coleccion deshace la agrupacion y deja los
 * juegos intactos, que es la regla `nullify` que traia SwiftData.
 */
@Entity(
  tableName = "game_collection_cross_ref",
  primaryKeys = ["game_id", "collection_id"],
  foreignKeys = [
    ForeignKey(
      entity = GameEntity::class,
      parentColumns = ["id"],
      childColumns = ["game_id"],
      onDelete = ForeignKey.CASCADE,
    ),
    ForeignKey(
      entity = CollectionEntity::class,
      parentColumns = ["id"],
      childColumns = ["collection_id"],
      onDelete = ForeignKey.CASCADE,
    ),
  ],
  indices = [Index("collection_id")],
)
data class GameCollectionCrossRef(
  @ColumnInfo(name = "game_id") val gameId: UUID,
  @ColumnInfo(name = "collection_id") val collectionId: UUID,
)

/** Tabla puente juego <-> etiqueta. Mismas reglas que la de colecciones. */
@Entity(
  tableName = "game_tag_cross_ref",
  primaryKeys = ["game_id", "tag_id"],
  foreignKeys = [
    ForeignKey(
      entity = GameEntity::class,
      parentColumns = ["id"],
      childColumns = ["game_id"],
      onDelete = ForeignKey.CASCADE,
    ),
    ForeignKey(
      entity = TagEntity::class,
      parentColumns = ["id"],
      childColumns = ["tag_id"],
      onDelete = ForeignKey.CASCADE,
    ),
  ],
  indices = [Index("tag_id")],
)
data class GameTagCrossRef(
  @ColumnInfo(name = "game_id") val gameId: UUID,
  @ColumnInfo(name = "tag_id") val tagId: UUID,
)

/**
 * Un juego con todo lo que cuelga de el.
 *
 * Es lo que Room sabe rellenar de una consulta y lo que el mapper convierte en
 * el `Game` de dominio.
 */
data class GameWithRelations(
  @Embedded val game: GameEntity,

  @Relation(parentColumn = "id", entityColumn = "game_id")
  val storeEntries: List<StoreEntryEntity>,

  @Relation(
    parentColumn = "id",
    entityColumn = "id",
    associateBy = Junction(
      value = GameCollectionCrossRef::class,
      parentColumn = "game_id",
      entityColumn = "collection_id",
    ),
  )
  val collections: List<CollectionEntity>,

  @Relation(
    parentColumn = "id",
    entityColumn = "id",
    associateBy = Junction(
      value = GameTagCrossRef::class,
      parentColumn = "game_id",
      entityColumn = "tag_id",
    ),
  )
  val tags: List<TagEntity>,
)

/** Una coleccion con sus juegos, para la pantalla de detalle. */
data class CollectionWithGames(
  @Embedded val collection: CollectionEntity,

  @Relation(
    parentColumn = "id",
    entityColumn = "id",
    entity = GameEntity::class,
    associateBy = Junction(
      value = GameCollectionCrossRef::class,
      parentColumn = "collection_id",
      entityColumn = "game_id",
    ),
  )
  val games: List<GameWithRelations>,
)

/** Una etiqueta con sus juegos. */
data class TagWithGames(
  @Embedded val tag: TagEntity,

  @Relation(
    parentColumn = "id",
    entityColumn = "id",
    entity = GameEntity::class,
    associateBy = Junction(
      value = GameTagCrossRef::class,
      parentColumn = "tag_id",
      entityColumn = "game_id",
    ),
  )
  val games: List<GameWithRelations>,
)
