# GameShelf para Android

Version Android de GameShelf, portada desde la app de iOS que vive en la raiz
del repositorio. Las dos hacen lo mismo y comparten el archivo de secretos y
los fixtures de las pruebas.

El proyecto de iOS **no se toco**: sigue al lado, y sirve tanto de referencia
como para comparar las dos versiones cuando algo se comporta distinto.

## Como correrlo

### 1. Compilar y ya

No hace falta configurar nada antes de compilar. Las cuentas se conectan
**desde dentro de la app**, en Ajustes, y cada una pide ahi lo que necesita.

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

## Conectar las cuentas

Todo se hace en **Ajustes**, con la app corriendo. Cada cuenta se guarda cifrada
con `EncryptedSharedPreferences` y nada sale del dispositivo.

| Cuenta | Que pide | De donde sale |
| --- | --- | --- |
| Steam | La clave de la Web API y la direccion de tu perfil | `steamcommunity.com/dev/apikey` y tu propio perfil |
| PlayStation | El codigo NPSSO | Del navegador, con la sesion iniciada |
| Epic | El codigo de autorizacion | Del navegador, con la sesion iniciada |
| Precios (opcional) | La clave de IsThereAnyDeal | `isthereanydeal.com/apps/new/` |

Las cuatro pantallas tienen la misma forma y traen los enlaces en orden, porque
en las tres primeras el segundo paso falla de manera confusa si no se hizo el
primero.

### Por que hay que pegar claves y no hay un boton de "iniciar sesion"

Ninguna de las tres tiendas ofrece OAuth a aplicaciones de terceros para lo que
esta app necesita:

- **Steam** no tiene OAuth para su Web API. La clave se genera a mano en su web
  y solo se puede copiar de ahi. Lo que si se resuelve solo es el SteamID: se
  pega la URL del perfil y la app la traduce al numero de 17 digitos, resolviendo
  el nombre personalizado contra la API cuando hace falta.
- **PlayStation** y **Epic** solo exponen un codigo que se copia del navegador
  con la sesion ya iniciada.

Lo que si cambio es **cuando** se piden: antes eran configuracion de compilacion
y ahora son parte de usar la app.

### El archivo de secretos sigue sirviendo

Si ya tenias `Config/Secrets.xcconfig` (por ejemplo porque compartes el repo con
la version de iOS), sigue funcionando sin tocar nada: cuando no hay ninguna
cuenta conectada, las claves se leen de ahi como antes. Lo que conectes desde la
app siempre gana sobre el archivo.

Para crearlo, si lo prefieres a conectar desde la app:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Tambien se leen de `android/local.properties`. Si no existe ninguno de los dos,
el proyecto **compila igual**: simplemente arranca sin cuentas conectadas.

### El emulador, sin ventana, revienta

En Fedora 44 (kernel 7.1) el emulador **en modo headless** se cae con SIGSEGV
antes de terminar de arrancar Android, con y sin GPU:

```
qemu-system-x86_64-headless   SIGSEGV
```

Con ventana funciona sin problema, porque es **otro binario**
(`qemu-system-x86_64`, sin el sufijo) y otra ruta de renderizado:

```bash
emulator -avd <nombre> -gpu host        # arranca en ~30 s
emulator -avd <nombre> -no-window       # SIGSEGV
```

Asi que si la idea es probar en CI sin pantalla, este emulador no sirve tal
cual en esta distribucion: hace falta un servidor X virtual por delante, o un
dispositivo real.

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
