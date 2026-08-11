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

## Arquitectura

El proyecto usa MVVM adaptado a SwiftUI + SwiftData. La decision completa, con
alternativas y consecuencias, esta en
[`docs/decisiones/001-arquitectura.md`](docs/decisiones/001-arquitectura.md).

Las reglas que se revisan en cada PR:

1. **Una vista nunca llama a un `Service` directamente.** Siempre pasa por un
   ViewModel. Si una vista importa un Service, el PR no se fusiona.
2. Una vista **si** puede usar `@Query` para leer modelos locales de SwiftData.
3. Los `Services` no importan SwiftUI y se definen como protocolo, para poder
   inyectar un doble en las pruebas.
4. Los DTOs de red nunca se persisten: se mapean a modelos `@Model` antes.
5. Los ViewModels reciben Services por inyeccion; no construyen URLs ni
   parsean JSON.

## Estilo de codigo

Seguimos las [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
oficiales de Apple, con estas reglas de formato:

| Regla | Valor |
| --- | --- |
| Indentacion | **2 espacios** (nunca tabs) |
| Ancho de linea | 120 caracteres |
| Llave de apertura | En la misma linea |
| Imports | Ordenados alfabeticamente |

Para que Xcode respete la indentacion de 2 espacios:
`Xcode > Settings > Text Editing > Indentation` y dejar
`Prefer Indent Using: Spaces`, `Tab width: 2`, `Indent width: 2`.

Cuando el proyecto tenga codigo real se agrega SwiftLint, y estas reglas
quedan escritas en `.swiftlint.yml` para que el estilo se revise solo y no
dependa de la configuracion local de cada maquina.

## Secretos

Ninguna API key se comitea, nunca. Viven en `Secrets.xcconfig`, que esta en
`.gitignore` desde el primer commit. Si algun dia una key se sube por error,
se revoca y se genera una nueva de inmediato - no basta con borrarla del
commit siguiente, porque queda en el historial de git.

## Tests

El proyecto usa **Swift Testing** (`@Test`, `#expect`) para pruebas unitarias
y **XCTest** solo para pruebas de interfaz.

Reglas:

- Toda logica que pueda romperse va con su prueba: parseo de JSON, mapeo de
  DTO a modelo, calculos, filtros, validaciones.
- Las llamadas de red no se prueban contra el servidor real. Se prueba el
  parseo con respuestas JSON guardadas como archivos de apoyo.
- Vistas de SwiftUI no llevan prueba unitaria; lo que se prueba es el modelo
  que las alimenta.
- Un PR que agrega logica sin prueba no se fusiona.

## Documentacion

- Todo tipo y metodo publico lleva comentario de documentacion (`///`).
- Cada requerimiento (issue) se cierra con su documentacion al dia.
- Las decisiones de arquitectura que no sean obvias se registran en
  `docs/decisiones/`, en un archivo corto por decision: que se decidio,
  que alternativas habia y por que se escogio esa.
- El `README.md` se actualiza cuando cambia la forma de instalar o correr
  el proyecto.

## Orden de construccion del proyecto

1. Conector de Steam (biblioteca + wishlist), solo lectura.
2. Organizacion local: carpetas y listas propias sobre esos juegos.
3. Conexion con IsThereAnyDeal para ofertas de la wishlist.
4. Conector de PSN.
5. Conector de Epic (el mas fragil, al final).
