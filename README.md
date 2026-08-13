# GameShelf

App personal para iOS que organiza tu biblioteca de videojuegos en un solo lugar,
sin importar de que tienda vienen.

## Que hace

- Conecta tus cuentas de Steam, PlayStation Network y Epic Games para traer los
  juegos que ya tienes.
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
| `ITAD_API_KEY` | https://isthereanydeal.com/apps/my/ (solo hace falta para el modulo de ofertas) |

Llena el valor en `Config/Secrets.xcconfig`:

```
ITAD_API_KEY = tu_key_aqui
```

Steam, PlayStation y Epic **no van aca**: se conectan desde la app. Ver la
siguiente seccion.

### 3. Correr

Abrir `GameShelf.xcodeproj` en Xcode y correr en el simulador o en tu
dispositivo.

Si falta alguna clave el proyecto **compila igual**: la app avisa cuales faltan
en vez de caerse. Ver `docs/decisiones/002-gestion-de-secretos.md`.

### Requisitos

- Xcode 26 o superior
- [SwiftLint](https://github.com/realm/SwiftLint): `brew install swiftlint`

## Conectar Steam, PlayStation y Epic

Las tres se conectan desde la app, en **Ajustes -> Cuentas**, y sus
credenciales se guardan cifradas en el llavero del telefono. Ninguna vive en
el archivo de secretos: eso es lo que permite instalar la app en otro telefono
y conectar ahi una cuenta distinta, sin recompilar.

### Steam

A diferencia de PSN y Epic, Steam si ofrece un camino oficial: no hace falta
iniciar sesion desde la app.

1. Consigue tu SteamID64 en https://steamid.io pegando la URL de tu perfil.
2. Saca una API key gratis en https://steamcommunity.com/dev/apikey (pide un
   dominio; sirve `localhost`).
3. Pega los dos datos en **Ajustes -> Steam**.

### PlayStation y Epic

La razon de que sean un rodeo es la misma en las dos: ni Sony ni Epic ofrecen
un "iniciar sesion" para aplicaciones de terceros. Lo unico que hay es copiar
un codigo desde el navegador, con la sesion ya iniciada.

### PlayStation Network

1. Inicia sesion en https://www.playstation.com/ (boton "Sign In").
2. **En el mismo navegador**, abre
   https://ca.account.sony.com/api/v1/ssocookie
3. Copia lo que aparece entre comillas y pegalo en la app.

Lo que comparten los dos pasos es la sesion, por eso tienen que ser en el
mismo navegador. Si el segundo responde
`{"error":"invalid_grant","error_description":"Invalid login"}`, es que falta
el paso 1.

Ese codigo dura unos dos meses. Mientras tanto la app renueva el acceso sola.

### Epic Games

> **Ojo.** Epic avisa en su propia pagina de que ese codigo **da acceso
> completo a la cuenta**. En GameShelf se guarda cifrado en el llavero y no se
> manda a ningun servidor, pero no conviene pegarlo en ningun otro sitio.

1. Inicia sesion en https://www.epicgames.com/id/login
2. **En el mismo navegador**, abre
   https://www.epicgames.com/id/api/redirect?clientId=34a02cf8f4414e29b15921876da36f9a&responseType=code
3. Copia lo que hay tras `"authorizationCode"`, entre comillas, y pegalo en la
   app **enseguida**.

Los codigos de Epic caducan en segundos. Si al pegarlo dice que no sirve, basta
con recargar esa pagina y copiar el nuevo. Si la pagina muestra
`"authorizationCode": null`, es que falta el paso 1.

### Que pasa si una falla

Cada tienda va por su lado. Si el flujo de Epic deja de funcionar, o si Sony
cambia el suyo, **el resto de la app sigue igual**: la biblioteca ya guardada,
las colecciones y las notas no dependen de ellos.

## Estado del proyecto

En construccion. Ver `CONTRIBUTING.md` para las reglas de trabajo.
