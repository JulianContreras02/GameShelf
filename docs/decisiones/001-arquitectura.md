# 001 - Arquitectura de la app

- **Fecha:** 2026-08-10
- **Estado:** Aceptada
- **Issue:** [#1](https://github.com/JulianContreras02/GameShelf/issues/1)

## Contexto

GameShelf tiene que hacer tres cosas muy distintas entre si:

1. Hablar con APIs externas (Steam, IsThereAnyDeal, PSN, Epic).
2. Guardar y organizar datos localmente con SwiftData.
3. Mostrar todo eso en pantalla con SwiftUI.

Si esas tres responsabilidades quedan mezcladas dentro de las vistas, pasan dos
cosas malas: no se puede probar nada sin levantar la interfaz, y cambiar una
API obliga a tocar codigo de UI.

Ademas, este proyecto tiene como requisito explicito tener pruebas unitarias
(ver `CONTRIBUTING.md`), asi que la arquitectura tiene que hacer que la logica
sea probable **sin** instanciar vistas.

## Decision

Usamos **MVVM adaptado a SwiftUI + SwiftData**. No MVVM de libro: MVVM donde
aporta, y acceso directo donde el framework ya resuelve el problema.

### La tension que hay que entender

MVVM clasico dice que la vista nunca toca los datos: siempre pasa por un
ViewModel. Pero SwiftData fue diseñado con la idea contraria: la vista declara
que datos quiere con `@Query` y el framework se encarga de traerlos y de
refrescar la pantalla cuando cambian.

`@Query` **solo funciona dentro de una `View`**. Si lo envolvemos en un
ViewModel para cumplir el dogma de MVVM, perdemos la actualizacion automatica y
tenemos que reimplementar a mano algo que el framework ya hacia bien.

Por eso no aplicamos MVVM de forma uniforme.

### Como queda entonces

| Capa | Responsabilidad | Conoce SwiftUI? | Se prueba? |
| --- | --- | --- | --- |
| `Models/` | Modelos `@Model` de SwiftData y enums de dominio | No | Si |
| `Services/` | Llamadas de red, parseo, mapeo DTO a dominio | No | Si, es la capa mas probada |
| `ViewModels/` | Estado de carga y error, orquestacion, logica de UI | No (solo `Observation`) | Si |
| `Views/` | Presentacion y lecturas simples con `@Query` | Si | No unitariamente |

**Lecturas simples van directo con `@Query`.** Mostrar la lista de juegos
guardados, filtrarla, ordenarla: eso es exactamente para lo que existe `@Query`
y meterle un ViewModel encima solo agrega ruido.

**Todo lo demas pasa por un ViewModel.** Sincronizar con Steam, manejar el
estado de "cargando / error / vacio", decidir si una sesion de juego puede
iniciarse: eso es logica que puede romperse, y por lo tanto es logica que
necesita prueba unitaria. No puede vivir dentro de una vista.

## Reglas

1. **Una vista nunca llama a un `Service` directamente.** Siempre pasa por un
   ViewModel. Si una vista importa un Service, es un error de revision.
2. **Una vista si puede usar `@Query`** para leer modelos locales de SwiftData.
   Eso no viola la arquitectura, es usar el framework como fue diseñado.
3. **Los `Services` no importan SwiftUI.** Si un Service necesita SwiftUI, algo
   se puso en la capa equivocada.
4. **Los `Services` se definen como protocolo**, para poder inyectar un doble en
   las pruebas y no depender de la red real.
5. **Los DTOs nunca se guardan.** Las respuestas de red son structs `Codable`
   que viven en `Services/`, y se mapean a modelos `@Model` antes de persistir.
   Nunca se marca un DTO con `@Model`.
6. **Los ViewModels no conocen la red.** Reciben un Service por inyeccion; no
   construyen URLs ni parsean JSON.

## Alternativas consideradas

**MVVM puro (todo pasa por ViewModel, sin `@Query`).**
Mas consistente conceptualmente, pero pelea contra SwiftData en vez de usarlo:
habria que replicar a mano el refresco automatico de la UI. Mas codigo, mas
bugs, sin ganancia real de testabilidad porque las lecturas simples no tienen
logica que probar. Rechazada.

**Sin ViewModels (patron "MV", que es lo que muestra Apple en sus ejemplos).**
Mas simple y muy idiomatico con SwiftUI. Rechazada porque deja la logica de red
y de sincronizacion dentro de las vistas, y este proyecto tiene como requisito
poder probar esa logica sin levantar interfaz.

**TCA (The Composable Architecture).**
Excelente testabilidad y unidireccionalidad. Rechazada por dos razones: es una
dependencia externa grande para un proyecto que quiere mantenerse simple, y es
una curva de aprendizaje muy pronunciada para un primer proyecto en el
ecosistema Apple. El objetivo aqui es aprender los frameworks de Apple, no una
abstraccion encima de ellos.

## Consecuencias

**A favor:**
- La logica de red y de negocio se prueba sin instanciar una sola vista.
- Se aprovecha `@Query` y su refresco automatico, que es lo que hace agradable
  trabajar con SwiftData.
- Cambiar de API (o que Sony rompa la suya) solo afecta `Services/`.

**En contra:**
- La regla "cuando va ViewModel y cuando no" requiere criterio, no es mecanica.
  El corte practico es: **si tiene logica que puede romperse, va en ViewModel.**
- Conviven dos formas de acceder a datos, lo que puede confundir al principio.
  El costo se acepta a cambio de no pelear contra el framework.

## Estructura de carpetas

```
GameShelf/
├── GameShelfApp.swift      Punto de entrada, configura el ModelContainer
├── Models/                 Modelos @Model y enums de dominio
├── Services/               Clientes de red, DTOs y mapeadores
├── ViewModels/             Estado y orquestacion, marcados con @Observable
├── Views/                  Vistas de SwiftUI
├── Extensions/             Extensiones de tipos propios y del sistema
└── Resources/              Assets y otros recursos
```

`GameShelfApp.swift` se queda en la raiz del target a proposito: es el punto de
entrada y no pertenece a ninguna capa.

### Nota sobre carpetas vacias

El proyecto usa **carpetas sincronizadas** de Xcode 16+
(`PBXFileSystemSynchronizedRootGroup`): lo que existe en disco aparece
automaticamente en Xcode, sin tener que registrar cada archivo en el
`.xcodeproj`.

El efecto secundario es que Xcode trata cualquier archivo que no sea codigo
como un recurso a copiar al bundle. Poner un `.gitkeep` en cada carpeta para
versionarlas vacias hace fallar la compilacion, porque los cinco archivos se
llaman igual y colisionan en el mismo destino:

```
error: Multiple commands produce '.../GameShelf.app/.gitkeep'
```

Se puede resolver declarando `membershipExceptions` en el `.xcodeproj`, pero
eso agrega complejidad al build a cambio de versionar carpetas vacias que se
van a llenar en los siguientes issues. Se decidio no hacerlo: git no versiona
carpetas vacias, y cada carpeta entra al repositorio cuando recibe su primer
archivo real. La estructura de referencia es la de este documento.
