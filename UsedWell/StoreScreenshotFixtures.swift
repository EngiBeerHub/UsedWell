#if DEBUG
  import Foundation
  import SwiftData

  /// Fixed, fictional data for repeatable Store captures. Uses only the in-memory fixture store.
  enum StoreScreenshotFixtures {
    static var referenceDate: Date { date(2026, 9, 23) }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
      Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @MainActor static func populate(
      _ container: ModelContainer, mode: String, locale: Locale
    ) throws {
      let japanese = locale.language.languageCode?.identifier == "ja"
      if mode == "store-cost" {
        let computer = Item(
          name: "MacBook Pro", category: .computer, purchaseDate: date(2025, 3, 23),
          purchasePrice: japanese ? 298_000 : 2_499, targetMonths: 48)
        container.mainContext.insert(computer)
        computer.usageNotes.append(
          UsageNote(
            date: date(2026, 9, 12),
            text: japanese ? "動画の編集も、まだ快適にできる。" : "Still handles my video projects well."))
      } else {
        let goalReached = mode == "store-goal"
        let phone = Item(
          name: goalReached ? "iPhone 14 Pro" : "iPhone 15 Pro", category: .phone,
          purchaseDate: goalReached ? date(2022, 9, 23) : date(2023, 11, 16),
          purchasePrice: japanese ? 159_800 : 1_099, targetMonths: 36)
        phone.photoData = ScreenshotFixtures.fixturePhotoData()
        container.mainContext.insert(phone)
        let notes =
          japanese
          ? ["バッテリーは気になる。動作はまだ快適。", "写真は今もきれい。新型は今回は見送った。", "容量は整理すれば、もう少し使えそう。"]
          : [
            "Battery life could be better. Still runs smoothly.",
            "Still takes great photos. Skipped this year's upgrade.",
            "Clearing some storage should keep it useful."
          ]
        for (index, text) in notes.enumerated() {
          phone.usageNotes.append(
            UsageNote(date: date(2026, 9 - index, 18 - index * 3), text: text))
        }
        container.mainContext.insert(
          Item(
            name: "MacBook Air", category: .computer, purchaseDate: date(2024, 3, 23),
            purchasePrice: japanese ? 183_800 : 1_299, targetMonths: 36))
        container.mainContext.insert(
          Item(
            name: japanese ? "レザーバッグ" : "Leather bag", category: .bag,
            purchaseDate: date(2024, 12, 23), purchasePrice: japanese ? 80_000 : 549,
            targetMonths: 36))
      }
      try container.mainContext.save()
    }
  }
#endif
