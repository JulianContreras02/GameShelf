//
//  EpicLibraryTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@Suite("Epic: decodificar la biblioteca real")
struct EpicLibraryDecodingTests {

  private func registros() throws -> [EpicLibraryRecordDTO] {
    try Fixture.decode(EpicLibraryResponse.self, from: "epic_biblioteca").registros
  }

  @Test("Decodifica los registros reales")
  func decodifica() throws {
    let todos = try registros()

    #expect(todos.count == 345)
    #expect(todos.allSatisfy { !$0.namespace.isEmpty })
  }

  @Test("Un juego aparece varias veces: lo que lo agrupa es el namespace")
  func variosArtefactosPorJuego() throws {
    let todos = try registros()

    // Ark salia 6 veces y Cyberpunk 4: son el ejecutable, sus DLC y sus
    // editores, no juegos distintos.
    let ark = todos.filter { $0.sandboxName == "Ark" }
    #expect(ark.count > 1)
    #expect(Set(ark.map(\.namespace)).count == 1, "Todos comparten namespace")
  }

  @Test("Cada namespace tiene un unico nombre, asi que sirve de identificador")
  func namespaceIdentificaElJuego() throws {
    var nombresPorNamespace: [String: Set<String>] = [:]
    for registro in try registros() {
      nombresPorNamespace[registro.namespace, default: []].insert(registro.sandboxName ?? "")
    }

    let ambiguos = nombresPorNamespace.filter { $0.value.count > 1 }
    #expect(ambiguos.isEmpty, "Un namespace con dos nombres romperia el agrupado")
  }

  @Test("Epic deja algunos sin nombre util")
  func nombresSinResolver() throws {
    let todos = try registros()
    let sinNombre = todos.filter { !$0.tieneNombreUtil }

    // En la biblioteca real eran 49, todos con el nombre "Live", que no dice
    // nada del juego. Hay que resolverlos contra el catalogo.
    #expect(!sinNombre.isEmpty)
    #expect(sinNombre.allSatisfy { $0.sandboxName == "Live" })
  }

  @Test("Lee el cursor de la siguiente pagina")
  func paginacion() throws {
    let conCursor = Data(#"{"records":[],"responseMetadata":{"nextCursor":"abc"}}"#.utf8)
    #expect(try JSONDecoder().decode(EpicLibraryResponse.self, from: conCursor).siguienteCursor == "abc")

    // Un cursor vacio significa que ya no hay mas, igual que si no viniera.
    let vacio = Data(#"{"records":[],"responseMetadata":{"nextCursor":""}}"#.utf8)
    #expect(try JSONDecoder().decode(EpicLibraryResponse.self, from: vacio).siguienteCursor == nil)

    let sinMetadata = Data(#"{"records":[]}"#.utf8)
    #expect(try JSONDecoder().decode(EpicLibraryResponse.self, from: sinMetadata).siguienteCursor == nil)
  }

  @Test("Decodifica el catalogo, con nombre y caratula")
  func catalogo() throws {
    let respuesta = try Fixture.decode(EpicCatalogResponse.self, from: "epic_catalogo")
    let ficha = try #require(respuesta.items.values.first)

    #expect(ficha.title?.isEmpty == false)
    #expect(ficha.coverURL != nil)
  }
}

@Suite("Epic: agrupar artefactos en juegos")
struct EpicGroupingTests {

  private func datos() throws -> ([EpicLibraryRecordDTO], [String: Double]) {
    let registros = try Fixture.decode(EpicLibraryResponse.self, from: "epic_biblioteca").registros
    let tiempos = try Fixture.decode([EpicPlaytimeDTO].self, from: "epic_tiempos")
      .reduce(into: [String: Double]()) { $0[$1.artifactId] = $1.horas }
    return (registros, tiempos)
  }

  @Test("345 registros son muchos menos juegos")
  func agrupa() throws {
    let (registros, tiempos) = try datos()

    let grupos = EpicLibraryService.agrupar(registros, tiempos: tiempos)

    #expect(grupos.count == 293, "Un grupo por namespace")
    #expect(grupos.count < registros.count, "Varios artefactos por juego")
  }

  @Test("El tiempo es el mayor de sus artefactos, no la suma")
  func tiempoSinDuplicar() throws {
    let (registros, tiempos) = try datos()
    let grupos = EpicLibraryService.agrupar(registros, tiempos: tiempos)

    // Cyberpunk reportaba 49,8 h bajo dos artefactos distintos del mismo
    // juego, y 17,5 h bajo un tercero. Sumarlas daria 117 h de un juego que
    // se jugo 50.
    let cyberpunk = try #require(grupos.values.first { $0.nombre.contains("yberpunk") })
    #expect(abs(cyberpunk.horas - 49.8) < 0.2, "Se toma el mayor, no la suma")
  }

  @Test("Los juegos sin jugar quedan en cero, no sin dato")
  func sinJugar() throws {
    let (registros, tiempos) = try datos()
    let grupos = EpicLibraryService.agrupar(registros, tiempos: tiempos)

    // En Epic lo normal es no haber jugado: son regalos semanales acumulados.
    let sinJugar = grupos.values.filter { $0.horas == 0 }
    #expect(sinJugar.count > grupos.count / 2, "La mayoria nunca se abrio")
  }

  @Test("El nombre util gana al que no lo es")
  func prefiereElNombreUtil() {
    // Si el primer artefacto trae "Live" y el segundo el nombre de verdad, se
    // queda el segundo, sin importar el orden en que lleguen.
    let registros = [
      EpicLibraryRecordDTO(
        namespace: "ns", catalogItemId: "a", appName: "x", sandboxName: "Live", recordType: nil
      ),
      EpicLibraryRecordDTO(
        namespace: "ns", catalogItemId: "b", appName: "y", sandboxName: "Hades", recordType: nil
      )
    ]

    let grupos = EpicLibraryService.agrupar(registros, tiempos: [:])

    #expect(grupos["ns"]?.nombre == "Hades")
    #expect(grupos["ns"]?.tieneNombre == true)
  }
}

@MainActor
@Suite("Epic: guardar y deduplicar")
struct EpicSyncTests {

  private func hacerContexto() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let contenedor = try ModelContainer(
      for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self,
      configurations: config
    )
    return ModelContext(contenedor)
  }

  private func juego(_ espacio: String, _ nombre: String, horas: Double = 5) -> EpicGame {
    EpicGame(namespace: espacio, name: nombre, coverURL: nil, playtimeHours: horas)
  }

  @Test("Guarda los juegos con su entrada de Epic")
  func guarda() throws {
    let context = try hacerContexto()

    let resultado = try EpicLibrarySyncer.sync(
      [juego("a", "Hades"), juego("b", "Celeste")],
      into: context
    )

    #expect(resultado.created == 2)
    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.allSatisfy { $0.stores == [.epic] })
    #expect(juegos.allSatisfy { $0.status == .backlog })
  }

  @Test("Sincronizar dos veces no duplica")
  func idempotente() throws {
    let context = try hacerContexto()
    let lista = [juego("a", "Hades"), juego("b", "Celeste")]

    try EpicLibrarySyncer.sync(lista, into: context)
    let segunda = try EpicLibrarySyncer.sync(lista, into: context)

    #expect(segunda.created == 0)
    #expect(segunda.updated == 2)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 2)
  }

  @Test("Un juego que ya estaba en Steam no se duplica")
  func deduplicaConSteam() throws {
    let context = try hacerContexto()
    let json = #"{"appid": 1, "name": "Cyberpunk 2077", "playtime_forever": 600}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)

    let resultado = try EpicLibrarySyncer.sync([juego("ns", "Cyberpunk 2077", horas: 49.8)], into: context)

    #expect(resultado.merged == 1)
    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 1)

    let unico = try #require(juegos.first)
    #expect(Set(unico.stores) == [.steam, .epic])
    #expect(abs(unico.playtimeHours - 59.8) < 0.01, "10 h de Steam mas 49,8 de Epic")
  }

  @Test("Tambien deduplica contra PlayStation")
  func deduplicaConPSN() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([
      PSNGame(
        titleId: "PPSA1", name: "Detroit: Become Human", coverURL: nil,
        playtimeHours: 2, playCount: 1, lastPlayedAt: nil, firstPlayedAt: nil, trophyProgress: 40
      )
    ], into: context)

    let resultado = try EpicLibrarySyncer.sync(
      [juego("ns", "Detroit: Become Human", horas: 42.9)],
      into: context
    )

    #expect(resultado.merged == 1)
    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(Set(unico.stores) == [.psn, .epic])
    #expect(unico.trophyProgress == 40, "Lo de PlayStation se conserva")
  }

  @Test("No pisa el estado ni las notas")
  func respetaLoDelUsuario() throws {
    let context = try hacerContexto()
    try EpicLibrarySyncer.sync([juego("a", "Hades")], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    guardado.status = .finished
    guardado.notes = "Terminado"
    try context.save()

    try EpicLibrarySyncer.sync([juego("a", "Hades", horas: 30)], into: context)

    let despues = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(despues.status == .finished)
    #expect(despues.notes == "Terminado")
    #expect(despues.playtimeHours == 30, "Las horas si se refrescan")
  }

  @Test("El nombre de otra tienda no se pisa con el de Epic")
  func noPisaElNombre() throws {
    let context = try hacerContexto()
    let json = #"{"appid": 1, "name": "Sid Meier's Civilization VI", "playtime_forever": 60}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)

    try EpicLibrarySyncer.sync([juego("ns", "sid meiers civilization vi")], into: context)

    let unico = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(unico.name == "Sid Meier's Civilization VI", "Se conserva el nombre bien escrito")
  }

  @Test("Dos juegos distintos de la misma tanda no se pisan entre si")
  func variosNuevosDeUnaVez() throws {
    let context = try hacerContexto()

    try EpicLibrarySyncer.sync([juego("a", "Uno"), juego("b", "Dos"), juego("c", "Tres")], into: context)

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 3)
  }

  @Test("Dos entradas con el mismo nombre acaban en un solo juego")
  func mismoNombreEnLaMismaTanda() throws {
    let context = try hacerContexto()

    // Puede pasar si Epic tiene el juego bajo dos namespaces distintos.
    let resultado = try EpicLibrarySyncer.sync(
      [juego("a", "Fortnite", horas: 100), juego("b", "Fortnite", horas: 10)],
      into: context
    )

    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
    #expect(resultado.created == 1)
    #expect(resultado.merged == 1)
  }
}

@Suite("Epic: peticiones de biblioteca")
struct EpicLibraryRequestTests {

  private func servicio(_ client: HTTPClient, cuenta: String? = "abc") -> EpicLibraryService {
    EpicLibraryService(client: client, accessToken: { "TOKEN" }, accountID: { cuenta })
  }

  @Test("La URL lleva el cursor solo cuando hay")
  func urls() throws {
    let epic = servicio(StubHTTPClient(json: "{}"))

    let primera = try epic.libraryURL().absoluteString
    #expect(primera.contains("includeMetadata=true"))
    #expect(!primera.contains("cursor="))

    let siguiente = try epic.libraryURL(cursor: "abc").absoluteString
    #expect(siguiente.contains("cursor=abc"))
  }

  @Test("El token va en la cabecera, en minuscula como espera Epic")
  func cabecera() async throws {
    let cliente = StubHTTPClient(json: #"{"records":[]}"#)

    _ = try await servicio(cliente).fetchRecords()

    let cabeceras = try #require(cliente.sentHeaders.first)
    #expect(cabeceras["Authorization"] == "bearer TOKEN")
  }

  @Test("Un 401 se traduce a sesion expirada")
  func tokenRechazado() async {
    let cliente = StubHTTPClient(.failure(.httpError(statusCode: 401)))

    await #expect(throws: EpicAuthError.sesionExpirada) {
      try await servicio(cliente).fetchRecords()
    }
  }

  @Test("Sin id de cuenta no se piden tiempos, y no falla")
  func sinCuenta() async {
    let tiempos = await servicio(StubHTTPClient(json: "[]"), cuenta: nil).fetchPlaytimes()

    #expect(tiempos.isEmpty)
  }

  @Test("Que fallen los tiempos no tumba la sincronizacion")
  func tiemposQueFallan() async {
    // Sin tiempos la biblioteca sigue sirviendo: los juegos se ven con 0 h,
    // que es mejor que no ver nada.
    let tiempos = await servicio(StubHTTPClient(.failure(.noConnection))).fetchPlaytimes()

    #expect(tiempos.isEmpty)
  }

  @Test("Que falle el catalogo no tumba la sincronizacion")
  func catalogoQueFalla() async {
    let grupos = [
      EpicLibraryService.Grupo(namespace: "ns", nombre: "Live", horas: 0, catalogItemID: "abc")
    ]

    let resueltos = await servicio(StubHTTPClient(.failure(.noConnection))).resolverNombres(de: grupos)

    #expect(resueltos.isEmpty)
  }
}
