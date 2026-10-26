//
//  WishlistSyncTests.swift
//  GameShelfTests
//

import Foundation
import SwiftData
import Testing

@testable import GameShelf

@MainActor
private func hacerContexto() throws -> ModelContext {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let contenedor = try ModelContainer(
    for: Game.self, StoreEntry.self, GameCollection.self, GameTag.self,
    configurations: config
  )
  return ModelContext(contenedor)
}

private func juegoDePSN(_ titleId: String, nombre: String, horas: Double, trofeos: Int? = nil) -> PSNGame {
  PSNGame(
    titleId: titleId, name: nombre, coverURL: nil,
    playtimeHours: horas, playCount: nil, lastPlayedAt: nil, firstPlayedAt: nil, trophyProgress: trofeos
  )
}

@MainActor
@Suite("Wishlist: guardar en la base")
struct WishlistSyncTests {

  @Test("Guarda los juegos con estado de lista de deseos")
  func guardaConEstado() throws {
    let context = try hacerContexto()

    let resultado = try SteamWishlistSyncer.sync(
      [.ejemplo(appID: 1, name: "Cuphead"), .ejemplo(appID: 2, name: "Hades")],
      into: context
    )

    #expect(resultado.created == 2)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 2)
    #expect(juegos.allSatisfy { $0.status == .wishlist })
    #expect(juegos.allSatisfy { $0.isWishlistedInStore })
    #expect(juegos.allSatisfy { $0.playtimeHours == 0 })
  }

  @Test("Sincronizar dos veces no duplica nada")
  func idempotente() throws {
    let context = try hacerContexto()
    let juegos: [SteamWishlistGame] = [.ejemplo(appID: 1), .ejemplo(appID: 2)]

    let primera = try SteamWishlistSyncer.sync(juegos, into: context)
    let segunda = try SteamWishlistSyncer.sync(juegos, into: context)

    #expect(primera.created == 2)
    #expect(segunda.created == 0)
    #expect(segunda.updated == 2)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 2)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 2)
  }

  @Test("No pisa el estado que puso el usuario")
  func respetaElEstado() throws {
    let context = try hacerContexto()
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, name: "Hades")], into: context)

    // El usuario lo jugo en consola y lo marco como terminado, aunque siga en
    // su lista de deseos de Steam.
    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    juego.status = .finished
    juego.notes = "Terminado en Switch"
    try context.save()

    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, name: "Hades")], into: context)

    let despues = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(despues.status == .finished, "La sincronizacion no puede cambiar el estado")
    #expect(despues.notes == "Terminado en Switch")
    #expect(despues.isWishlistedInStore, "Sigue en la lista de Steam, aunque el estado sea otro")
  }

  @Test("Comprar un juego lo saca de la lista sin borrarlo")
  func alComprarSeQuitaDeLaLista() throws {
    let context = try hacerContexto()
    try SteamWishlistSyncer.sync(
      [.ejemplo(appID: 1, name: "Hades"), .ejemplo(appID: 2, name: "Cuphead")],
      into: context
    )

    // Compraste Cuphead: Steam lo saca de la wishlist y ya no viene.
    let resultado = try SteamWishlistSyncer.sync([.ejemplo(appID: 1, name: "Hades")], into: context)

    #expect(resultado.removed == 1)

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 2, "El juego no se borra, solo deja de estar deseado")

    let cuphead = try #require(juegos.first { $0.name == "Cuphead" })
    #expect(!cuphead.isWishlistedInStore)
    #expect(cuphead.status == .wishlist, "El estado es del usuario: lo cambia el, no la sincronizacion")

    let hades = try #require(juegos.first { $0.name == "Hades" })
    #expect(hades.isWishlistedInStore)
  }

  @Test("Una respuesta vacia no vacia la lista guardada")
  func respuestaVaciaNoBorra() throws {
    let context = try hacerContexto()
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1), .ejemplo(appID: 2)], into: context)

    // Wishlist privada: Steam responde lo mismo que si estuviera vacia. Vaciar
    // la lista del usuario por una respuesta ambigua seria el peor error
    // posible, asi que no se quita nada.
    let resultado = try SteamWishlistSyncer.sync([], into: context, allowRemovals: false)

    #expect(resultado.removed == 0)
    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 2)
    #expect(juegos.allSatisfy { $0.isWishlistedInStore })
  }

  @Test("Un juego que ya tienes no pierde sus horas al entrar en la lista")
  func noPisaLasHoras() throws {
    let context = try hacerContexto()

    // Primero llega por la biblioteca, con horas jugadas.
    let json = #"{"appid": 1, "name": "Hades", "playtime_forever": 600}"#
    let dto = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([dto], into: context)

    // Y despues aparece tambien en la lista de deseos (pasa con ediciones
    // completas y DLC).
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, name: "Hades")], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(juego.playtimeHours == 10, "Las horas las manda la biblioteca, no la wishlist")
    #expect(juego.isWishlistedInStore)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 1, "No se crea una segunda entrada")
  }

  @Test("Un juego sin fecha pero marcado como proximo se guarda como tal")
  func proximoSinFecha() throws {
    let context = try hacerContexto()

    // Es el caso de "Totally Secure Airport": Steam dice "Proximamente" y no
    // manda fecha. Sin guardar el aviso, la app lo mostraria como ya lanzado.
    try SteamWishlistSyncer.sync(
      [.ejemplo(appID: 1, name: "Sin fecha", isComingSoon: true)],
      into: context
    )

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(juego.releaseDate == nil)
    #expect(juego.isComingSoon)
  }

  @Test("Cuando el juego sale, deja de estar marcado como proximo")
  func dejaDeSerProximo() throws {
    let context = try hacerContexto()
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, isComingSoon: true)], into: context)

    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, isComingSoon: false)], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(!juego.isComingSoon, "Este si se refresca: es un dato de la tienda que cambia")
  }

  @Test("Se conserva la fecha en que lo deseaste por primera vez")
  func conservaLaFecha() throws {
    let context = try hacerContexto()
    let original = Date(timeIntervalSince1970: 1_700_000_000)

    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, addedAt: original)], into: context)
    try SteamWishlistSyncer.sync([.ejemplo(appID: 1, addedAt: Date())], into: context)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(juego.wishlistedAt == original)
  }

  @Test("Sincroniza la wishlist real de punta a punta")
  func deExtremoAExtremo() async throws {
    let context = try hacerContexto()

    let wishlist = try String(data: Fixture.data("steam_wishlist"), encoding: .utf8) ?? ""
    let fichas = try String(data: Fixture.data("steam_store_items"), encoding: .utf8) ?? ""

    let servicio = SteamWishlistService(
      client: RoutingHTTPClient(rutas: [
        ("GetWishlist", wishlist),
        ("GetItems", fichas)
      ]),
      steamID: "123"
    )

    let juegos = try await servicio.fetchWishlist()
    #expect(juegos.count == 10)

    try SteamWishlistSyncer.sync(juegos, into: context)

    let guardados = try context.fetch(FetchDescriptor<Game>())
    #expect(guardados.count == 10)
    #expect(guardados.allSatisfy { $0.status == .wishlist })
    #expect(guardados.contains { $0.name == "Cuphead" })
    #expect(guardados.allSatisfy { $0.coverImageURL != nil }, "Todos deberian traer caratula")
  }

  @Test("Si la tienda no resuelve un appid, el juego no se pierde")
  func fichaQueFalla() async throws {
    let servicio = SteamWishlistService(
      client: RoutingHTTPClient(rutas: [
        ("GetWishlist", #"{"response":{"items":[{"appid":999,"priority":0,"date_added":1700000000}]}}"#),
        ("GetItems", #"{"response":{"store_items":[{"appid":999,"success":2}]}}"#)
      ]),
      steamID: "123"
    )

    let juegos = try await servicio.fetchWishlist()

    #expect(juegos.count == 1, "Perder la entrada seria peor que mostrarla incompleta")
    #expect(juegos.first?.name.contains("999") == true, "Al menos se ve de que appid se trata")
    #expect(juegos.first?.storeURL != nil, "El enlace a la tienda se puede armar igual")
  }

  @Test("Con la wishlist vacia no se piden fichas de tienda")
  func sinLlamadaDeMas() async throws {
    let cliente = RoutingHTTPClient(rutas: [("GetWishlist", #"{"response":{}}"#)])
    let servicio = SteamWishlistService(client: cliente, steamID: "123")

    let juegos = try await servicio.fetchWishlist()

    #expect(juegos.isEmpty)
    #expect(cliente.requestedURLs.count == 1, "No tiene sentido pedir fichas de cero appids")
  }
}

@MainActor
@Suite("Wishlist: un juego de otra tienda suma Steam")
struct WishlistSyncMergeTests {

  @Test("Un juego que ya vino de PSN no se duplica: suma su entrada de Steam")
  func uneConPSN() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "HADES", horas: 20)], into: context)

    let resultado = try SteamWishlistSyncer.sync([.ejemplo(appID: 1145360, name: "Hades")], into: context)

    #expect(resultado == SteamWishlistSyncer.Result(merged: 1))

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 1, "Es el mismo juego, no dos")

    let juego = try #require(juegos.first)
    #expect(Set(juego.stores) == [.psn, .steam])
    #expect(juego.wishlistedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(juego.steamAppID == 1145360, "Con el appID ya se le pueden pedir precios")
    #expect(juego.status == .backlog, "Ya lo tienes: no pasa a la lista de deseos")
    #expect(juego.playtimeHours == 20, "Las horas son las de PSN")
    #expect(juego.name == "HADES", "Si Steam lo pisara, PSN se lo volveria a cambiar")
  }

  @Test("Tambien une con Epic")
  func uneConEpic() throws {
    let context = try hacerContexto()
    try EpicLibrarySyncer.sync(
      [EpicGame(namespace: "ns", name: "Cyberpunk 2077", coverURL: nil, playtimeHours: 49.5)],
      into: context
    )

    let resultado = try SteamWishlistSyncer.sync([.ejemplo(appID: 1091500, name: "Cyberpunk 2077")], into: context)

    #expect(resultado.merged == 1)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(Set(juego.stores) == [.epic, .steam])
    #expect(juego.isWishlistedInStore)
  }

  @Test("Sincronizar otra vez despues de la union no duplica nada")
  func unionIdempotente() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Hades", horas: 20)], into: context)
    let deseado = SteamWishlistGame.ejemplo(appID: 1145360, name: "Hades")

    try SteamWishlistSyncer.sync([deseado], into: context)
    let segunda = try SteamWishlistSyncer.sync([deseado], into: context)

    #expect(segunda == SteamWishlistSyncer.Result(updated: 1), "La segunda vez ya lo encuentra por su appID")
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<StoreEntry>()).count == 2, "Una entrada de PSN y una de Steam")
  }

  @Test("La union no pisa el estado ni las notas del juego que ya estaba")
  func unionRespetaLoDelUsuario() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Hades", horas: 20)], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    guardado.status = .finished
    guardado.notes = "Platino conseguido"
    let idOriginal = guardado.id
    try context.save()

    let deseado = SteamWishlistGame.ejemplo(appID: 1145360, name: "Hades")
    try SteamWishlistSyncer.sync([deseado], into: context)
    try SteamWishlistSyncer.sync([deseado], into: context)

    let despues = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(despues.id == idOriginal, "Es el mismo registro, no uno nuevo")
    #expect(despues.status == .finished, "El estado no se puede perder")
    #expect(despues.notes == "Platino conseguido", "Las notas no se pueden perder")
    #expect(despues.isWishlistedInStore)
  }

  @Test("Si sale de la lista, al juego unido solo se le limpia la fecha")
  func quitarLaUnionSoloLimpiaLaFecha() throws {
    let context = try hacerContexto()
    try PSNLibrarySyncer.sync([juegoDePSN("PPSA1", nombre: "Hades", horas: 20, trofeos: 40)], into: context)

    let guardado = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    guardado.status = .playing
    guardado.notes = "Lo quiero tambien en PC"
    try context.save()

    try SteamWishlistSyncer.sync(
      [.ejemplo(appID: 1145360, name: "Hades"), .ejemplo(appID: 268910, name: "Cuphead")],
      into: context
    )

    // Lo compraste en Steam o lo quitaste de la lista: ya no viene.
    let resultado = try SteamWishlistSyncer.sync([.ejemplo(appID: 268910, name: "Cuphead")], into: context)

    #expect(resultado == SteamWishlistSyncer.Result(updated: 1, removed: 1))
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 2, "No se borra ningun juego")

    let hades = try #require(try context.fetch(FetchDescriptor<Game>()).first { $0.name == "Hades" })
    #expect(!hades.isWishlistedInStore)
    #expect(hades.status == .playing, "El estado es del usuario")
    #expect(hades.notes == "Lo quiero tambien en PC")

    let steam = try #require(hades.storeEntries.first { $0.store == .steam })
    #expect(steam.wishlistedAt == nil)
    #expect(steam.storeGameID == "1145360", "La entrada se queda: solo se limpia la fecha")

    let psn = try #require(hades.storeEntries.first { $0.store == .psn })
    #expect(psn.playtimeHours == 20, "La entrada de PSN no se toca")
    #expect(psn.trophyProgress == 40)
  }

  @Test("Un juego de Steam con el mismo nombre y otro appID se guarda aparte")
  func mismoNombreEnSteam() throws {
    let context = try hacerContexto()
    // Tienes Resident Evil 4 de 2005 y deseas el remake: mismo nombre, otro appID.
    let json = #"{"appid": 254700, "name": "Resident Evil 4", "playtime_forever": 600}"#
    let original = try JSONDecoder().decode(SteamGameDTO.self, from: Data(json.utf8))
    try SteamLibrarySyncer.sync([original], into: context)

    let resultado = try SteamWishlistSyncer.sync(
      [.ejemplo(appID: 2050650, name: "Resident Evil 4")],
      into: context
    )

    #expect(resultado == SteamWishlistSyncer.Result(created: 1))

    let juegos = try context.fetch(FetchDescriptor<Game>())
    #expect(juegos.count == 2)

    let tuyo = try #require(juegos.first { $0.steamAppID == 254700 })
    #expect(!tuyo.isWishlistedInStore, "La entrada del que ya tienes no se pisa")
    #expect(tuyo.storeEntries.count == 1)

    let remake = try #require(juegos.first { $0.steamAppID == 2050650 })
    #expect(remake.status == .wishlist)
  }

  @Test("Un juego agregado a mano suma Steam en vez de repetirse")
  func uneConUnoAgregadoAMano() throws {
    let context = try hacerContexto()
    context.insert(Game(name: "hades", status: .wishlist))
    try context.save()

    let resultado = try SteamWishlistSyncer.sync([.ejemplo(appID: 1145360, name: "Hades")], into: context)

    #expect(resultado.merged == 1)

    let juego = try #require(try context.fetch(FetchDescriptor<Game>()).first)
    #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
    #expect(juego.name == "Hades", "Sin otra tienda, el nombre lo pone Steam")
    #expect(juego.isWishlistedInStore)
    #expect(!WishlistViewModel.canDelete(juego), "Ahora vuelve con cada sincronizacion de Steam")
  }
}
