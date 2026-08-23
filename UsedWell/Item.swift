import Foundation
import SwiftData

enum ItemCategory: String, CaseIterable, Codable, Identifiable {
  case phone = "スマートフォン"
  case computer = "パソコン"
  case watch = "時計"
  case camera = "カメラ"
  case bag = "バッグ"
  case wallet = "財布"
  case audio = "オーディオ"
  case other = "その他"
  var id: Self { self }
  var symbolName: String {
    switch self {
    case .phone: "iphone"
    case .computer: "laptopcomputer"
    case .watch: "applewatch"
    case .camera: "camera"
    case .bag: "handbag"
    case .wallet: "wallet.bifold"
    case .audio: "headphones"
    case .other: "star"
    }
  }
}

enum ReplacementStatus: Int, Comparable {
  case stillUsing, considerReplacing, goalAchieved
  static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  var title: String {
    switch self {
    case .stillUsing: "まだ使いたい"
    case .considerReplacing: "買い替えを考え始める"
    case .goalAchieved: "目標達成"
    }
  }
  var symbolName: String {
    switch self {
    case .stillUsing: "leaf.fill"
    case .considerReplacing: "eye.fill"
    case .goalAchieved: "checkmark.seal.fill"
    }
  }
}

@Model final class Item {
  var name: String
  var categoryRawValue: String
  var purchaseDate: Date
  var purchasePrice: Int
  var targetMonths: Int
  var completedDate: Date?
  var createdAt: Date

  init(
    name: String, category: ItemCategory, purchaseDate: Date, purchasePrice: Int, targetMonths: Int,
    completedDate: Date? = nil, createdAt: Date = .now
  ) {
    self.name = name
    categoryRawValue = category.rawValue
    self.purchaseDate = purchaseDate
    self.purchasePrice = purchasePrice
    self.targetMonths = targetMonths
    self.completedDate = completedDate
    self.createdAt = createdAt
  }

  var category: ItemCategory {
    get { ItemCategory(rawValue: categoryRawValue) ?? .other }
    set { categoryRawValue = newValue.rawValue }
  }
  var isCompleted: Bool { completedDate != nil }
  func targetDate(calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .month, value: targetMonths, to: purchaseDate) ?? purchaseDate
  }
  func elapsedDays(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
    max(1, calendar.dateComponents([.day], from: purchaseDate, to: completedDate ?? date).day ?? 1)
  }
  func targetDays(calendar: Calendar = .current) -> Int {
    max(
      1,
      calendar.dateComponents([.day], from: purchaseDate, to: targetDate(calendar: calendar)).day
        ?? 1)
  }
  func progress(asOf date: Date = .now, calendar: Calendar = .current) -> Double {
    Double(elapsedDays(asOf: date, calendar: calendar)) / Double(targetDays(calendar: calendar))
  }
  func status(asOf date: Date = .now, calendar: Calendar = .current) -> ReplacementStatus {
    let value = progress(asOf: date, calendar: calendar)
    if value >= 1 { return .goalAchieved }
    if value >= 0.9 { return .considerReplacing }
    return .stillUsing
  }
  func currentDailyCost(asOf date: Date = .now, calendar: Calendar = .current) -> Double {
    Double(purchasePrice) / Double(elapsedDays(asOf: date, calendar: calendar))
  }
  func targetDailyCost(calendar: Calendar = .current) -> Double {
    Double(purchasePrice) / Double(targetDays(calendar: calendar))
  }
  func extendedDailyCost(calendar: Calendar = .current) -> Double {
    Double(purchasePrice) / Double(targetDays(calendar: calendar) + 365)
  }
  func reviewPriority(asOf date: Date = .now) -> (Int, Double) {
    (status(asOf: date).rawValue, progress(asOf: date))
  }

  var usageDurationText: String {
    let components = Calendar.current.dateComponents(
      [.year, .month, .day], from: purchaseDate, to: completedDate ?? .now)
    if let years = components.year, years > 0 { return "\(years)年\(components.month ?? 0)か月" }
    if let months = components.month, months > 0 { return "\(months)か月" }
    return "\(max(0, components.day ?? 0))日"
  }
  var remainingText: String {
    let days = Calendar.current.dateComponents([.day], from: .now, to: targetDate()).day ?? 0
    if days >= 0 { return "目標まであと約\(max(1, Int(ceil(Double(days) / 30))))か月" }
    return "目標を約\(max(1, Int(ceil(Double(-days) / 30))))か月超えて使えています"
  }
}
