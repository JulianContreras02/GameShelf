//
//  LibraryMatcher.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Encuentra si un juego que llega de una tienda ya esta guardado.
///
/// Es la deduplicacion que hace que tener varias tiendas sirva de algo: si
/// Red Dead Redemption 2 esta en Steam y en PlayStation, la biblioteca muestra
/// **un** juego con las horas de los dos, no dos filas repetidas.
///
/// Vive aparte porque la usan todos los conectores menos Steam. Estaba escrita
/// dentro del sincronizador de PSN y copiarla para Epic habria sido la tercera
/// version de la misma idea.
///
/// Pasar a una cuarta tienda (Xbox) no cambio la idea: cada sincronizacion
/// mira su propia tienda por id y todas las demas por nombre, sean las que
/// sean. Lo que si cambio es el nombre, ver `clave(de:)`.
struct LibraryMatcher {

  /// Entradas de la tienda que se esta sincronizando, por su id.
  private let porIDDeTienda: [String: StoreEntry]

  /// Todos los juegos guardados, por su nombre normalizado.
  private var porNombre: [String: Game]

  /// Prepara los indices de una vez.
  ///
  /// Se indexa en memoria en vez de consultar juego por juego: es mas rapido y
  /// evita pelear con los predicados de SwiftData sobre enums.
  init(store: Store, context: ModelContext) throws {
    let entradas = try context.fetch(FetchDescriptor<StoreEntry>())
    porIDDeTienda = entradas
      .filter { $0.store == store }
      .reduce(into: [:]) { indice, entrada in
        // Si hubiera duplicados por un fallo previo, gana el primero: asi no
        // se crean todavia mas copias.
        if indice[entrada.storeGameID] == nil {
          indice[entrada.storeGameID] = entrada
        }
      }

    let juegos = try context.fetch(FetchDescriptor<Game>())
    porNombre = juegos.reduce(into: [:]) { indice, juego in
      let clave = Self.clave(de: juego.name)
      if indice[clave] == nil {
        indice[clave] = juego
      }
    }
  }

  /// Como se reconocio un juego que llega.
  enum Coincidencia {
    /// Ya estaba, y con esta misma tienda.
    case mismaTienda(Game)
    /// Ya estaba, pero venido de otra tienda. Hay que sumarle esta.
    case otraTienda(Game)
    /// No estaba: hay que crearlo.
    case nuevo
  }

  /// Busca un juego por su id de tienda y, si no, por su nombre.
  ///
  /// La comparacion por nombre ignora mayusculas y tildes, la misma regla que
  /// usan la busqueda y las etiquetas, y ademas las marcas registradas.
  func buscar(storeGameID: String, nombre: String) -> Coincidencia {
    if let entrada = porIDDeTienda[storeGameID], let juego = entrada.game {
      return .mismaTienda(juego)
    }
    if let juego = porNombre[Self.clave(de: nombre)] {
      return .otraTienda(juego)
    }
    return .nuevo
  }

  /// Registra un juego recien creado, para que el siguiente de la misma tanda
  /// lo encuentre en vez de crear otro igual.
  mutating func registrar(_ juego: Game) {
    porNombre[Self.clave(de: juego.name)] = juego
  }

  /// La forma del nombre con la que se comparan las tiendas.
  ///
  /// Ademas de mayusculas y tildes, ignora ™, ® y ©. Xbox se los pone a
  /// muchos nombres ("Assassin's Creed® Syndicate") y cada tienda decide por
  /// su lado si los usa: por un simbolo, el mismo juego saldria dos veces en
  /// la biblioteca.
  ///
  /// No va dentro de `normalizedForSearch` porque eso es lo que usan tambien
  /// la busqueda y las etiquetas, y este ajuste solo tiene sentido aca.
  static func clave(de nombre: String) -> String {
    String(nombre.filter { !marcas.contains($0) }).normalizedForSearch
  }

  private static let marcas: Set<Character> = ["™", "®", "©"]
}
