//
//  EpicLibraryDTOs.swift
//  GameShelf
//

import Foundation

// MARK: - Biblioteca

/// Respuesta de `library/api/public/items`.
///
/// Viene paginada: mientras `nextCursor` traiga algo, faltan mas.
struct EpicLibraryResponse: Decodable, Sendable {
  let records: [EpicLibraryRecordDTO]?
  let responseMetadata: EpicResponseMetadataDTO?

  var registros: [EpicLibraryRecordDTO] { records ?? [] }
  var siguienteCursor: String? {
    let cursor = responseMetadata?.nextCursor
    return cursor?.isEmpty == false ? cursor : nil
  }
}

struct EpicResponseMetadataDTO: Decodable, Sendable {
  let nextCursor: String?
}

/// Una entrada de la biblioteca de Epic.
///
/// **No es un juego, es un artefacto.** Un mismo juego aparece varias veces:
/// el ejecutable, sus DLC, sus editores... En la biblioteca real, Ark salia 6
/// veces y Cyberpunk 4. Lo que agrupa a todos es el `namespace`.
struct EpicLibraryRecordDTO: Decodable, Sendable {
  /// Identifica al **juego**. Se comprobo con la biblioteca real que cada
  /// namespace tiene un unico nombre, asi que sirve de identificador estable.
  let namespace: String

  let catalogItemId: String?

  /// Identifica al **artefacto** dentro del juego. Es la clave con la que se
  /// emparejan los tiempos jugados.
  let appName: String?

  /// Nombre legible del juego. En la biblioteca real venia en todos.
  let sandboxName: String?

  let recordType: String?

  /// Si el nombre sirve para mostrarlo.
  ///
  /// Epic pone `"Live"` en unos cuantos, casi todos regalos semanales, y ahi
  /// no dice nada del juego. Esos hay que resolverlos contra el catalogo.
  var tieneNombreUtil: Bool {
    guard let sandboxName, !sandboxName.isEmpty else { return false }
    return sandboxName != Self.nombreSinResolver
  }

  /// El valor que pone Epic cuando el sandbox no tiene nombre propio.
  static let nombreSinResolver = "Live"
}

// MARK: - Tiempo jugado

/// Una entrada de `playtime/account/{id}/all`.
///
/// El tiempo va por artefacto, no por juego, y **el mismo tiempo aparece
/// repetido bajo varios artefactos del mismo juego**: Cyberpunk reportaba
/// 49,8 h dos veces, con ids distintos. Por eso al juntarlos se toma el mayor
/// y no la suma, que daria el doble.
struct EpicPlaytimeDTO: Decodable, Sendable {
  let artifactId: String
  let totalTime: Int?

  var horas: Double { Double(totalTime ?? 0) / 3600 }
}

// MARK: - Catalogo

/// Respuesta de `catalog/api/shared/namespace/{ns}/bulk/items`.
///
/// Es un diccionario con el `catalogItemId` como clave. Aporta el nombre de
/// verdad y la caratula, que la biblioteca no trae.
struct EpicCatalogResponse: Decodable, Sendable {
  let items: [String: EpicCatalogItemDTO]

  init(from decoder: Decoder) throws {
    let contenedor = try decoder.singleValueContainer()
    items = try contenedor.decode([String: EpicCatalogItemDTO].self)
  }
}

struct EpicCatalogItemDTO: Decodable, Sendable {
  let title: String?
  let keyImages: [EpicKeyImageDTO]?

  /// La caratula vertical, que es la que encaja con el resto de la app.
  ///
  /// Si no esta, sirve la apaisada: mejor una imagen con otra proporcion que
  /// un hueco gris.
  var coverURL: URL? {
    let preferidas = ["DieselGameBoxTall", "OfferImageTall", "DieselGameBox", "OfferImageWide"]
    for tipo in preferidas {
      if let imagen = keyImages?.first(where: { $0.type == tipo }),
         let url = imagen.url.flatMap(URL.init(string:)) {
        return url
      }
    }
    return keyImages?.first?.url.flatMap(URL.init(string:))
  }
}

struct EpicKeyImageDTO: Decodable, Sendable {
  let type: String?
  let url: String?
}
