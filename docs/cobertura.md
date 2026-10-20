# Cobertura de pruebas

Que parte del codigo ejercitan las pruebas, que queda fuera y por que.

## Como se mide

- El scheme compartido (`GameShelf`) genera cobertura de lineas, **solo del
  target de la app**: las pruebas no se cuentan a si mismas.
- CI corre `scripts/revisar-cobertura.py` sobre el `.xcresult` de las pruebas.
  Calcula la cobertura de dos capas por separado, segun su carpeta:
  `GameShelf/Services` y `GameShelf/Models`.
- **El minimo es 70 % en cada capa.** Si una baja, CI falla. La tabla de cada
  run queda en el resumen del trabajo "Compilar y probar".
- Vistas y ViewModels no cuentan para el minimo. Las vistas de SwiftUI no
  llevan prueba unitaria (CONTRIBUTING), y el minimo vigila la logica que mas
  se puede romper.

Para verlo en local: en Xcode, despues de correr las pruebas, el *Report
navigator* (⌘9) tiene la pestana *Coverage*. O, sobre un `.xcresult`:

```
python3 scripts/revisar-cobertura.py ruta/al/Pruebas.xcresult
```

## Donde estamos

Medido en CI el 20 de octubre de 2026, sobre `main` en `c97d054` (con la
autenticacion de Xbox, sin su biblioteca):

| Capa | Lineas cubiertas | Porcentaje |
| --- | --- | --- |
| Servicios | 1901 de 2251 | 84,5 % |
| Modelos | 240 de 263 | 91,3 % |

No se persigue el 100 %: lo que sigue es lo que queda sin cubrir, y por que
se deja asi.

## Lo que queda sin cubrir

### Los transportes reales (`XboxAuthTransport` 5,9 %, `PSNAuthTransport` 34,1 %)

Son la capa que manda los formularios de inicio de sesion por `URLSession`.
Las pruebas de autenticacion (`PSNAuthTests`, `EpicAuthTests`,
`XboxAuthTests`) no pasan por ellos a proposito: inyectan un transporte falso
y prueban lo que importa, que es como se interpreta cada respuesta. Del de
PSN se prueba ademas la funcion que codifica el formulario; del de Xbox, casi
nada.

Lo que queda fuera es armar la `URLRequest` (metodo, cabeceras, cuerpo) y
traducir los `URLError` a `NetworkError`. Es poco codigo y casi sin ramas.
**Es lo mas barato de cubrir si hiciera falta:** `URLProtocolStub`, que ya
usan las pruebas de `HTTPClient`, sirve igual para estos dos.

### El cliente HTTP real (`HTTPClient.swift`, 54,8 %)

`URLSessionHTTPClient` si se prueba contra un `URLProtocol` falso (la suite
"Cliente HTTP (peticion real, sin red)"): pide, decodifica y traduce los
codigos de error. Lo que no se cubre son los mensajes para cada tipo de
`DecodingError` (`typeMismatch`, `valueNotFound`, `dataCorrupted`) y el error
al codificar un cuerpo, que solo pasaria con un tipo `Encodable` roto. Son
textos de depuracion, y los dos caminos ya terminan en el mismo
`NetworkError.decodingFailed`, que si esta probado.

### La biblioteca de Epic de punta a punta (`EpicLibraryService.swift`, 57 %)

Lo delicado de Epic esta probado contra respuestas reales guardadas: agrupar
los artefactos por `namespace`, quedarse con el mayor tiempo y no con la suma,
preferir el nombre util, armar las URLs y que fallen los tiempos sin tumbar
nada. Lo que no se cubre es `fetchOwnedGames` encadenando las tres consultas
(biblioteca, tiempos y catalogo) en una sola prueba, ni que siga pidiendo
paginas mientras Epic mande un cursor. Una prueba de ese recorrido completo necesitaria un doble que
responda distinto por URL, como el que ya usa la lista de deseos
(`RoutingHTTPClient`). Es la siguiente que vale la pena escribir.

### El validador de credenciales de Steam (`SteamCredentialsValidating.swift`, 50 %)

`SteamAPICredentialsValidator` es una linea: pide la biblioteca y descarta el
resultado. Las pruebas de la pantalla de Steam usan un validador falso, y la
peticion que hace ya esta probada en `SteamServiceTests`.

### Los nombres para mostrar (`CollectionColor.swift` y `Store.swift`, 0 %)

Son los `displayName`: un `switch` que devuelve el texto de cada caso. Las
pruebas de traducciones no los llaman a proposito: buscan las claves en
espanol directamente en cada idioma, porque `displayName` ya sale traducido al
idioma del simulador y la prueba dejaria de comprobar la traduccion (ver
`LocalizationTests`). El compilador comprueba que el `switch` cubra todos los
casos; que cada uno devuelva su propio texto es lo unico que queda sin probar,
y salta a la vista en cuanto se abre el selector de color o el filtro por
tienda.

### El resto

Lo demas que falta son ramas de respaldo de los DTOs (`PSNLibraryDTOs` 82 %,
`EpicLibraryDTOs` 83 %) y de `Money` (75 %): campos que la API casi nunca deja
de mandar. Las respuestas reales guardadas pasan por el camino normal, y los
casos raros que si se vieron en datos reales ya tienen su prueba.

## Cuando subir el minimo

El 70 % es un piso, no una meta. Si una capa se queda muy por encima durante
un tiempo, subirlo protege lo ganado. Y si un PR la baja, el CI lo dice antes
de fusionarlo.
