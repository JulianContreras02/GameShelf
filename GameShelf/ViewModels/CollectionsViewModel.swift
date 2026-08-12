//
//  CollectionsViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Crea, edita, borra y reordena colecciones.
///
/// Aca vive lo que puede salir mal: validar el nombre y mantener el orden
/// coherente. Las vistas leen con `@Query` y llaman a estos metodos para
/// cambiar cosas. Ver `docs/decisiones/001-arquitectura.md`.
@Observable
@MainActor
final class CollectionsViewModel {

  /// Por que se rechazo un nombre.
  enum ValidationError: LocalizedError, Equatable {
    case emptyName
    case duplicateName(String)
    case tooLong(max: Int)

    var errorDescription: String? {
      switch self {
      case .emptyName:
        String(localized: "El nombre no puede estar vacio.", comment: "Error al nombrar una coleccion")
      case .duplicateName(let nombre):
        String(
          localized: "Ya tienes una coleccion llamada \"\(nombre)\".",
          comment: "Error: ya existe una coleccion con ese nombre"
        )
      case .tooLong(let max):
        String(
          localized: "El nombre no puede pasar de \(max) caracteres.",
          comment: "Error: nombre de coleccion demasiado largo"
        )
      }
    }
  }

  /// Limite del nombre. Uno muy largo se recorta en pantalla y no se distingue
  /// de otro parecido.
  static let maxNameLength = 40

  /// Simbolos entre los que elegir. Lista curada: un selector con todos los SF
  /// Symbols seria inmanejable.
  static let availableSymbols = [
    "folder", "star", "heart", "flag", "bookmark", "tag",
    "gamecontroller", "trophy", "crown", "flame", "bolt", "sparkles",
    "moon", "sun.max", "leaf", "cube", "puzzlepiece", "dice"
  ]

  init() {}

  // MARK: - Crear

  /// Crea una coleccion al final de la lista.
  ///
  /// - Throws: `ValidationError` si el nombre esta vacio, repetido o es muy largo.
  @discardableResult
  func create(
    name: String,
    symbolName: String = GameCollection.defaultSymbol,
    color: CollectionColor = .default,
    in context: ModelContext
  ) throws -> GameCollection {
    let limpio = try validar(name, in: context)

    let coleccion = GameCollection(
      name: limpio,
      symbolName: symbolName,
      color: color,
      sortOrder: try siguienteOrden(in: context)
    )
    context.insert(coleccion)
    try context.save()
    return coleccion
  }

  // MARK: - Editar

  /// Cambia el nombre.
  ///
  /// - Throws: `ValidationError` si el nombre no sirve. Un nombre repetido se
  ///   permite si es el de la propia coleccion (renombrar sin cambiar nada).
  func rename(
    _ coleccion: GameCollection,
    to nuevoNombre: String,
    in context: ModelContext
  ) throws {
    let limpio = try validar(nuevoNombre, in: context, ignorando: coleccion)
    coleccion.name = limpio
    try context.save()
  }

  /// Cambia simbolo y color. No hay nada que validar aca.
  func updateAppearance(
    _ coleccion: GameCollection,
    symbolName: String,
    color: CollectionColor,
    in context: ModelContext
  ) throws {
    coleccion.symbolName = symbolName
    coleccion.color = color
    try context.save()
  }

  // MARK: - Borrar

  /// Borra la coleccion.
  ///
  /// Los juegos que contenia **no se borran**: solo se deshace la agrupacion.
  /// Lo garantiza la regla de borrado del modelo.
  func delete(_ coleccion: GameCollection, in context: ModelContext) throws {
    context.delete(coleccion)
    try context.save()
    try renumerar(in: context)
  }

  // MARK: - Asignar juegos

  /// Mete o saca un juego de una coleccion, segun donde este.
  ///
  /// - Returns: `true` si quedo dentro, `false` si quedo fuera.
  @discardableResult
  func toggle(
    _ juego: Game,
    in coleccion: GameCollection,
    context: ModelContext
  ) throws -> Bool {
    let estaba = coleccion.contains(juego)
    if estaba {
      coleccion.remove(juego)
    } else {
      coleccion.add(juego)
    }
    try context.save()
    return !estaba
  }

  /// Agrega varios juegos a una coleccion de una sola vez.
  ///
  /// Los que ya estaban no se duplican ni se cuentan.
  ///
  /// - Returns: Cuantos se agregaron de verdad.
  @discardableResult
  func add(
    _ juegos: [Game],
    to coleccion: GameCollection,
    context: ModelContext
  ) throws -> Int {
    let nuevos = juegos.filter { !coleccion.contains($0) }
    for juego in nuevos {
      coleccion.add(juego)
    }
    try context.save()
    return nuevos.count
  }

  /// Quita varios juegos de una coleccion. Los juegos no se borran.
  ///
  /// - Returns: Cuantos se quitaron de verdad.
  @discardableResult
  func remove(
    _ juegos: [Game],
    from coleccion: GameCollection,
    context: ModelContext
  ) throws -> Int {
    let presentes = juegos.filter { coleccion.contains($0) }
    for juego in presentes {
      coleccion.remove(juego)
    }
    try context.save()
    return presentes.count
  }

  // MARK: - Reordenar

  /// Mueve colecciones dentro de la lista y reescribe su orden.
  ///
  /// - Parameters:
  ///   - colecciones: La lista tal como se ve, ya ordenada.
  ///   - origen: Indices que se arrastran, tal como los da SwiftUI.
  ///   - destino: Posicion de destino, tal como la da SwiftUI.
  func move(
    _ colecciones: [GameCollection],
    from origen: IndexSet,
    to destino: Int,
    in context: ModelContext
  ) throws {
    let reordenadas = Self.reordenar(colecciones, from: origen, to: destino)

    for (indice, coleccion) in reordenadas.enumerated() {
      coleccion.sortOrder = indice
    }
    try context.save()
  }

  /// Reordena una lista con la misma semantica que `onMove` de SwiftUI.
  ///
  /// Se implementa a mano en vez de usar `move(fromOffsets:toOffset:)` porque
  /// ese metodo lo aporta SwiftUI, y este tipo no debe depender de la interfaz.
  /// Ademas asi el reordenamiento se puede probar como logica pura.
  ///
  /// El detalle facil de equivocar: `destino` es la posicion **antes** de sacar
  /// los elementos, asi que hay que restarle cuantos de los movidos estaban por
  /// delante.
  static func reordenar<T>(_ items: [T], from origen: IndexSet, to destino: Int) -> [T] {
    let movidos = origen.sorted().map { items[$0] }

    var resultado = items
    for indice in origen.sorted(by: >) {
      resultado.remove(at: indice)
    }

    let porDelante = origen.filter { $0 < destino }.count
    let posicion = min(max(destino - porDelante, 0), resultado.count)
    resultado.insert(contentsOf: movidos, at: posicion)

    return resultado
  }

  // MARK: - Apoyo

  /// Limpia y comprueba un nombre.
  ///
  /// - Parameter ignorando: Coleccion que no cuenta al buscar repetidos, para
  ///   poder guardar una sin cambiarle el nombre.
  private func validar(
    _ nombre: String,
    in context: ModelContext,
    ignorando: GameCollection? = nil
  ) throws -> String {
    let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !limpio.isEmpty else { throw ValidationError.emptyName }
    guard limpio.count <= Self.maxNameLength else {
      throw ValidationError.tooLong(max: Self.maxNameLength)
    }

    let existentes = try context.fetch(FetchDescriptor<GameCollection>())
    let repetido = existentes.contains { otra in
      otra.id != ignorando?.id
        && otra.name.compare(limpio, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    guard !repetido else { throw ValidationError.duplicateName(limpio) }
    return limpio
  }

  /// Orden que le toca a una coleccion nueva: al final de la lista.
  private func siguienteOrden(in context: ModelContext) throws -> Int {
    let existentes = try context.fetch(FetchDescriptor<GameCollection>())
    return (existentes.map(\.sortOrder).max() ?? -1) + 1
  }

  /// Deja el orden en 0, 1, 2... sin huecos.
  ///
  /// Despues de borrar quedan saltos, y aunque no se noten en pantalla,
  /// arrastrando se vuelven inconsistentes.
  private func renumerar(in context: ModelContext) throws {
    let ordenadas = try context
      .fetch(FetchDescriptor<GameCollection>())
      .sorted { $0.sortOrder < $1.sortOrder }

    for (indice, coleccion) in ordenadas.enumerated() {
      coleccion.sortOrder = indice
    }
    try context.save()
  }
}
