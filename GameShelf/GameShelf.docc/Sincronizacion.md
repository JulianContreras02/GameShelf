# Como se sincroniza una tienda

De la cuenta del usuario a la biblioteca: el camino que siguen todas las
tiendas.

## Overview

Cada tienda es distinta por dentro. Steam tiene una API oficial; PlayStation,
Epic y Xbox no, y cada una tiene sus rarezas. Pero las cuatro siguen el mismo
camino hasta la base de datos, y conocerlo es lo que deja agregar una tienda
nueva sin tocar las demas.

```
Ajustes ─▶ ViewModel de la cuenta ─▶ servicio de biblioteca ─▶ HTTPClient ─▶ API
                                              │
                                     DTOs ─▶ valor propio (PSNGame, EpicGame…)
                                              │
                    syncer ─ LibraryMatcher ─▶ mapper ─▶ Game + StoreEntry ─▶ SwiftData
```

### 1. Las credenciales

Las cuentas se conectan desde Ajustes y sus credenciales viven en el llavero del
sistema, detras de ``KeychainStoring``. Nunca en `UserDefaults`, que es un
archivo sin cifrar, ni en el binario.

- **Steam** usa una API key y un SteamID que el usuario pega
  (``SteamService/Credentials``). No hay tokens que renovar.
- **PlayStation, Epic y Xbox** no ofrecen un "iniciar sesion" para apps de
  terceros. El usuario copia un codigo del navegador y su servicio de
  autenticacion (``PSNAuthService``, ``EpicAuthService``, ``XboxAuthService``)
  lo canjea por tokens. En Xbox hace falta antes registrar una app propia en
  Azure: ``XboxCredentials`` guarda las dos identidades.

Los tokens caducan, y el ViewModel de cada cuenta los renueva solo cuando hace
falta, con el refresh token. Cuando eso tampoco sirve, el estado de la cuenta
pasa a pedir un codigo nuevo, que es lo unico que lo arregla.

### 2. Pedir los datos

El ViewModel de la cuenta arma el servicio de biblioteca y, en vez de pasarle un
token, le pasa una funcion que lo devuelve vigente. Asi un token que vence a
mitad de una sincronizacion larga se renueva sin que el servicio se entere.

Los servicios solo hablan con la red a traves de ``HTTPClient``, que traduce
cualquier fallo a ``NetworkError``. En las APIs con sesion, un 401 o un 403 se
traduce a "la sesion caduco" (por ejemplo ``PSNAuthError/sesionExpirada``): es
lo que le dice a la pantalla que pida un codigo nuevo en vez de ensenar
"error 401".

Lo propio de cada tienda queda encerrado en su servicio:

- **Steam** (``SteamService``): una sola peticion, `GetOwnedGames`, con
  `include_played_free_games=1`. Sin ese parametro Steam se salta los
  free-to-play jugados.
- **PlayStation** (``PSNLibraryService``): la lista de juegos viene paginada, y
  el progreso de trofeos se pide aparte, en tandas. Las respuestas llegan en
  otro orden del que se pidio, asi que se indexan por id.
- **Epic** (``EpicLibraryService``): la biblioteca no trae juegos sino
  artefactos (el ejecutable, cada DLC...), y se agrupan por `namespace`. El
  tiempo jugado y los nombres que faltan salen de consultas aparte que **no
  tumban la sincronizacion** si fallan: mejor ver los juegos sin horas que no
  verlos.
- **Lista de deseos de Steam** (``SteamWishlistService``): dos llamadas
  encadenadas, primero los appids y despues sus fichas en la tienda.

### 3. De DTO a valor propio

Las respuestas se decodifican a DTOs que reflejan la API tal cual, con sus
nombres y sus opcionales. Los DTOs **nunca se guardan**. Lo que sale del
servicio es un valor propio y simple, ya limpio (``PSNGame``, ``EpicGame``,
``SteamWishlistGame``): con el nombre resuelto, las horas en horas y las fechas
como `Date`. Steam es la excepcion: su syncer recibe directamente
``SteamGameDTO``, que ya es casi un valor de dominio.

### 4. Guardar sin duplicar

Un *syncer* por tienda (``SteamLibrarySyncer``, ``PSNLibrarySyncer``,
``EpicLibrarySyncer``) guarda lo que llego, siempre con las mismas reglas:

- **Es idempotente.** Sincronizar dos veces con lo mismo deja la base igual.
- **Nunca borra.** Un juego que deja de venir puede faltar porque la peticion
  fallo a medias. Borrar la biblioteca del usuario por eso seria mucho peor que
  dejar un juego de mas.
- **No toca lo del usuario.** ``Game/status``, ``Game/notes``, las colecciones
  y las etiquetas no cambian en ninguna sincronizacion.
- **No repite juegos entre tiendas.** ``LibraryMatcher`` busca primero el id en
  la misma tienda y, si no esta, el nombre en todas las demas, sin mayusculas
  ni tildes. Si el juego ya vino de otra tienda, suma una ``StoreEntry`` nueva
  en vez de crear otro ``Game``: esa union es lo que hace util tener las
  tiendas juntas.

Un *mapper* por tienda (``PSNGameMapper``, ``EpicGameMapper``,
``SteamGameMapper``) decide que se pisa al actualizar. En general, solo lo que
llego bien: si PlayStation manda una duracion ilegible, la que ya estaba
guardada es mejor que un cero.

> Important: Steam todavia busca solo por appid. Fue el primer conector y no usa
> ``LibraryMatcher``, asi que un juego que llego antes por PlayStation o Epic se
> crea otra vez al sincronizar Steam.

La lista de deseos es la unica que quita algo: si un juego deja de estar en la
lista de Steam, ``SteamWishlistSyncer`` le quita la marca
(``StoreEntry/wishlistedAt``), pero el juego se queda. Y si la respuesta llega
vacia no quita nada, porque una lista privada responde igual que una vacia.

### 5. Las horas

``Game/playtimeHours`` es el total, y cada ``StoreEntry`` lleva las horas de su
tienda. Cada sincronizacion rehace el total desde cero con
``SteamGameMapper/recalculatePlaytime(for:)``, sumando las de todas las
entradas. Por eso el total nunca se toca a mano: el siguiente recalculo lo
pisaria.

### 6. Los precios

Los precios no se guardan. Al abrir la lista de deseos, y al refrescarla, el
ViewModel le pide a
``ITADService`` los de todos los juegos de una vez, por su appid de Steam
(``Game/steamAppID``): dos peticiones en lote, una para traducir los appids a
ids de IsThereAnyDeal y otra para los precios. Si falta la clave de
IsThereAnyDeal, la lista se ve igual, sin precios.

## Agregar una tienda

Con este camino, una tienda nueva es sobre todo codigo nuevo y casi nada de
codigo tocado:

1. Un caso nuevo en ``Store``.
2. Su autenticacion, si hace falta, con las credenciales en el llavero.
3. Un servicio de biblioteca detras de un protocolo, con sus DTOs y respuestas
   guardadas como archivos de apoyo para las pruebas.
4. Un valor propio con lo que hace falta para guardar un juego.
5. Un syncer que use ``LibraryMatcher`` y un mapper que respete lo del usuario.
6. El `syncLibrary(into:using:)` del ViewModel de la cuenta y su boton en
   Ajustes.
