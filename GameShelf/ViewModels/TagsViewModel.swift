//
//  TagsViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Crea, asigna y borra etiquetas.
///
/// Lo importante que resuelve: que escribir "RPG" en un juego y "rpg" en otro
/// no cree dos etiquetas distintas.
@Observable
@MainActor
final class TagsViewModel {

  enum ValidationError: LocalizedError, Equatable {
    case emptyName
    case tooLong(max: Int)

    var errorDescription: String? {
      switch self {
      case .emptyName:
        String(localized: "La etiqueta no puede estar vacia.", comment: "Error al crear una etiqueta")
      case .tooLong(let max):
        String(
          localized: "La etiqueta no puede pasar de \(max) caracteres.",
          comment: "Error al crear una etiqueta demasiado larga"
        )
      }
    }
  }

  init() {}

  // MARK: - Crear y asignar

  /// Devuelve la etiqueta con ese nombre, y la crea si no existe.
  ///
  /// La comparacion ignora mayusculas y tildes, asi que "RPG" encuentra una
  /// "rpg" que ya existiera y **no** crea una segunda.
  ///
  /// - Throws: `ValidationError` si el nombre esta vacio o es muy largo.
  func findOrCreate(named nombre: String, in context: ModelContext) throws -> GameTag {
    let limpio = try validar(nombre)

    if let existente = try buscar(limpio, in: context) {
      return existente
    }

    let nueva = GameTag(name: limpio)
    context.insert(nueva)
    return nueva
  }

  /// Le pone una etiqueta a un juego, creandola si hace falta.
  ///
  /// Si el juego ya la tenia, no hace nada.
  ///
  /// - Returns: La etiqueta, exista o recien creada.
  @discardableResult
  func addTag(
    named nombre: String,
    to juego: Game,
    in context: ModelContext
  ) throws -> GameTag {
    let etiqueta = try findOrCreate(named: nombre, in: context)

    if !juego.tags.contains(where: { $0.id == etiqueta.id }) {
      juego.tags.append(etiqueta)
    }
    try context.save()
    return etiqueta
  }

  // MARK: - Quitar

  /// Le quita una etiqueta a un juego.
  ///
  /// Si con eso la etiqueta se queda sin ningun juego, se borra: una etiqueta
  /// que no usa nadie solo estorbaria en el autocompletado.
  func removeTag(_ etiqueta: GameTag, from juego: Game, in context: ModelContext) throws {
    juego.tags.removeAll { $0.id == etiqueta.id }

    if etiqueta.isOrphan {
      context.delete(etiqueta)
    }
    try context.save()
  }

  /// Borra una etiqueta y la quita de todos los juegos que la tuvieran.
  ///
  /// Los juegos no se borran: la regla de la relacion es `nullify`.
  func delete(_ etiqueta: GameTag, in context: ModelContext) throws {
    context.delete(etiqueta)
    try context.save()
  }

  /// Borra las etiquetas que no usa ningun juego.
  ///
  /// - Returns: Cuantas se borraron.
  @discardableResult
  func deleteOrphans(in context: ModelContext) throws -> Int {
    let huerfanas = try context.fetch(FetchDescriptor<GameTag>()).filter(\.isOrphan)
    for etiqueta in huerfanas {
      context.delete(etiqueta)
    }
    if !huerfanas.isEmpty {
      try context.save()
    }
    return huerfanas.count
  }

  // MARK: - Autocompletado

  /// Etiquetas que se pueden sugerir mientras se escribe.
  ///
  /// - Parameters:
  ///   - texto: Lo que lleva escrito el usuario. Vacio devuelve las mas usadas.
  ///   - juego: Sus etiquetas se excluyen: no tiene sentido sugerir una que ya
  ///     tiene puesta.
  ///   - limite: Cuantas devolver como maximo.
  func suggestions(
    for texto: String,
    excluding juego: Game?,
    in context: ModelContext,
    limit limite: Int = 8
  ) throws -> [GameTag] {
    let todas = try context.fetch(FetchDescriptor<GameTag>())
    return Self.suggestions(
      for: texto,
      from: todas,
      excluding: juego?.tags ?? [],
      limit: limite
    )
  }

  /// Version pura del autocompletado, para poder probarla sin base de datos.
  ///
  /// Ordena poniendo primero las que **empiezan** por lo escrito, y despues las
  /// que solo lo contienen. Dentro de cada grupo, las mas usadas primero.
  nonisolated static func suggestions(
    for texto: String,
    from todas: [GameTag],
    excluding puestas: [GameTag],
    limit limite: Int = 8
  ) -> [GameTag] {
    let buscado = GameTag.normalize(texto)
    let idsPuestas = Set(puestas.map(\.id))

    let candidatas = todas.filter { !idsPuestas.contains($0.id) }

    guard !buscado.isEmpty else {
      return Array(
        candidatas
          .sorted { ($0.gameCount, $1.normalized) > ($1.gameCount, $0.normalized) }
          .prefix(limite)
      )
    }

    let empiezan = candidatas.filter { $0.normalized.hasPrefix(buscado) }
    let contienen = candidatas.filter {
      !$0.normalized.hasPrefix(buscado) && $0.normalized.contains(buscado)
    }

    let ordenar: ([GameTag]) -> [GameTag] = { grupo in
      grupo.sorted {
        $0.gameCount != $1.gameCount
          ? $0.gameCount > $1.gameCount
          : $0.normalized < $1.normalized
      }
    }

    return Array((ordenar(empiezan) + ordenar(contienen)).prefix(limite))
  }

  /// Si el texto escrito daria una etiqueta nueva.
  ///
  /// Sirve para mostrar "Crear …" solo cuando de verdad no existe.
  nonisolated static func wouldCreateNew(_ texto: String, among todas: [GameTag]) -> Bool {
    let limpio = GameTag.clean(texto)
    guard !limpio.isEmpty else { return false }
    return !todas.contains { GameTag.areEquivalent($0.name, limpio) }
  }

  // MARK: - Apoyo

  private func validar(_ nombre: String) throws -> String {
    let limpio = GameTag.clean(nombre)

    guard !limpio.isEmpty else { throw ValidationError.emptyName }
    guard limpio.count <= GameTag.maxNameLength else {
      throw ValidationError.tooLong(max: GameTag.maxNameLength)
    }
    return limpio
  }

  private func buscar(_ nombre: String, in context: ModelContext) throws -> GameTag? {
    // Se filtra en memoria en vez de con un predicado: SwiftData no sabe
    // comparar ignorando tildes, que es justo lo que hace falta aca.
    try context
      .fetch(FetchDescriptor<GameTag>())
      .first { GameTag.areEquivalent($0.name, nombre) }
  }
}
