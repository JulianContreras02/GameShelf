# GameShelf para Android

Version Android de GameShelf, portada desde la app de iOS que vive en la raiz
del repositorio. Las dos hacen lo mismo y comparten el archivo de secretos y
los fixtures de las pruebas.

El proyecto de iOS **no se toco**: sigue al lado, y sirve tanto de referencia
como para comparar las dos versiones cuando algo se comporta distinto.

## Como correrlo

### 1. Secretos

Se leen del **mismo archivo** que usa la version de iOS:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Y se llenan los valores como explica el README principal. Gradle lo parsea y
mete las claves en `BuildConfig`. Si no existe ese archivo, tambien se leen de
`android/local.properties`.

Si falta alguna clave el proyecto **compila igual**: la app avisa cuales faltan
en Ajustes, en vez de caerse. Es la misma promesa que en iOS.

### 2. Compilar

```bash
cd android
./gradlew assembleDebug          # el APK queda en app/build/outputs/apk/debug/
./gradlew testDebugUnitTest      # las pruebas
./gradlew installDebug           # instalar en un dispositivo conectado
```

### Requisitos

- JDK 17 o 21 (el 25 todavia no lo soporta el plugin de Android)
- Android SDK con la plataforma 35 y build-tools 35
- No hace falta instalar Gradle: el wrapper lo descarga solo

Si el SDK no esta en la ruta por defecto, se indica en `android/local.properties`:

```
sdk.dir=/ruta/a/tu/Android/Sdk
```

## Como se hizo el puerto

| iOS | Android | Por que |
| --- | --- | --- |
| SwiftUI | Jetpack Compose | Equivalente directo |
| SwiftData | Room | Las relaciones N:M pasan a tablas puente |
| Clases `@Model` mutables | `data class` inmutables | Los mappers devuelven copias y el repositorio escribe |
| `@Query` | `Flow` de Room | Compose no tiene un equivalente que lea la base solo |
| `URLSession` | OkHttp | |
| `Codable` | kotlinx.serialization | |
| Keychain | `EncryptedSharedPreferences` | Cifrado con una clave del Keystore |
| `UserDefaults` | `SharedPreferences` | Lecturas sincronas, como alla |
| `LocalizedError` | `UserFacingError` con ids de recurso | Resolver una cadena necesita `Context`, y meterlo en el dominio obligaria a levantar Android para probar logica pura |
| SF Symbols | Iconos de Material | El dominio nombra el icono, la UI lo traduce |
| String Catalog | `values/` y `values-en/` | Espanol como base, igual que en iOS |

Lo que **no** cambio: las reglas de negocio. La sincronizacion sigue siendo
idempotente, sigue sin borrar juegos, y sigue sin tocar nunca el estado, las
notas ni las colecciones del usuario.

### Diferencias que si se notan

- **Los iconos de coleccion son un conjunto cerrado.** En iOS se guardaba el
  nombre libre de un SF Symbol; aca los iconos de Material se referencian por
  propiedad, asi que un nombre guardado que ya no exista no podria resolverse
  en tiempo de ejecucion. Cerrar el conjunto convierte ese fallo en imposible.
- **Las colecciones se reordenan con botones**, no arrastrando. El arrastre es
  dificil de usar con un lector de pantalla y estas dos flechas funcionan igual
  para todos.
- **La lista de deseos vive en Ajustes y en la biblioteca**, no en su propia
  pestana: la barra inferior de Android se llena antes que la de iOS.

## Pruebas

```bash
./gradlew testDebugUnitTest
```

Usan **los mismos fixtures JSON** que la suite de iOS, copiados sin tocar a
`app/src/test/resources/fixtures`. Si las dos versiones se prueban contra las
mismas respuestas reales, un cambio de formato en una API rompe las dos a la
vez y no una sola.
