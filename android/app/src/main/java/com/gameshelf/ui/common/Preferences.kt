package com.gameshelf.ui.common

import android.content.Context
import android.content.SharedPreferences
import com.gameshelf.ui.library.GameSortOrder
import com.gameshelf.ui.wishlist.WishlistSortOrder
import java.time.Instant

/**
 * Preferencias que sobreviven al cierre de la app.
 *
 * Es el equivalente de `UserDefaults`. Se usa `SharedPreferences` y no
 * DataStore a proposito: las lecturas son sincronas, igual que en iOS, y eso
 * evita que la pantalla arranque con el orden por defecto y salte al guardado
 * un frame despues.
 *
 * De la biblioteca solo se guarda el **orden**. Los filtros son
 * deliberadamente pasajeros: abrir la app y encontrarse media biblioteca
 * escondida por un filtro que se puso ayer se siente como que faltan juegos.
 */
class AppPreferences(private val prefs: SharedPreferences) {

  var librarySortOrder: GameSortOrder
    get() = GameSortOrder.fromId(prefs.getString(LIBRARY_SORT, null))
    set(value) = prefs.edit().putString(LIBRARY_SORT, value.id).apply()

  var wishlistSortOrder: WishlistSortOrder
    get() = WishlistSortOrder.fromId(prefs.getString(WISHLIST_SORT, null))
    set(value) = prefs.edit().putString(WISHLIST_SORT, value.id).apply()

  /** Cuando termino la ultima sincronizacion correcta de la biblioteca. */
  var librarySyncedAt: Instant?
    get() = instante(LIBRARY_SYNCED_AT)
    set(value) = guardarInstante(LIBRARY_SYNCED_AT, value)

  /** Lo mismo, para la lista de deseos. */
  var wishlistSyncedAt: Instant?
    get() = instante(WISHLIST_SYNCED_AT)
    set(value) = guardarInstante(WISHLIST_SYNCED_AT, value)

  private fun instante(clave: String): Instant? =
    prefs.getLong(clave, 0L).takeIf { it > 0L }?.let(Instant::ofEpochMilli)

  private fun guardarInstante(clave: String, valor: Instant?) {
    prefs.edit().apply {
      if (valor == null) remove(clave) else putLong(clave, valor.toEpochMilli())
    }.apply()
  }

  companion object {
    private const val FILE = "gameshelf_prefs"
    private const val LIBRARY_SORT = "library.sortOrder"
    private const val WISHLIST_SORT = "wishlist.sortOrder"
    private const val LIBRARY_SYNCED_AT = "library.lastSyncedAt"
    private const val WISHLIST_SYNCED_AT = "wishlist.lastSyncedAt"

    fun from(context: Context): AppPreferences =
      AppPreferences(context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE))
  }
}
