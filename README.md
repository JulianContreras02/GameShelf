# GameShelf

App personal para iOS que organiza tu biblioteca de videojuegos en un solo lugar,
sin importar de que tienda vienen.

## Que hace

- Conecta con tu cuenta de Steam (y mas adelante PSN, Epic) para traer los juegos
  que ya tienes.
- Te deja organizar esa biblioteca con tus propias carpetas y listas
  (pendientes, favoritos, lo que sea), algo que ninguna tienda te deja hacer
  entre plataformas.
- Revisa ofertas de tu lista de deseos usando una API de agregador de precios
  (IsThereAnyDeal), en vez de reinventar el scraping de cada tienda.

Es un proyecto de aprendizaje: mi primera app en el ecosistema Apple, y estoy
usandolo tambien para experimentar con las funciones de accesibilidad de iOS.

## Como correrlo

### 1. Crear tu archivo de secretos

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Ese archivo esta ignorado por git, asi que tus claves nunca se suben.

### 2. Conseguir las claves

| Clave | Donde se saca |
| --- | --- |
| `STEAM_API_KEY` | https://steamcommunity.com/dev/apikey (pide un dominio; sirve `localhost`) |
| `STEAM_ID` | Tu SteamID64, el numero de 17 digitos. Se obtiene en https://steamid.io pegando la URL de tu perfil |
| `ITAD_API_KEY` | https://isthereanydeal.com/apps/new/ (solo hace falta para el modulo de ofertas) |

Llena los valores en `Config/Secrets.xcconfig`:

```
STEAM_API_KEY = tu_key_aqui
STEAM_ID = 76561198000000000
ITAD_API_KEY = tu_key_aqui
```

### 3. Correr

Abrir `GameShelf.xcodeproj` en Xcode y correr en el simulador o en tu
dispositivo.

Si falta alguna clave el proyecto **compila igual**: la app avisa cuales faltan
en vez de caerse. Ver `docs/decisiones/002-gestion-de-secretos.md`.

### Requisitos

- Xcode 26 o superior
- [SwiftLint](https://github.com/realm/SwiftLint): `brew install swiftlint`

## Estado del proyecto

En construccion. Ver `CONTRIBUTING.md` para las reglas de trabajo.
