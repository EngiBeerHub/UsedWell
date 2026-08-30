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

enum PurchasePrice {
  static let allowedRange = 1...9_999_999

  static func validationMessage(for value: Int?) -> String? {
    guard let value else { return "購入価格を入力してください" }
    guard value >= allowedRange.lowerBound else { return "購入価格は1円以上で入力してください" }
    guard value <= allowedRange.upperBound else {
      return "購入価格は9,999,999円以下で入力してください"
    }
    return nil
  }
}

@Model final class Item {
  /// Stable app-owned identity for navigation. Unlike `persistentModelID`, this does not change
  /// when SwiftData saves a newly inserted model and replaces its temporary identifier.
  var navigationID: UUID = UUID()
  var notificationID: UUID = UUID()
  var name: String
  var categoryRawValue: String
  var purchaseDate: Date
  var purchasePrice: Int
  var targetMonths: Int
  var completedDate: Date?
  var createdAt: Date
  @Relationship(deleteRule: .cascade, inverse: \UsageNote.item)
  var usageNotes: [UsageNote] = []

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

  /// Purchase dates represent local calendar days rather than moments in time.
  func purchaseDay(calendar: Calendar = .current) -> Date {
    calendar.startOfDay(for: purchaseDate)
  }

  func referenceDay(asOf date: Date = .now, calendar: Calendar = .current) -> Date {
    calendar.startOfDay(for: referenceDate(asOf: date))
  }

  func targetDate(calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .month, value: targetMonths, to: purchaseDay(calendar: calendar))
      ?? purchaseDay(calendar: calendar)
  }

  func elapsedDays(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
    max(
      1,
      calendar.dateComponents(
        [.day], from: purchaseDay(calendar: calendar),
        to: referenceDay(asOf: date, calendar: calendar)
      ).day ?? 1
    )
  }

  func targetDays(calendar: Calendar = .current) -> Int {
    max(
      1,
      calendar.dateComponents(
        [.day], from: purchaseDay(calendar: calendar), to: targetDate(calendar: calendar)
      ).day ?? 1
    )
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
      calendar.date(
        byAdding: .year, value: 1, to: referenceDay(asOf: date, calendar: calendar)
      ) ?? referenceDay(asOf: date, calendar: calendar)
    let days = max(
      1,
      calendar.dateComponents(
        [.day], from: purchaseDay(calendar: calendar), to: extendedDate
      ).day ?? 1
    )
    return Double(purchasePrice) / Double(days)
  }
  func reviewPriority(asOf date: Date = .now) -> (Int, Double) {
    (status(asOf: date).rawValue, progress(asOf: date))
  }

  func usageDurationText(asOf date: Date = .now, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents(
      [.year, .month, .day], from: purchaseDay(calendar: calendar),
      to: referenceDay(asOf: date, calendar: calendar))
    if let years = components.year, years > 0 { return "\(years)年\(components.month ?? 0)か月" }
    if let months = components.month, months > 0 { return "\(months)か月" }
    return "\(max(0, components.day ?? 0))日"
  }
  func remainingText(
    asOf date: Date = .now, calendar: Calendar = .current, usesDayPrecision: Bool = false
  ) -> String {
    let referenceDate = referenceDay(asOf: date, calendar: calendar)
    let targetDate = targetDate(calendar: calendar)
    let days = calendar.dateComponents([.day], from: referenceDate, to: targetDate).day ?? 0
    if days == 0 { return "今日が目標日です" }
    if usesDayPrecision {
      if days > 0 && days < 30 { return "目標まであと\(days)日" }
      if days < 0 && days > -30 { return "目標を\(-days)日超えて使えています" }
    }
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
  var sortedUsageNotes: [UsageNote] {
    usageNotes.sorted {
      if $0.date != $1.date { return $0.date > $1.date }
      return $0.createdAt > $1.createdAt
    }
  }

  static func repairDuplicateNavigationIDs(in items: [Item]) -> [Item] {
    let duplicateIDs = Set(
      Dictionary(grouping: items, by: \.navigationID).compactMap { id, items in
        items.count > 1 ? id : nil
      }
    )
    guard !duplicateIDs.isEmpty else { return [] }

    var usedIDs = Set(items.map(\.navigationID)).subtracting(duplicateIDs)
    var repairedItems: [Item] = []
    for item in items where duplicateIDs.contains(item.navigationID) {
      var repairedID = UUID()
      while usedIDs.contains(repairedID) {
        repairedID = UUID()
      }
      item.navigationID = repairedID
      usedIDs.insert(repairedID)
      repairedItems.append(item)
    }
    return repairedItems
  }

  static func repairDuplicateNotificationIDs(in items: [Item]) -> NotificationIDRepair {
    let duplicateIDs = Set(
      Dictionary(grouping: items, by: \.notificationID).compactMap { id, items in
        items.count > 1 ? id : nil
      }
    )
    guard !duplicateIDs.isEmpty else { return .none }

    var usedIDs = Set(items.map(\.notificationID)).subtracting(duplicateIDs)
    var repairedItems: [Item] = []
    for item in items where duplicateIDs.contains(item.notificationID) {
      var repairedID = UUID()
      while usedIDs.contains(repairedID) {
        repairedID = UUID()
      }
      item.notificationID = repairedID
      usedIDs.insert(repairedID)
      repairedItems.append(item)
    }
    return NotificationIDRepair(staleIDs: duplicateIDs, repairedItems: repairedItems)
  }
}

struct NotificationIDRepair {
  static let none = NotificationIDRepair(staleIDs: [], repairedItems: [])

  let staleIDs: Set<UUID>
  let repairedItems: [Item]
}

extension Date {
  var japaneseDateText: String {
    formatted(Date.FormatStyle().year().month().day().locale(Locale(identifier: "ja_JP")))
  }
}
