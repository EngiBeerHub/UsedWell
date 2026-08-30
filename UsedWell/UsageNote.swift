import Foundation
import SwiftData

@Model final class UsageNote {
  var date: Date
  var text: String
  var createdAt: Date
  var updatedAt: Date
  var item: Item?

  init(
    date: Date, text: String, item: Item? = nil, createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.date = date
    self.text = text
    self.item = item
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
