//
//  GameShelfApp.swift
//  GameShelf
//
//  Created by Julian Contreras on 10/08/26.
//

import SwiftData
import SwiftUI

@main
struct GameShelfApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Game.self,
      StoreEntry.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
