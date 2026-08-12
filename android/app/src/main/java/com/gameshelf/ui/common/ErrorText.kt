package com.gameshelf.ui.common

import android.content.Context
import androidx.annotation.StringRes
import com.gameshelf.data.net.UserFacingError

/**
 * Traduce cualquier error a un texto que se le pueda ensenar al usuario.
 *
 * En iOS esto lo resolvia `LocalizedError` en el momento de crear el error.
 * Aca los errores viajan sin texto (no conocen `Context`) y se resuelven en la
 * capa de UI, que es la unica que puede leer `strings.xml`. Ese cambio es lo
 * que permite que los servicios y los ViewModels se prueben sin Android.
 *
 * @param fallback Que decir cuando el error no sabe describirse. En iOS era el
 *   `?? String(localized: "No se pudo sincronizar.")` repetido en cada `catch`.
 */
fun Throwable.userMessage(context: Context, @StringRes fallback: Int): String = when (this) {
  is UserFacingError -> message(context)
  else -> localizedMessage ?: context.getString(fallback)
}

/** Que puede hacer el usuario, si el error lo sabe. */
fun Throwable.userRecovery(context: Context): String? =
  (this as? UserFacingError)?.recovery(context)
