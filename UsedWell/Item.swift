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
  func displayName(locale: Locale = .current) -> String {
    switch self {
    case .phone: String(localized: LocalizedStringResource("スマートフォン", locale: locale))
    case .computer: String(localized: LocalizedStringResource("パソコン", locale: locale))
    case .watch: String(localized: LocalizedStringResource("時計", locale: locale))
    case .camera: String(localized: LocalizedStringResource("カメラ", locale: locale))
    case .bag: String(localized: LocalizedStringResource("バッグ", locale: locale))
    case .wallet: String(localized: LocalizedStringResource("財布", locale: locale))
    case .audio: String(localized: LocalizedStringResource("オーディオ", locale: locale))
    case .other: String(localized: LocalizedStringResource("その他", locale: locale))
    }
  }
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
  func title(locale: Locale = .current) -> String {
    switch self {
    case .stillUsing: String(localized: LocalizedStringResource("まだ使いたい", locale: locale))
    case .considerReplacing:
      String(localized: LocalizedStringResource("買い替えを考え始める", locale: locale))
    case .goalAchieved: String(localized: LocalizedStringResource("目標達成", locale: locale))
    }
  }
  var symbolName: String {
    switch self {
    case .stillUsing: "leaf.fill"
    case .considerReplacing: "eye.fill"
    case .goalAchieved:
      "checkmark.seal.fill"
    }
  }
}

enum PurchasePrice {
  static let allowedRange = 1...9_999_999

  static func validationMessage(for value: Int?, locale: Locale = .current) -> String? {
    guard let value else {
      return String(localized: LocalizedStringResource("購入価格を入力してください", locale: locale))
    }
    let format = IntegerFormatStyle<Int>.Currency(code: locale.currency?.identifier ?? "JPY")
      .precision(.fractionLength(0)).locale(locale)
    guard value >= allowedRange.lowerBound else {
      return String(
        localized: LocalizedStringResource(
          "購入価格は\(allowedRange.lowerBound.formatted(format))以上で入力してください",
          locale: locale))
    }
    guard value <= allowedRange.upperBound else {
      return String(
        localized: LocalizedStringResource(
          "購入価格は\(allowedRange.upperBound.formatted(format))以下で入力してください",
          locale: locale))
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
  @Attribute(.externalStorage) var photoData: Data?
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
  func reviewPriority(asOf date: Date = .now, calendar: Calendar = .current) -> (Int, Double) {
    (status(asOf: date, calendar: calendar).rawValue, progress(asOf: date, calendar: calendar))
  }

  static func activeItemsForReview(
    _ items: [Item], asOf date: Date, calendar: Calendar = .current
  ) -> [Item] {
    items.filter { !$0.isCompleted }.sorted {
      let lhs = $0.reviewPriority(asOf: date, calendar: calendar)
      let rhs = $1.reviewPriority(asOf: date, calendar: calendar)
      return lhs.0 == rhs.0 ? lhs.1 > rhs.1 : lhs.0 > rhs.0
    }
  }

  func usageDurationText(
    asOf date: Date = .now, calendar: Calendar = .current, locale: Locale = .current
  ) -> String {
    let components = calendar.dateComponents(
      [.year, .month, .day], from: purchaseDay(calendar: calendar),
      to: referenceDay(asOf: date, calendar: calendar))
    if let years = components.year, years > 0 {
      return Self.durationText(
        years: years, months: components.month ?? 0, includesZeroMonths: true, locale: locale)
    }
    if let months = components.month, months > 0 {
      return String(localized: LocalizedStringResource("\(months)か月", locale: locale))
    }
    return String(
      localized: LocalizedStringResource("\(max(0, components.day ?? 0))日", locale: locale))
  }
  func remainingText(
    asOf date: Date = .now, calendar: Calendar = .current, usesDayPrecision: Bool = false,
    locale: Locale = .current
  ) -> String {
    let referenceDate = referenceDay(asOf: date, calendar: calendar)
    let targetDate = targetDate(calendar: calendar)
    let days = calendar.dateComponents([.day], from: referenceDate, to: targetDate).day ?? 0
    if days == 0 { return String(localized: LocalizedStringResource("今日が目標日です", locale: locale)) }
    if usesDayPrecision {
      if days > 0 && days < 30 {
        return String(
          localized: LocalizedStringResource(
            "目標まであと\(String(localized: LocalizedStringResource("\(days)日", locale: locale)))",
            locale: locale))
      }
      if days < 0 && days > -30 {
        return String(
          localized: LocalizedStringResource(
            "目標を\(String(localized: LocalizedStringResource("\(-days)日", locale: locale)))超えて使えています",
            locale: locale))
      }
    }
    if referenceDate <= targetDate {
      let duration = yearMonthDurationText(
        from: referenceDate, to: targetDate, calendar: calendar, locale: locale)
      return
        String(
          localized: LocalizedStringResource(
            "目標まであと約\(duration)",
            locale: locale))
    }
    let duration = yearMonthDurationText(
      from: targetDate, to: referenceDate, calendar: calendar, locale: locale)
    return
      String(
        localized: LocalizedStringResource(
          "目標を約\(duration)超えて使えています",
          locale: locale))
  }

  private func yearMonthDurationText(
    from start: Date, to end: Date, calendar: Calendar, locale: Locale
  ) -> String {
    let components = calendar.dateComponents([.year, .month], from: start, to: end)
    let years = max(0, components.year ?? 0)
    let months = max(0, components.month ?? 0)
    if years > 0 && months > 0 {
      return Self.durationText(years: years, months: months, locale: locale)
    }
    if years > 0 { return String(localized: LocalizedStringResource("\(years)年", locale: locale)) }
    return String(localized: LocalizedStringResource("\(max(1, months))か月", locale: locale))
  }

  private static func durationText(
    years: Int, months: Int, includesZeroMonths: Bool = false, locale: Locale
  ) -> String {
    let yearText = String(localized: LocalizedStringResource("\(years)年", locale: locale))
    if months == 0 && !includesZeroMonths { return yearText }
    let monthText = String(localized: LocalizedStringResource("\(months)か月", locale: locale))
    return String(localized: LocalizedStringResource("\(yearText)\(monthText)", locale: locale))
  }

  var usageDurationText: String { usageDurationText() }
  var remainingText: String { remainingText() }
  var targetDurationText: String { targetDurationText(locale: .current) }
  func targetDurationText(locale: Locale) -> String {
    let years = targetMonths / 12
    let months = targetMonths % 12
    if years > 0 && months > 0 {
      return Self.durationText(years: years, months: months, locale: locale)
    }
    if years > 0 { return String(localized: LocalizedStringResource("\(years)年", locale: locale)) }
    return String(localized: LocalizedStringResource("\(months)か月", locale: locale))
  }
  func completedPeriodText(locale: Locale = .current) -> String {
    let start = purchaseDate.localizedDateText(locale: locale)
    let end = (completedDate ?? referenceDate()).localizedDateText(locale: locale)
    return String(localized: LocalizedStringResource("\(start) 〜 \(end)", locale: locale))
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
  func localizedDateText(locale: Locale = .current) -> String {
    formatted(Date.FormatStyle().year().month().day().locale(locale))
  }
}
