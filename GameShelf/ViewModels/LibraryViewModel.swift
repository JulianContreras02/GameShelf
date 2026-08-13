//
//  LibraryViewModel.swift
//  GameShelf
//

import Foundation
import SwiftData

/// Orquesta la sincronizacion de la biblioteca con Steam.
///
/// **No entrega los juegos a la vista**: de eso se encarga `@Query`, que ya
/// refresca la pantalla sola cuando cambian los datos. Este tipo existe para lo
/// que si puede fallar y por tanto necesita pruebas: llamar al servicio,
/// guardar el resultado y traducir los errores a algo que el usuario entienda.
///
/// Ver `docs/decisiones/001-arquitectura.md`.
@Observable
@MainActor
final class LibraryViewModel {

  /// En que punto esta la sincronizacion.
  ///
  /// Transiciones posibles:
  /// ```
  /// idle ─────────► syncing ──┬──► succeeded ──► syncing ──► ...
  ///                           └──► failed ─────► syncing ──► ...
  /// ```
  /// Nunca se pasa de `syncing` a `syncing`: las llamadas mientras hay una en
  /// curso se ignoran.
  enum State: Equatable {
    /// Todavia no se ha intentado nada en esta sesion.
    case idle
    /// Pidiendo datos a Steam.
    case syncing
    /// Termino bien.
    case succeeded(created: Int, updated: Int)
    /// Fallo, con un mensaje que se puede mostrar tal cual.
    case failed(message: String, suggestion: String?)

    var isSyncing: Bool { self == .syncing }

    /// Si ya se intentó sincronizar al menos una vez en esta sesion.
    var hasAttempted: Bool { self != .idle }
  }

  private(set) var state: State = .idle

  /// Cuando termino la ultima sincronizacion correcta.
  ///
  /// Se guarda entre sesiones para poder decirle al usuario que tan viejos son
  /// los datos que esta viendo cuando la red falla.
  private(set) var lastSyncedAt: Date?

  /// Si la ultima sincronizacion correcta no trajo ningun juego.
  ///
  /// Sirve para distinguir "todavia no has sincronizado" de "sincronizamos y
  /// Steam no devolvio nada", que para el usuario son problemas distintos.
  private(set) var lastSyncReturnedNoGames = false

  private let service: SteamServicing
  private let defaults: UserDefaults

  private static let lastSyncKey = "library.lastSyncedAt"

  init(service: SteamServicing, defaults: UserDefaults = .standard) {
    self.service = service
    self.defaults = defaults
    self.lastSyncedAt = defaults.object(forKey: Self.lastSyncKey) as? Date
  }

  /// Crea el ViewModel con el servicio real.
  ///
  /// Si faltan las claves de Steam, no lanza: deja el estado en `failed` con
  /// las instrucciones, porque una app que se cae al abrir es peor que una que
  /// explica que le falta.
  static func live() -> LibraryViewModel {
    do {
      return LibraryViewModel(service: try SteamService.live())
    } catch {
      return LibraryViewModel(service: UnavailableSteamService(error: error))
    }
  }

  /// Sincroniza solo si nunca se ha hecho.
  ///
  /// Se llama al abrir la pantalla: la primera vez trae la biblioteca sola, y
  /// despues no molesta en cada arranque. Para forzarla esta `sync`.
  func syncIfNeeded(into context: ModelContext) async {
    guard lastSyncedAt == nil, !state.hasAttempted else { return }
    await sync(into: context)
  }

  /// Trae la biblioteca de Steam y la guarda.
  ///
  /// No propaga errores: los guarda en `state` para que la vista los muestre.
  /// Un fallo **no borra** lo que ya estaba guardado.
  func sync(into context: ModelContext) async {
    guard !state.isSyncing else { return }

    state = .syncing

    do {
      let juegos = try await service.fetchOwnedGames()
      let resultado = try SteamLibrarySyncer.sync(juegos, into: context)

      lastSyncReturnedNoGames = juegos.isEmpty
      registrarSincronizacion(at: Date())
      state = .succeeded(created: resultado.created, updated: resultado.updated)
    } catch let error as NetworkError {
      state = .failed(
        message: error.errorDescription ?? String(localized: "No se pudo sincronizar.", comment: "Error generico"),
        suggestion: error.recoverySuggestion
      )
    } catch let error as SteamCredentialsError {
      state = .failed(
        message: error.errorDescription ?? "",
        suggestion: error.recoverySuggestion
      )
    } catch {
      state = .failed(message: error.localizedDescription, suggestion: nil)
    }
  }

  private func registrarSincronizacion(at fecha: Date) {
    lastSyncedAt = fecha
    defaults.set(fecha, forKey: Self.lastSyncKey)
  }
}

/// Servicio que solo sabe fallar, con el motivo original.
///
/// Se usa cuando no se pudieron leer las credenciales: asi la app arranca y
/// explica el problema en vez de caerse.
private struct UnavailableSteamService: SteamServicing {
  let error: Error

  func fetchOwnedGames() async throws -> [SteamGameDTO] {
    throw error
  }
}
