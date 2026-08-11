//
//  Item.swift
//  GameShelf
//
//  Created by Julian Contreras on 10/08/26.
//

import Foundation
import SwiftData

@Model
final class Item {
  var timestamp: Date

  init(timestamp: Date) {
    self.timestamp = timestamp
  }
}
