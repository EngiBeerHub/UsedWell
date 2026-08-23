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
  var notificationID: UUID = UUID()
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
  func referenceDate(asOf date: Date = .now) -> Date { completedDate ?? date }
  func targetDate(calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .month, value: targetMonths, to: purchaseDate) ?? purchaseDate
  }
  func elapsedDays(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
    max(
      1, calendar.dateComponents([.day], from: purchaseDate, to: referenceDate(asOf: date)).day ?? 1
    )
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
  func extendedDailyCost(asOf date: Date = .now, calendar: Calendar = .current) -> Double {
    let extendedDate =
      calendar.date(byAdding: .year, value: 1, to: referenceDate(asOf: date)) ?? date
    let days = max(
      1, calendar.dateComponents([.day], from: purchaseDate, to: extendedDate).day ?? 1)
    return Double(purchasePrice) / Double(days)
  }
  func reviewPriority(asOf date: Date = .now) -> (Int, Double) {
    (status(asOf: date).rawValue, progress(asOf: date))
  }

  func usageDurationText(asOf date: Date = .now, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents(
      [.year, .month, .day], from: purchaseDate, to: referenceDate(asOf: date))
    if let years = components.year, years > 0 { return "\(years)年\(components.month ?? 0)か月" }
    if let months = components.month, months > 0 { return "\(months)か月" }
    return "\(max(0, components.day ?? 0))日"
  }
  func remainingText(asOf date: Date = .now, calendar: Calendar = .current) -> String {
    let referenceDate = referenceDate(asOf: date)
    let targetDate = targetDate(calendar: calendar)
    if referenceDate <= targetDate {
      return
        "目標まであと約\(yearMonthDurationText(from: referenceDate, to: targetDate, calendar: calendar))"
    }
    return
      "目標を約\(yearMonthDurationText(from: targetDate, to: referenceDate, calendar: calendar))超えて使えています"
  }

  private func yearMonthDurationText(from start: Date, to end: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month], from: start, to: end)
    let years = max(0, components.year ?? 0)
    let months = max(0, components.month ?? 0)
    if years > 0 && months > 0 { return "\(years)年\(months)か月" }
    if years > 0 { return "\(years)年" }
    return "\(max(1, months))か月"
  }

  var usageDurationText: String { usageDurationText() }
  var remainingText: String { remainingText() }
  var targetDurationText: String {
    let years = targetMonths / 12
    let months = targetMonths % 12
    if years > 0 && months > 0 { return "\(years)年\(months)か月" }
    if years > 0 { return "\(years)年" }
    return "\(months)か月"
  }
  var completedPeriodText: String {
    "\(purchaseDate.japaneseDateText) 〜 \((completedDate ?? referenceDate()).japaneseDateText)"
  }
}

extension Date {
  var japaneseDateText: String {
    formatted(Date.FormatStyle().year().month().day().locale(Locale(identifier: "ja_JP")))
  }
}
