#if DEBUG
  import Foundation
  import SwiftData
  import SwiftUI

  /// Opt-in, in-memory fixtures for UI tests and App Store capture. Never opens the user's store.
  enum ScreenshotFixtures {
    @MainActor static func previewContainer(locale: Locale) -> ModelContainer {
      do { return try makeContainer(mode: "screenshots", locale: locale) } catch {
        fatalError("Failed to create preview fixtures: \(error)")
      }
    }

    @MainActor static func makeCommit() -> PersistenceCommit {
      guard mode != nil,
        let operation = ProcessInfo.processInfo.environment["USEDWELL_FAIL_SAVE"],
        let failureIndex = Int(operation)
      else { return PersistenceCommit() }
      var saves = 0
      return PersistenceCommit { context in
        saves += 1
        if saves == failureIndex { throw CocoaError(.fileWriteUnknown) }
        try context.save()
      }
    }

    @MainActor private static func populateDateBoundary(_ container: ModelContainer) throws {
      let calendar = Calendar.current
      container.mainContext.insert(
        Item(
          name: "Boundary Phone", category: .phone,
          purchaseDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 25))!,
          purchasePrice: 3100, targetMonths: 1))
      container.mainContext.insert(
        Item(
          name: "Long Goal", category: .camera,
          purchaseDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 27))!,
          purchasePrice: 6100, targetMonths: 2))
      try container.mainContext.save()
    }

    static var mode: String? { ProcessInfo.processInfo.environment["USEDWELL_FIXTURE"] }

    @MainActor private static func populateCostScreenshot(
      _ container: ModelContainer, today: Date, calendar: Calendar
    ) throws {
      let computer = Item(
        name: "MacBook Pro", category: .computer,
        purchaseDate: calendar.date(byAdding: .year, value: -2, to: today)!,
        purchasePrice: 3_999, targetMonths: 48)
      container.mainContext.insert(computer)
      computer.usageNotes.append(
        UsageNote(date: today, text: "Still handles my video projects well"))
      try container.mainContext.save()
    }

    static var homeReferenceDate: Date? {
      guard mode?.hasPrefix("home-") == true else { return nil }
      return homeDate(2026, 9, 8)
    }

    private static func homeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
      Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @MainActor private static func populateHome(
      _ container: ModelContainer, mode: String, locale: Locale
    ) throws {
      let japanese = locale.language.languageCode?.identifier == "ja"
      let phone = Item(
        name: "iPhone 15 Pro", category: .phone, purchaseDate: homeDate(2023, 9, 24),
        purchasePrice: 159_800, targetMonths: 36)
      if mode == "home-new" {
        phone.purchaseDate = homeDate(2026, 9, 8)
      } else if mode == "home-over" {
        phone.purchaseDate = homeDate(2022, 9, 8)
      } else if mode == "home-long" {
        phone.name =
          japanese
          ? "旅と日常の記録に使い続けている大切なフルサイズカメラと標準ズームレンズ"
          : "The full-frame camera and everyday zoom lens I have used for travel and family photographs"
        phone.categoryRawValue = ItemCategory.camera.rawValue
        phone.purchaseDate = homeDate(2013, 10, 8)
      }
      container.mainContext.insert(phone)
      if mode == "home-review" {
        // Deliberately insert out of review order, including two items in the 90–99% state.
        container.mainContext.insert(
          Item(
            name: "Leather bag", category: .bag, purchaseDate: homeDate(2024, 12, 8),
            purchasePrice: 80_000, targetMonths: 36))
        container.mainContext.insert(
          Item(
            name: "MacBook Air", category: .computer, purchaseDate: homeDate(2024, 3, 8),
            purchasePrice: 183_800, targetMonths: 36))
        container.mainContext.insert(
          Item(
            name: "Review Camera", category: .camera, purchaseDate: homeDate(2023, 11, 8),
            purchasePrice: 120_000, targetMonths: 36))
      }
      if mode != "home-new" {
        container.mainContext.insert(
          Item(
            name: "Past Watch", category: .watch, purchaseDate: homeDate(2020, 9, 8),
            purchasePrice: 40_000, targetMonths: 24, completedDate: homeDate(2023, 9, 8)))
      }
      try container.mainContext.save()
    }

    @MainActor static func makeContainer(
      mode: String, locale: Locale = .current
    ) throws -> ModelContainer {
      let container = try ModelContainer(
        for: Item.self, UsageNote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
      guard mode != "empty" else { return container }
      if mode.hasPrefix("home-") {
        try populateHome(container, mode: mode, locale: locale)
        return container
      }
      if mode == "day-boundary" {
        try populateDateBoundary(container)
        return container
      }
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: .now)
      if mode == "cost-screenshot" {
        try populateCostScreenshot(container, today: today, calendar: calendar)
        return container
      }
      let target = calendar.date(byAdding: .day, value: 16, to: today)!
      let purchase = calendar.date(byAdding: .year, value: -3, to: target)!
      let japanese = locale.language.languageCode?.identifier == "ja"
      let phone = Item(
        name: "iPhone 15 Pro", category: .phone, purchaseDate: purchase,
        purchasePrice: japanese ? 159_800 : 1_099, targetMonths: 36)
      container.mainContext.insert(phone)
      let notes =
        japanese
        ? ["容量が少し足りなくなってきた", "最近バッテリーの減りが早い", "特に不満なし"]
        : ["Storage is getting tight", "Battery drains faster lately", "Still happy with it"]
      for (offset, text) in zip([18, 366, 1_066], notes) {
        phone.usageNotes.append(
          UsageNote(date: calendar.date(byAdding: .day, value: -offset, to: today)!, text: text))
      }
      container.mainContext.insert(
        Item(
          name: "MacBook Air", category: .computer,
          purchaseDate: calendar.date(byAdding: .month, value: -30, to: today)!,
          purchasePrice: japanese ? 183_800 : 1_299, targetMonths: 36))
      container.mainContext.insert(
        Item(
          name: japanese ? "レザーバッグ" : "Leather bag", category: .bag,
          purchaseDate: calendar.date(byAdding: .month, value: -21, to: today)!,
          purchasePrice: japanese ? 80_000 : 549, targetMonths: 36))
      try container.mainContext.save()
      return container
    }
  }
  /// Controls exist only in an explicitly selected, in-memory UI-test fixture.
  struct DateRefreshFixture: View {
    let notifications: NotificationScheduler
    let commit: PersistenceCommit
    @State private var date = TestDate()

    var body: some View {
      ContentView(notifications: notifications, commit: commit, now: { date.value })
        .safeAreaInset(edge: .bottom) {
          HStack {
            Button("Advance day") {
              date.advance()
              NotificationCenter.default.post(
                name: UIApplication.significantTimeChangeNotification, object: nil)
            }.accessibilityIdentifier("advance-day")
            Button("Advance without refresh") { date.advance() }
              .accessibilityIdentifier("advance-unobserved-day")
          }
        }
    }

    private final class TestDate {
      var value = Calendar.current.date(
        from: DateComponents(year: 2026, month: 8, day: 21, hour: 12))!
      func advance() { value = Calendar.current.date(byAdding: .day, value: 1, to: value)! }
    }
  }
#endif
