//
//  WishlistViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Orquesta la lista de deseos: sincronizarla con Steam y agregar juegos a mano.
///
/// Sigue la misma idea que `LibraryViewModel`: no entrega los juegos a la
/// vista (de eso se encarga `@Query`), solo se ocupa de lo que puede fallar.
///
/// Ver `docs/decisiones/001-arquitectura.md`.
@Observable
@MainActor
final class WishlistViewModel {

  /// En que punto esta la sincronizacion.
  enum State: Equatable {
    case idle
    case syncing
    /// Termino bien.
    case succeeded(created: Int, updated: Int, removed: Int)
    /// Fallo, con un mensaje que se puede mostrar tal cual.
    case failed(message: String, suggestion: String?)

    var isSyncing: Bool { self == .syncing }
    var hasAttempted: Bool { self != .idle }
  }

  private(set) var state: State = .idle

  /// Cuando termino la ultima sincronizacion correcta.
  private(set) var lastSyncedAt: Date?

  /// Si la ultima sincronizacion correcta no trajo ningun juego.
  ///
  /// Steam responde igual cuando la lista esta vacia y cuando es privada, asi
  /// que esto no significa "es privada": significa "no vino nada", y la vista
  /// explica las dos posibilidades.
  private(set) var lastSyncReturnedNoGames = false

  private let service: SteamWishlistServicing
  private let defaults: UserDefaults

  private static let lastSyncKey = "wishlist.lastSyncedAt"

  init(service: SteamWishlistServicing, defaults: UserDefaults = .standard) {
    self.service = service
    self.defaults = defaults
    self.lastSyncedAt = defaults.object(forKey: Self.lastSyncKey) as? Date
  }

  /// Crea el ViewModel con el servicio real.
  ///
  /// Si falta el SteamID no lanza: deja el estado listo para fallar con las
  /// instrucciones cuando se intente sincronizar.
  static func live() -> WishlistViewModel {
    do {
      return WishlistViewModel(service: try SteamWishlistService.live())
    } catch {
      return WishlistViewModel(service: UnavailableWishlistService(error: error))
    }
  }

  /// Trae la lista de deseos de Steam y la guarda.
  ///
  /// No propaga errores: los deja en `state`. Un fallo **no borra** lo que ya
  /// estaba guardado.
  func sync(into context: ModelContext) async {
    guard !state.isSyncing else { return }

    state = .syncing

    do {
      let juegos = try await service.fetchWishlist()

      // Si no vino nada, no se quita nada: puede que la lista sea privada, y
      // vaciar la wishlist del usuario por una respuesta ambigua seria el peor
      // de los errores posibles.
      let resultado = try SteamWishlistSyncer.sync(
        juegos,
        into: context,
        allowRemovals: !juegos.isEmpty
      )

      lastSyncReturnedNoGames = juegos.isEmpty
      registrarSincronizacion(at: Date())
      state = .succeeded(
        created: resultado.created,
        updated: resultado.updated,
        removed: resultado.removed
      )
    } catch let error as NetworkError {
      state = .failed(
        message: error.errorDescription ?? String(localized: "No se pudo sincronizar.", comment: "Error generico"),
        suggestion: error.recoverySuggestion
      )
    } catch let error as AppSecrets.MissingSecretError {
      state = .failed(
        message: error.errorDescription
          ?? String(localized: "Falta configurar las claves.", comment: "Error generico de configuracion"),
        suggestion: error.recoverySuggestion
      )
    } catch {
      state = .failed(message: error.localizedDescription, suggestion: nil)
    }
  }

  // MARK: - Agregar a mano

  /// Por que no se pudo agregar un juego a mano.
  enum ValidationError: LocalizedError, Equatable {
    case emptyName
    case duplicateName(String)

    var errorDescription: String? {
      switch self {
      case .emptyName:
        String(localized: "El nombre no puede estar vacio.", comment: "Error al nombrar una coleccion")
      case .duplicateName(let nombre):
        String(
          localized: "Ya tienes \"\(nombre)\" en tu biblioteca.",
          comment: "Error: el juego ya existe"
        )
      }
    }
  }

  /// Agrega un juego a la lista de deseos sin pasar por Steam.
  ///
  /// Es el respaldo para cuando el endpoint de wishlist se rompa, y tambien
  /// sirve para juegos que no estan en Steam.
  ///
  /// - Returns: El juego creado.
  /// - Throws: `ValidationError` si el nombre esta vacio o repetido.
  @discardableResult
  func addManually(name: String, in context: ModelContext) throws -> Game {
    let limpio = name.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !limpio.isEmpty else { throw ValidationError.emptyName }

    // La comparacion ignora mayusculas y tildes, la misma regla que usan la
    // busqueda y las etiquetas: agregar "elden ring" teniendo "Elden Ring" no
    // deberia crear un segundo juego.
    let buscado = limpio.normalizedForSearch
    let existentes = try context.fetch(FetchDescriptor<Game>())
    if let repetido = existentes.first(where: { $0.name.normalizedForSearch == buscado }) {
      throw ValidationError.duplicateName(repetido.name)
    }

    let juego = Game(name: limpio, status: .wishlist)
    context.insert(juego)
    try context.save()
    return juego
  }

  /// Si un juego se puede quitar de la lista desde la app.
  ///
  /// Solo los que agregaste a mano. Los que vienen de Steam se quitan en
  /// Steam: borrarlos aca no serviria de nada porque la siguiente
  /// sincronizacion los traeria de vuelta, y prometer una accion que se
  /// deshace sola es peor que no ofrecerla.
  nonisolated static func canDelete(_ juego: Game) -> Bool {
    juego.storeEntries.isEmpty
  }

  /// Borra un juego agregado a mano.
  ///
  /// - Throws: Si el juego viene de una tienda, o si falla el guardado.
  func delete(_ juego: Game, in context: ModelContext) throws {
    guard Self.canDelete(juego) else { return }
    context.delete(juego)
    try context.save()
  }

  private func registrarSincronizacion(at fecha: Date) {
    lastSyncedAt = fecha
    defaults.set(fecha, forKey: Self.lastSyncKey)
  }
}

/// Servicio que solo sabe fallar, con el motivo original.
///
/// Se usa cuando no se pudo leer el SteamID: asi la pantalla abre y explica el
/// problema en vez de caerse.
private struct UnavailableWishlistService: SteamWishlistServicing {
  let error: Error

  func fetchWishlist() async throws -> [SteamWishlistGame] {
    throw error
  }
}
