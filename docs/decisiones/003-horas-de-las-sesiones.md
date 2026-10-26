# 003 - Como entran las sesiones en las horas de un juego

- **Fecha:** 2026-10-20
- **Estado:** Aceptada
- **Issue:** [#41](https://github.com/JulianContreras02/GameShelf/issues/41)

## Contexto

El issue pide que, al cerrar una `PlaySession`, su duracion se sume a las horas
totales del `Game`.

El problema es que `Game.playtimeHours` no es un acumulado: cada sincronizacion
con una tienda lo **rehace desde cero**, sumando las horas de sus `StoreEntry`
(`SteamGameMapper.recalculatePlaytime`). Un `playtimeHours += duracion` al
cerrar la sesion funcionaria hasta la siguiente sincronizacion, y ahi se
perderia sin avisar.

## Decision

Las sesiones son una fuente mas del total, igual que las tiendas:

```
Game.playtimeHours = suma de StoreEntry.playtimeHours + Game.sessionPlaytimeHours
```

- `Game.sessionPlaytimeHours` se calcula de las sesiones **cerradas**. La activa
  no cuenta hasta cerrarla, para que el total no vaya cambiando solo.
- El total se sigue recalculando en un solo sitio, `recalculatePlaytime`, que
  ahora incluye las sesiones. `PlaySessionTracker.end` lo llama al cerrar una.
- Las sesiones cuelgan del juego con borrado en cascada, igual que sus entradas
  de tienda.

## Consecuencia a tener en cuenta: horas contadas dos veces

Todas las tiendas que hay hoy (Steam, PSN, Epic y Xbox) informan sus propias
horas. Si juegas dos horas a un juego de Steam y ademas registras esa sesion en
la app, el total suma cuatro: dos de Steam y dos de la sesion.

Se deja asi a proposito, porque es lo que pide el issue y porque decidir que
sesion "ya esta contada" por una tienda necesita informacion que todavia no
hay. Se puede revisar cuando llegue la deteccion automatica desde la presencia
de Steam (#49), que es donde el doble conteo seria constante. Opciones para
entonces:

- Que las sesiones de un juego que tiene tienda no sumen al total, y solo se
  vean en el historial (#47).
- Que solo sumen las sesiones de juegos sin horas de ninguna tienda.

Cualquiera de las dos es cambiar la formula de `recalculatePlaytime` y nada
mas.

## Alternativas consideradas

- **Sumar al cerrar (`+=`).** Lo mas directo, pero la siguiente sincronizacion
  borra lo sumado. Descartada por eso: hay una prueba que lo comprueba.
- **Un campo `manualPlaytimeHours` en `Game`** que se incrementa al cerrar.
  Sobrevive a las sincronizaciones, pero es un segundo dato que puede
  desincronizarse de las sesiones, por ejemplo si un dia se borra o se edita
  una. Calcularlo de las sesiones evita esa clase de error.
