# ``GameShelf``

Tu biblioteca de videojuegos de Steam, PlayStation, Epic y Xbox en un solo lugar.

## Overview

GameShelf trae los juegos de cada tienda, los junta en una sola biblioteca sin
repetirlos y deja organizarlos con cosas propias: el estado de cada juego, las
colecciones, las etiquetas y las notas. Ninguna tienda deja hacer eso entre
plataformas. Ademas revisa los precios de la lista de deseos con
IsThereAnyDeal.

Esta documentacion cubre las dos capas que guardan la logica que se puede
romper: los **modelos** y los **servicios**. Las vistas y los ViewModels quedan
fuera a proposito; se entienden mejor leyendo el codigo junto a la pantalla.

### Como esta armada

La app sigue MVVM sobre SwiftUI y SwiftData. La decision completa, con las
alternativas y sus consecuencias, esta en
`docs/decisiones/001-arquitectura.md`. Lo que hay que saber para moverse por
aca:

- **Modelos.** Lo que se guarda con SwiftData. El centro es ``Game``: un juego
  independiente de la tienda, con una ``StoreEntry`` por cada tienda donde
  esta. Lo que decide el usuario (``Game/status``, ``Game/notes``, sus
  colecciones y etiquetas) vive en el juego, y ninguna sincronizacion lo toca.
- **Servicios.** Todo lo que habla con algo de fuera: las APIs de las tiendas,
  IsThereAnyDeal y el llavero del sistema. Cada uno va detras de un protocolo,
  para poder probarlo con un doble, y no sabe nada de SwiftUI.
- **DTOs.** Las respuestas de las APIs tal cual llegan, con sus rarezas. Nunca
  se guardan: un servicio o un *mapper* las traduce a modelos antes.

El camino entero, de la cuenta del usuario a la base de datos, esta en
<doc:Sincronizacion>.

## Topics

### Para empezar

- <doc:Sincronizacion>

### La biblioteca

- ``Game``
- ``StoreEntry``
- ``Store``
- ``PlayStatus``
- ``TrophyCounts``
- ``TrophyBreakdown``
- ``TrophyKind``
- ``Gamerscore``

### Sesiones de juego

- ``PlaySession``
- ``PlaySessionError``
- ``PlaySessionTracker``

### Organizacion del usuario

- ``GameCollection``
- ``CollectionColor``
- ``GameTag``

### Juntar las tiendas

- ``LibraryMatcher``

### Red

- ``HTTPClient``
- ``URLSessionHTTPClient``
- ``NetworkError``

### Llavero

- ``KeychainStoring``
- ``KeychainStore``
- ``InMemoryKeychainStore``

### Steam

- ``SteamServicing``
- ``SteamService``
- ``SteamCredentialsValidating``
- ``SteamCredentialsError``
- ``SteamLibrarySyncer``
- ``SteamGameMapper``
- ``SteamPresence``
- ``SteamWishlistServicing``
- ``SteamWishlistService``
- ``SteamWishlistGame``
- ``SteamWishlistSyncer``
- ``SteamWishlistMapper``

### PlayStation

- ``PSNAuthenticating``
- ``PSNAuthService``
- ``PSNCredentials``
- ``PSNAuthError``
- ``PSNLibraryServicing``
- ``PSNLibraryService``
- ``PSNGame``
- ``PSNLibrarySyncer``
- ``PSNGameMapper``

### Epic Games

- ``EpicAuthenticating``
- ``EpicAuthService``
- ``EpicCredentials``
- ``EpicAuthError``
- ``EpicLibraryServicing``
- ``EpicLibraryService``
- ``EpicGame``
- ``EpicLibrarySyncer``
- ``EpicGameMapper``

### Xbox

- ``XboxAuthenticating``
- ``XboxAuthService``
- ``XboxCredentials``
- ``XboxAuthError``
- ``XboxLibraryServicing``
- ``XboxLibraryService``
- ``XboxGame``
- ``XboxLibrarySyncer``
- ``XboxGameMapper``

### Precios y ofertas

- ``ITADServicing``
- ``ITADService``
- ``ITADCredentialsError``
- ``GamePrices``
- ``GameDeal``
- ``Money``
