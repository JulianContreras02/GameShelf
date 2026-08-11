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
  enum State: Equatable {
    /// Sin hacer nada.
    case idle
    /// Pidiendo datos a Steam.
    case syncing
    /// Termino bien.
    case succeeded(created: Int, updated: Int)
    /// Fallo, con un mensaje que se puede mostrar tal cual.
    case failed(message: String, suggestion: String?)

    var isSyncing: Bool { self == .syncing }
  }

  private(set) var state: State = .idle

  /// Cuando termino la ultima sincronizacion correcta.
  private(set) var lastSyncedAt: Date?

  private let service: SteamServicing

  init(service: SteamServicing) {
    self.service = service
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

  /// Trae la biblioteca de Steam y la guarda.
  ///
  /// No propaga errores: los guarda en `state` para que la vista los muestre.
  func sync(into context: ModelContext) async {
    guard !state.isSyncing else { return }

    state = .syncing

    do {
      let juegos = try await service.fetchOwnedGames()
      let resultado = try SteamLibrarySyncer.sync(juegos, into: context)
      lastSyncedAt = Date()
      state = .succeeded(created: resultado.created, updated: resultado.updated)
    } catch let error as NetworkError {
      state = .failed(
        message: error.errorDescription ?? "No se pudo sincronizar.",
        suggestion: error.recoverySuggestion
      )
    } catch let error as AppSecrets.MissingSecretError {
      state = .failed(
        message: error.errorDescription ?? "Falta configurar las claves.",
        suggestion: error.recoverySuggestion
      )
    } catch {
      state = .failed(message: error.localizedDescription, suggestion: nil)
    }
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
