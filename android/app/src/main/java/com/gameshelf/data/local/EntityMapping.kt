package com.gameshelf.data.local

import com.gameshelf.domain.Game
import com.gameshelf.domain.GameCollection
import com.gameshelf.domain.GameTag
import com.gameshelf.domain.StoreEntry
import java.util.UUID

/**
 * Traduccion entre las filas de Room y los tipos de dominio.
 *
 * Las colecciones y las etiquetas que viajan dentro de un [Game] llegan con su
 * lista de juegos vacia: es lo que corta el ciclo juego -> coleccion -> juego
 * documentado en [Game].
 */

fun GameWithRelations.toDomain(): Game = Game(
  id = game.id,
  name = game.name,
  coverImageURL = game.coverImageURL,
  releaseDate = game.releaseDate,
  playtimeHours = game.playtimeHours,
  notes = game.notes,
  status = game.status,
  addedAt = game.addedAt,
  storeEntries = storeEntries.map { it.toDomain() },
  collections = collections.map { it.toDomain() },
  tags = tags.map { it.toDomain() },
)

fun StoreEntryEntity.toDomain(): StoreEntry = StoreEntry(
  id = id,
  store = store,
  storeGameID = storeGameID,
  storeURL = storeURL,
  playtimeHours = playtimeHours,
  recentPlaytimeHours = recentPlaytimeHours,
  lastPlayedAt = lastPlayedAt,
  wishlistedAt = wishlistedAt,
  trophyProgress = trophyProgress,
  launchCount = launchCount,
  earnedTrophies = earnedTrophies,
  definedTrophies = definedTrophies,
  comingSoon = comingSoon,
  lastSyncedAt = lastSyncedAt,
  gameId = gameId,
)

fun CollectionEntity.toDomain(games: List<Game> = emptyList()): GameCollection = GameCollection(
  id = id,
  name = name,
  symbol = symbol,
  color = color,
  sortOrder = sortOrder,
  createdAt = createdAt,
  games = games,
)

fun TagEntity.toDomain(games: List<Game> = emptyList()): GameTag = GameTag(
  id = id,
  name = name,
  createdAt = createdAt,
  games = games,
)

fun CollectionWithGames.toDomain(): GameCollection =
  collection.toDomain(games = games.map { it.toDomain() })

fun TagWithGames.toDomain(): GameTag = tag.toDomain(games = games.map { it.toDomain() })

fun Game.toEntity(): GameEntity = GameEntity(
  id = id,
  name = name,
  coverImageURL = coverImageURL,
  releaseDate = releaseDate,
  playtimeHours = playtimeHours,
  notes = notes,
  status = status,
  addedAt = addedAt,
)

/**
 * Convierte una entrada de dominio en fila.
 *
 * El id del juego se pasa aparte porque una entrada recien creada por un
 * mapper todavia no lo conoce: lo sabe el repositorio en el momento de
 * escribir.
 */
fun StoreEntry.toEntity(gameId: UUID): StoreEntryEntity = StoreEntryEntity(
  id = id,
  gameId = gameId,
  store = store,
  storeGameID = storeGameID,
  storeURL = storeURL,
  playtimeHours = playtimeHours,
  recentPlaytimeHours = recentPlaytimeHours,
  lastPlayedAt = lastPlayedAt,
  wishlistedAt = wishlistedAt,
  trophyProgress = trophyProgress,
  launchCount = launchCount,
  earnedTrophies = earnedTrophies,
  definedTrophies = definedTrophies,
  comingSoon = comingSoon,
  lastSyncedAt = lastSyncedAt,
)

fun GameCollection.toEntity(): CollectionEntity = CollectionEntity(
  id = id,
  name = name,
  symbol = symbol,
  color = color,
  sortOrder = sortOrder,
  createdAt = createdAt,
)

fun GameTag.toEntity(): TagEntity = TagEntity(id = id, name = name, createdAt = createdAt)
