//
//  KeychainStore.swift
//  GameShelf
//

import Foundation
import Security

/// Guarda secretos pequenos, cifrados por el sistema.
///
/// Es un protocolo para poder inyectar un doble en las pruebas: el Keychain de
/// verdad es un recurso compartido del sistema, y una prueba que lo escriba
/// puede dejar basura o chocar con otra.
protocol KeychainStoring: Sendable {
  /// Lee un valor. `nil` si no esta guardado.
  func string(for key: String) throws -> String?

  /// Guarda un valor, reemplazando el anterior si lo hubiera.
  func set(_ value: String, for key: String) throws

  /// Borra un valor. No falla si no existia.
  func remove(for key: String) throws
}

/// Errores del Keychain, con el codigo original por si hay que investigar.
enum KeychainError: LocalizedError, Equatable {
  case operacionFallida(status: OSStatus)
  case datosCorruptos

  var errorDescription: String? {
    switch self {
    case .operacionFallida(let status):
      String(
        localized: "No se pudo acceder al llavero (codigo \(Int(status))).",
        comment: "Error al leer o guardar en el Keychain"
      )
    case .datosCorruptos:
      String(localized: "El dato guardado no se pudo leer.", comment: "Error al leer del Keychain")
    }
  }
}

/// Implementacion real sobre el Keychain del sistema.
///
/// Se usa `kSecClassGenericPassword` con `kSecAttrAccessibleAfterFirstUnlock`:
/// el token tiene que poder leerse cuando la app se actualice en segundo plano,
/// pero no antes de que el usuario desbloquee el telefono por primera vez.
struct KeychainStore: KeychainStoring {

  /// Agrupa las entradas de la app y evita chocar con otras.
  let service: String

  init(service: String = "com.juliancontreras.GameShelf") {
    self.service = service
  }

  func string(for key: String) throws -> String? {
    var consulta = consultaBase(for: key)
    consulta[kSecReturnData as String] = true
    consulta[kSecMatchLimit as String] = kSecMatchLimitOne

    var resultado: CFTypeRef?
    let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)

    switch status {
    case errSecSuccess:
      guard let datos = resultado as? Data,
            let texto = String(data: datos, encoding: .utf8)
      else { throw KeychainError.datosCorruptos }
      return texto

    case errSecItemNotFound:
      return nil

    default:
      throw KeychainError.operacionFallida(status: status)
    }
  }

  func set(_ value: String, for key: String) throws {
    let datos = Data(value.utf8)
    let consulta = consultaBase(for: key)

    // Se intenta actualizar primero: SecItemAdd falla si la entrada ya existe.
    let cambios = [kSecValueData as String: datos] as CFDictionary
    let actualizacion = SecItemUpdate(consulta as CFDictionary, cambios)

    if actualizacion == errSecSuccess { return }

    guard actualizacion == errSecItemNotFound else {
      throw KeychainError.operacionFallida(status: actualizacion)
    }

    var nueva = consulta
    nueva[kSecValueData as String] = datos
    nueva[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

    let alta = SecItemAdd(nueva as CFDictionary, nil)
    guard alta == errSecSuccess else {
      throw KeychainError.operacionFallida(status: alta)
    }
  }

  func remove(for key: String) throws {
    let status = SecItemDelete(consultaBase(for: key) as CFDictionary)

    // Que no existiera no es un fallo: el resultado buscado es el mismo.
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.operacionFallida(status: status)
    }
  }

  private func consultaBase(for key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]
  }
}

/// Guarda los secretos en memoria. **Solo para pruebas y vistas previas.**
///
/// Vive junto a la implementacion real, y no en la carpeta de pruebas, para que
/// los `#Preview` puedan usarla sin tocar el llavero del sistema.
final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
  private let candado = NSLock()
  private var valores: [String: String] = [:]

  init(valoresIniciales: [String: String] = [:]) {
    self.valores = valoresIniciales
  }

  func string(for key: String) throws -> String? {
    candado.withLock { valores[key] }
  }

  func set(_ value: String, for key: String) throws {
    candado.withLock { valores[key] = value }
  }

  func remove(for key: String) throws {
    _ = candado.withLock { valores.removeValue(forKey: key) }
  }
}
