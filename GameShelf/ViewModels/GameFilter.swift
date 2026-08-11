//
//  GameFilter.swift
//  GameShelf
//

import Foundation

/// Que juegos se muestran.
///
/// Cada campo es un conjunto de valores permitidos. Un conjunto **vacio** no
/// filtra nada: significa "cualquiera", no "ninguno". Asi el filtro por defecto
/// muestra toda la biblioteca.
///
/// Entre categorias se aplica Y (tienda **y** estado), pero dentro de una
/// categoria se aplica O (Steam **o** PSN). Es lo que espera cualquiera al
/// marcar dos casillas de la misma lista.
struct GameFilter: Equatable, Sendable {
  var stores: Set<Store> = []
  var statuses: Set<PlayStatus> = []
  var collectionIDs: Set<UUID> = []
  var tagIDs: Set<UUID> = []

  static let none = GameFilter()

  /// Si hay algun filtro puesto.
  var isActive: Bool {
    !stores.isEmpty || !statuses.isEmpty || !collectionIDs.isEmpty || !tagIDs.isEmpty
  }

  /// Cuantos criterios hay puestos en total. Sirve para el contador del boton.
  var activeCount: Int {
    stores.count + statuses.count + collectionIDs.count + tagIDs.count
  }

  /// Quita todos los filtros.
  mutating func clear() {
    self = .none
  }

  /// Si un juego pasa el filtro.
  func matches(_ juego: Game) -> Bool {
    cumpleTienda(juego)
      && cumpleEstado(juego)
      && cumpleColeccion(juego)
      && cumpleEtiqueta(juego)
  }

  /// Aplica el filtro a una lista.
  func apply(to juegos: [Game]) -> [Game] {
    guard isActive else { return juegos }
    return juegos.filter(matches)
  }

  // MARK: - Cada criterio

  private func cumpleTienda(_ juego: Game) -> Bool {
    guard !stores.isEmpty else { return true }
    return juego.storeEntries.contains { stores.contains($0.store) }
  }

  private func cumpleEstado(_ juego: Game) -> Bool {
    guard !statuses.isEmpty else { return true }
    return statuses.contains(juego.status)
  }

  private func cumpleColeccion(_ juego: Game) -> Bool {
    guard !collectionIDs.isEmpty else { return true }
    return juego.collections.contains { collectionIDs.contains($0.id) }
  }

  private func cumpleEtiqueta(_ juego: Game) -> Bool {
    guard !tagIDs.isEmpty else { return true }
    return juego.tags.contains { tagIDs.contains($0.id) }
  }
}

/// Lo que hay que aplicar para obtener la lista que se ve: buscar, filtrar y
/// ordenar.
///
/// Se junta en un solo tipo para que el orden de las operaciones sea siempre el
/// mismo y este probado, en vez de repartirlo por la vista.
struct GameQuery: Equatable, Sendable {
  var search: String = ""
  var filter: GameFilter = .none
  var sort: GameSortOrder = .default

  /// Aplica todo, en este orden: filtrar, buscar y ordenar.
  ///
  /// El orden importa. Buscar va antes de ordenar porque la busqueda ya ordena
  /// por relevancia, y ese resultado se reemplaza a proposito por el orden que
  /// eligio el usuario: si pidio "mas jugados", eso es lo que quiere ver,
  /// tambien entre los resultados de la busqueda.
  func apply(to juegos: [Game]) -> [Game] {
    let filtrados = filter.apply(to: juegos)
    let buscados = GameSearch.filter(filtrados, query: search)
    return sort.sort(buscados)
  }

  /// Si hay algo puesto que reduzca la lista.
  var isNarrowing: Bool {
    filter.isActive || !search.normalizedForSearch.isEmpty
  }
}
