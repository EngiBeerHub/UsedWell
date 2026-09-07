#if DEBUG
  import Foundation
  import SwiftData

  /// Opt-in, in-memory fixtures for UI tests and App Store capture. Never opens the user's store.
  enum ScreenshotFixtures {
    @MainActor static func previewContainer(locale: Locale) -> ModelContainer {
      do { return try makeContainer(mode: "screenshots", locale: locale) } catch {
        fatalError("Failed to create preview fixtures: \(error)")
      }
    }

    static var mode: String? { ProcessInfo.processInfo.environment["USEDWELL_FIXTURE"] }

    @MainActor static func makeContainer(
      mode: String, locale: Locale = .current
    ) throws -> ModelContainer {
      let container = try ModelContainer(
        for: Item.self, UsageNote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
      guard mode != "empty" else { return container }
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: .now)
      if mode == "cost-screenshot" {
        let computer = Item(
          name: "MacBook Pro", category: .computer,
          purchaseDate: calendar.date(byAdding: .year, value: -2, to: today)!,
          purchasePrice: 3_999, targetMonths: 48)
        container.mainContext.insert(computer)
        computer.usageNotes.append(
          UsageNote(date: today, text: "Still handles my video projects well"))
        try container.mainContext.save()
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
#endif
