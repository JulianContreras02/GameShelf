package com.gameshelf.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

/**
 * La base local de la app, el equivalente al `ModelContainer` de SwiftData.
 *
 * Las claves foraneas se activan a mano: SQLite las trae apagadas por defecto,
 * y sin ellas el borrado en cascada de las entradas de tienda y de las tablas
 * puente no ocurriria.
 */
@Database(
  entities = [
    GameEntity::class,
    StoreEntryEntity::class,
    CollectionEntity::class,
    TagEntity::class,
    GameCollectionCrossRef::class,
    GameTagCrossRef::class,
  ],
  version = 1,
  exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class GameShelfDatabase : RoomDatabase() {

  abstract fun gameDao(): GameDao
  abstract fun collectionDao(): CollectionDao
  abstract fun tagDao(): TagDao

  companion object {
    private const val NAME = "gameshelf.db"

    @Volatile
    private var instancia: GameShelfDatabase? = null

    fun get(context: Context): GameShelfDatabase =
      instancia ?: synchronized(this) {
        instancia ?: build(context.applicationContext).also { instancia = it }
      }

    private fun build(context: Context): GameShelfDatabase =
      Room.databaseBuilder(context, GameShelfDatabase::class.java, NAME)
        .build()

    /** Base en memoria, para pruebas y vistas previas. */
    fun inMemory(context: Context): GameShelfDatabase =
      Room.inMemoryDatabaseBuilder(context, GameShelfDatabase::class.java)
        .allowMainThreadQueries()
        .build()
  }
}
