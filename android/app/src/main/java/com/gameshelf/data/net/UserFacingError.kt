package com.gameshelf.data.net

import android.content.Context

/**
 * Un error que se puede ensenar tal cual en pantalla.
 *
 * Es el equivalente de `LocalizedError` de iOS, partido en dos igual que alla:
 * [message] dice **que** paso y [recovery] dice **que hacer**, o `null` cuando
 * no hay nada que el usuario pueda hacer.
 *
 * Los textos se piden con un `Context` en vez de resolverse en el momento de
 * crear el error: asi los servicios siguen sin depender de Android y se pueden
 * probar sin levantarlo.
 */
interface UserFacingError {
  fun message(context: Context): String
  fun recovery(context: Context): String? = null
}
