//
//  GameDetailView+Previews.swift
//  GameShelf
//
//  Aparte para que GameDetailView no pase el limite de tamaño de SwiftLint.
//

import SwiftData
import SwiftUI

#Preview("Con caratula") {
  let game = Game(
    name: "Red Dead Redemption 2",
    coverImageURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1174180/header.jpg",
    playtimeHours: 227.9
  )
  game.storeEntries = [
    StoreEntry(
      store: .steam,
      storeGameID: "1174180",
      storeURL: "https://store.steampowered.com/app/1174180",
      playtimeHours: 227.9,
      lastPlayedAt: Date().addingTimeInterval(-3 * 86_400)
    )
  ]

  return NavigationStack {
    GameDetailView(game: game)
  }
}

#Preview("Sin jugar y sin caratula") {
  NavigationStack {
    GameDetailView(game: Game(name: "Un juego que nunca abri"))
  }
}
