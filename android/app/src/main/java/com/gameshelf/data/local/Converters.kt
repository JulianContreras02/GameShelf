package com.gameshelf.data.local

import androidx.room.TypeConverter
import com.gameshelf.domain.CollectionColor
import com.gameshelf.domain.CollectionSymbol
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.TrophyCounts
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.UUID

/**
 * Traducciones entre los tipos del dominio y lo que sabe guardar SQLite.
 *
 * Los enums se guardan por su id de texto y no por el ordinal, igual que en
 * iOS: asi agregar o reordenar casos no corrompe lo ya guardado. Un valor que
 * no se reconozca cae al por defecto en vez de reventar, porque una fila vieja
 * no deberia impedir abrir la app.
 */
class Converters {

  @TypeConverter fun uuidToString(value: UUID?): String? = value?.toString()

  @TypeConverter fun stringToUuid(value: String?): UUID? = value?.let(UUID::fromString)

  @TypeConverter fun instantToLong(value: Instant?): Long? = value?.toEpochMilli()

  @TypeConverter fun longToInstant(value: Long?): Instant? = value?.let(Instant::ofEpochMilli)

  @TypeConverter fun storeToString(value: Store?): String? = value?.id

  @TypeConverter
  fun stringToStore(value: String?): Store? = value?.let { Store.fromId(it) ?: Store.STEAM }

  @TypeConverter fun statusToString(value: PlayStatus?): String? = value?.id

  @TypeConverter
  fun stringToStatus(value: String?): PlayStatus? =
    value?.let { PlayStatus.fromId(it) ?: PlayStatus.BACKLOG }

  @TypeConverter fun colorToString(value: CollectionColor?): String? = value?.id

  @TypeConverter
  fun stringToColor(value: String?): CollectionColor? =
    value?.let { CollectionColor.fromId(it) ?: CollectionColor.DEFAULT }

  @TypeConverter fun symbolToString(value: CollectionSymbol?): String? = value?.id

  @TypeConverter
  fun stringToSymbol(value: String?): CollectionSymbol? = value?.let(CollectionSymbol::fromId)

  /**
   * Los conteos de trofeos van como JSON en una sola columna.
   *
   * Es el equivalente al valor embebido de SwiftData, y mantiene la regla de
   * que los cuatro numeros viajan siempre juntos.
   */
  @TypeConverter
  fun trophyCountsToString(value: TrophyCounts?): String? =
    value?.let { json.encodeToString(TrophyCounts.serializer(), it) }

  @TypeConverter
  fun stringToTrophyCounts(value: String?): TrophyCounts? =
    value?.let { runCatching { json.decodeFromString(TrophyCounts.serializer(), it) }.getOrNull() }

  private companion object {
    val json = Json { ignoreUnknownKeys = true }
  }
}
