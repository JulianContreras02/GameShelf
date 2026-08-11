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

1. Abrir `GameShelf.xcodeproj` en Xcode.
2. Conseguir tu propia API key de Steam en
   https://steamcommunity.com/dev/apikey
3. Crear un archivo `Secrets.xcconfig` en la raiz del proyecto (no se sube a
   git, ver `.gitignore`) con:
   ```
   STEAM_API_KEY = tu_key_aqui
   STEAM_ID = tu_steamid64_aqui
   ```
4. Correr en el simulador o en tu propio dispositivo.

## Estado del proyecto

En construccion. Ver `CONTRIBUTING.md` para las reglas de trabajo.
