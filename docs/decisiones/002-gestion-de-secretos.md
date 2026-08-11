# 002 - Gestion de secretos

- **Fecha:** 2026-08-10
- **Estado:** Aceptada
- **Issue:** [#3](https://github.com/JulianContreras02/GameShelf/issues/3)

## Contexto

La app necesita API keys de Steam y de IsThereAnyDeal. El riesgo real no es que
alguien extraiga la key del binario (eso siempre es posible en una app de
cliente), sino que la key quede escrita en el historial de git, donde queda
para siempre aunque despues se borre del codigo.

## Decision

Las keys entran por un archivo `.xcconfig` ignorado por git, pasan al Info.plist
como variables de build y se leen en tiempo de ejecucion desde `AppSecrets`.

```
Config/Secrets.xcconfig   (ignorado)  ->  Config/Info.plist  ->  AppSecrets
```

- `Config/Secrets.example.xcconfig` **si** se versiona: es la plantilla con las
  claves vacias.
- `Config/Secrets.xcconfig` **no** se versiona: es la copia con valores reales.
- `Config/Info.plist` mapea cada variable a una clave del Info.plist.
- `AppSecrets` las lee y devuelve un error accionable si falta alguna.

## Detalle tecnico que costo encontrar

Con `GENERATE_INFOPLIST_FILE = YES`, la primera idea fue declarar las claves
como build settings con el prefijo `INFOPLIST_KEY_`:

```
INFOPLIST_KEY_SteamAPIKey = "$(STEAM_API_KEY)"
```

**Eso no funciona.** El prefijo `INFOPLIST_KEY_` solo sirve para claves que
Apple ya conoce (`INFOPLIST_KEY_CFBundleDisplayName`,
`INFOPLIST_KEY_NSCameraUsageDescription`, etc.). Con una clave propia, el build
pasa sin error pero la clave **no aparece** en el Info.plist compilado: falla en
silencio, que es la peor forma de fallar.

La solucion es tener un Info.plist propio y apuntarlo con `INFOPLIST_FILE`.
`GENERATE_INFOPLIST_FILE` puede seguir en `YES`: Xcode toma el archivo como base
y le agrega encima las claves que genera solo.

Verificado inspeccionando el binario compilado:

```
plutil -p .../GameShelf.app/Info.plist
  "SteamAPIKey" => "VALOR_DE_PRUEBA_123"
```

## Alternativas consideradas

**Un archivo `Secrets.swift` ignorado por git.** Mas simple, no toca la
configuracion del proyecto. Rechazada porque el proyecto no compila hasta que
existe el archivo, lo que rompe el build en una maquina limpia y en CI. Con
xcconfig, la ausencia del archivo deja las claves vacias pero el proyecto
compila igual.

**Variables de entorno del esquema.** No se versionan y no viajan a CI de forma
natural. Rechazada.

**Keychain.** Es lo correcto para credenciales del usuario (el token de PSN, por
ejemplo), pero no para una API key del desarrollador que se necesita antes de
que el usuario haga nada. Se usara Keychain cuando llegue el issue de PSN.

## Consecuencias

- El repositorio nunca ve una key real.
- Si falta `Config/Secrets.xcconfig`, el proyecto **compila igual**: las claves
  quedan vacias y `AppSecrets.missingKeys()` las reporta.
- Xcode muestra el archivo en rojo si no existe. Es esperado; se resuelve
  copiando la plantilla.
- Esto **no** protege la key de alguien que inspeccione el binario. Para eso
  haria falta un backend propio, que esta fuera del alcance de este proyecto.
