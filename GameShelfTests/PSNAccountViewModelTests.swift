//
//  PSNAccountViewModelTests.swift
//  GameShelfTests
//

import Foundation
import Testing

@testable import GameShelf

/// Servicio de PSN falso.
final class StubPSNAuthService: PSNAuthenticating, @unchecked Sendable {
  enum Behavior {
    case success(PSNCredentials)
    case failure(Error)
  }

  private let alIniciar: Behavior
  private let alRenovar: Behavior

  private(set) var iniciosDeSesion = 0
  private(set) var renovaciones = 0

  init(alIniciar: Behavior, alRenovar: Behavior? = nil) {
    self.alIniciar = alIniciar
    self.alRenovar = alRenovar ?? alIniciar
  }

  func signIn(npsso: String) async throws -> PSNCredentials {
    iniciosDeSesion += 1
    switch alIniciar {
    case .success(let credenciales): return credenciales
    case .failure(let error): throw error
    }
  }

  func refresh(using refreshToken: String) async throws -> PSNCredentials {
    renovaciones += 1
    switch alRenovar {
    case .success(let credenciales): return credenciales
    case .failure(let error): throw error
    }
  }
}

private func credenciales(
  acceso: String = "ACCESO",
  refresco: String = "REFRESCO",
  vence: TimeInterval = 3600
) -> PSNCredentials {
  PSNCredentials(
    accessToken: acceso,
    refreshToken: refresco,
    expiresAt: Date().addingTimeInterval(vence)
  )
}

@MainActor
@Suite("PSN: conectar la cuenta")
struct PSNAccountConnectTests {

  @Test("Al conectar guarda las credenciales en el llavero")
  func conecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(credenciales())),
      keychain: llavero
    )

    await viewModel.connect(npsso: "MI_TOKEN")

    #expect(viewModel.state == .conectado)
    #expect(try llavero.string(for: "psn.accessToken") == "ACCESO")
    #expect(try llavero.string(for: "psn.refreshToken") == "REFRESCO")
    #expect(viewModel.expiresAt != nil)
  }

  @Test("Los tokens NO se guardan en UserDefaults")
  func nadaEnUserDefaults() async throws {
    // Es el criterio del issue, y conviene comprobarlo en vez de confiar en que
    // el codigo "obviamente" no lo hace: UserDefaults es un archivo sin cifrar
    // dentro del contenedor de la app, y el token vale por la cuenta de Sony.
    //
    // Se mira `UserDefaults.standard`, que es donde acabaria un descuido. Una
    // primera version de esta prueba creaba su propio almacen con `suiteName:`
    // y ahi no se veia nada, asi que pasaba aunque el token se estuviera
    // guardando: comprobaba el sitio equivocado.
    let marcador = "SECRETO-\(UUID().uuidString)"

    // Se limpia antes de empezar: `UserDefaults.standard` es del simulador
    // entero y sobrevive entre ejecuciones, asi que un residuo de otra corrida
    // haria fallar esta prueba sin que el codigo tenga nada malo. Borrar aqui
    // no le quita valor: lo que se comprueba es lo que se escriba **despues**.
    for clave in UserDefaults.standard.dictionaryRepresentation().keys where clave.hasPrefix("psn.") {
      UserDefaults.standard.removeObject(forKey: clave)
    }

    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(credenciales(acceso: marcador))),
      keychain: InMemoryKeychainStore()
    )
    await viewModel.connect(npsso: "X")

    let guardado = UserDefaults.standard.dictionaryRepresentation()

    for (clave, valor) in guardado {
      #expect(!"\(valor)".contains(marcador), "El token aparecio en UserDefaults, bajo '\(clave)'")
    }
    #expect(
      guardado.keys.first { $0.hasPrefix("psn.") } == nil,
      "No deberia haber ninguna clave de PSN en UserDefaults"
    )
  }

  @Test("Un token invalido deja el estado pidiendo uno nuevo")
  func tokenInvalido() async {
    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .failure(PSNAuthError.npssoInvalido)),
      keychain: InMemoryKeychainStore()
    )

    await viewModel.connect(npsso: "CADUCADO")

    guard case .necesitaTokenNuevo(let mensaje, let sugerencia) = viewModel.state else {
      Issue.record("Se esperaba que pidiera un token nuevo, y quedo en \(viewModel.state)")
      return
    }
    #expect(!mensaje.isEmpty)
    #expect(sugerencia?.isEmpty == false, "Tiene que decir como arreglarlo")
  }

  @Test("Un fallo de red no se confunde con un token caducado")
  func falloDeRed() async {
    // Si se mostrara "vuelve a copiar el codigo" por un problema de red, el
    // usuario haria un trabajo inutil.
    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .failure(NetworkError.noConnection)),
      keychain: InMemoryKeychainStore()
    )

    await viewModel.connect(npsso: "X")

    guard case .fallo = viewModel.state else {
      Issue.record("Un fallo de red no deberia pedir un token nuevo: \(viewModel.state)")
      return
    }
  }

  @Test("Desconectar borra todo del llavero")
  func desconecta() async throws {
    let llavero = InMemoryKeychainStore()
    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(credenciales())),
      keychain: llavero
    )
    await viewModel.connect(npsso: "X")

    viewModel.disconnect()

    #expect(viewModel.state == .desconectado)
    #expect(try llavero.string(for: "psn.accessToken") == nil)
    #expect(try llavero.string(for: "psn.refreshToken") == nil)
    #expect(try llavero.string(for: "psn.expiresAt") == nil)
    #expect(viewModel.expiresAt == nil)
  }

  @Test("Al arrancar recuerda que ya estaba conectado")
  func recuerdaLaSesion() {
    let llavero = InMemoryKeychainStore(valoresIniciales: [
      "psn.accessToken": "A",
      "psn.refreshToken": "R",
      "psn.expiresAt": String(Date().addingTimeInterval(3600).timeIntervalSince1970)
    ])

    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(credenciales())),
      keychain: llavero
    )

    #expect(viewModel.state == .conectado)
  }

  @Test("Sin nada guardado arranca desconectado")
  func arranqueLimpio() {
    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(credenciales())),
      keychain: InMemoryKeychainStore()
    )

    #expect(viewModel.state == .desconectado)
  }
}

@MainActor
@Suite("PSN: renovar sola")
struct PSNAccountRefreshTests {

  @Test("Con el token vigente no se renueva de gratis")
  func noRenuevaSiNoHaceFalta() async throws {
    let servicio = StubPSNAuthService(alIniciar: .success(credenciales(acceso: "PRIMERO")))
    let viewModel = PSNAccountViewModel(service: servicio, keychain: InMemoryKeychainStore())
    await viewModel.connect(npsso: "X")

    let token = try await viewModel.validAccessToken()

    #expect(token == "PRIMERO")
    #expect(servicio.renovaciones == 0)
  }

  @Test("Con el token vencido se renueva sin molestar al usuario")
  func renuevaSola() async throws {
    let servicio = StubPSNAuthService(
      alIniciar: .success(credenciales(acceso: "VIEJO", vence: -10)),
      alRenovar: .success(credenciales(acceso: "NUEVO"))
    )
    let llavero = InMemoryKeychainStore()
    let viewModel = PSNAccountViewModel(service: servicio, keychain: llavero)
    await viewModel.connect(npsso: "X")

    let token = try await viewModel.validAccessToken()

    #expect(token == "NUEVO")
    #expect(servicio.renovaciones == 1)
    #expect(try llavero.string(for: "psn.accessToken") == "NUEVO", "El nuevo tambien se guarda")
    #expect(viewModel.state == .conectado)
  }

  @Test("Renovar no borra la fecha de reconexion que ya se conocia")
  func conservaLaFechaDeReconexion() async throws {
    // La respuesta de una renovacion no siempre repite
    // `refresh_token_expires_in`. Borrarla dejaria la pantalla sin la unica
    // fecha util.
    let conFecha = PSNCredentials(
      accessToken: "A",
      refreshToken: "R",
      expiresAt: Date().addingTimeInterval(-10),
      refreshExpiresAt: Date(timeIntervalSince1970: 9_000_000)
    )
    let sinFecha = PSNCredentials(
      accessToken: "NUEVO",
      refreshToken: "R2",
      expiresAt: Date().addingTimeInterval(3600)
    )

    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(conFecha), alRenovar: .success(sinFecha)),
      keychain: InMemoryKeychainStore()
    )
    await viewModel.connect(npsso: "X")
    #expect(viewModel.reconnectBy == Date(timeIntervalSince1970: 9_000_000))

    _ = try await viewModel.validAccessToken()

    #expect(viewModel.reconnectBy == Date(timeIntervalSince1970: 9_000_000))
  }

  @Test("Si el refresco tampoco sirve, se pide un codigo nuevo")
  func refrescoMuerto() async {
    let servicio = StubPSNAuthService(
      alIniciar: .success(credenciales(vence: -10)),
      alRenovar: .failure(PSNAuthError.sesionExpirada)
    )
    let viewModel = PSNAccountViewModel(service: servicio, keychain: InMemoryKeychainStore())
    await viewModel.connect(npsso: "X")

    await #expect(throws: PSNAuthError.sesionExpirada) {
      try await viewModel.validAccessToken()
    }

    guard case .necesitaTokenNuevo = viewModel.state else {
      Issue.record("Deberia pedir un codigo nuevo, y quedo en \(viewModel.state)")
      return
    }
  }

  @Test("Sin credenciales lo dice, en vez de fallar raro")
  func sinCredenciales() async {
    let viewModel = PSNAccountViewModel(
      service: StubPSNAuthService(alIniciar: .success(credenciales())),
      keychain: InMemoryKeychainStore()
    )

    await #expect(throws: PSNAuthError.sinCredenciales) {
      try await viewModel.validAccessToken()
    }
    #expect(viewModel.state == .desconectado)
  }
}
