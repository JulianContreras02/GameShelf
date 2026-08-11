# Como trabajamos en este proyecto

Proyecto personal de una sola persona, pero seguimos reglas claras desde el
dia uno para aprender buenas practicas de verdad, no atajos.

## Ramas

Usamos **GitHub Flow**, no GitFlow:

- `main` siempre debe compilar y funcionar. Nunca se comitea directo ahi.
- Cada funcionalidad o arreglo va en su propia rama:
  `feature/nombre-corto` o `fix/nombre-corto`.
- Se integra a `main` por Pull Request, aunque seas tu mismo revisando.
  Sirve como registro de que se hizo y por que, y da un punto donde revisar
  el propio trabajo con calma antes de fusionar.

## Mensajes de commit

[Conventional Commits](https://www.conventionalcommits.org/):

```
feat: agregar conexion con Steam Web API
fix: corregir parseo de precios con coma decimal
docs: actualizar instrucciones de instalacion
refactor: extraer modelo de Juego a su propio archivo
test: agregar pruebas para el cliente de Steam
chore: actualizar dependencias
```

## Estilo de codigo

Seguimos las [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
oficiales de Apple. Cuando el proyecto tenga codigo real, se agrega SwiftLint
para que el estilo se revise solo.

## Secretos

Ninguna API key se comitea, nunca. Viven en `Secrets.xcconfig`, que esta en
`.gitignore` desde el primer commit. Si algun dia una key se sube por error,
se revoca y se genera una nueva de inmediato - no basta con borrarla del
commit siguiente, porque queda en el historial de git.

## Tests

No hay tests el primer dia porque no hay logica todavia. A partir del primer
commit que tenga una funcion real (parseo de JSON, llamada de red,
transformacion de datos), esa funcion va acompañada de su prueba en XCTest.
No es opcional una vez que existe logica que pueda romperse.

## Orden de construccion del proyecto

1. Conector de Steam (biblioteca + wishlist), solo lectura.
2. Organizacion local: carpetas y listas propias sobre esos juegos.
3. Conexion con IsThereAnyDeal para ofertas de la wishlist.
4. Conector de PSN.
5. Conector de Epic (el mas fragil, al final).
