import Foundation
import SwiftData
import Testing

@testable import UsedWell

@MainActor struct LocalizationTests {
  @Test func englishDurationsUseSingularAndPlural() {
    let locale = Locale(identifier: "en_US")
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: .now, purchasePrice: 999, targetMonths: 13)
    #expect(item.targetDurationText(locale: locale) == "1 year 1 month")
    item.targetMonths = 26
    #expect(item.targetDurationText(locale: locale) == "2 years 2 months")
    item.targetMonths = 1
    #expect(item.targetDurationText(locale: locale) == "1 month")
  }

  @Test func notificationCopyUsesTheRequestedLanguage() {
    let english = Locale(identifier: "en_US")
    #expect(NotificationMilestone.review.title(locale: english) == "A moment to reflect")
    #expect(
      NotificationMilestone.review.body(itemName: "Phone", locale: english)
        == "Phone has reached 90% of your usage goal.")
    #expect(NotificationMilestone.goal.title(locale: Locale(identifier: "ja_JP")) == "使用目標に到達しました")
  }

  @Test func regionNoticeOnlyForUnacknowledgedChangesWithItems() {
    #expect(
      !RegionNotice.needsAcknowledgement(previousRegion: nil, currentRegion: "US", hasItems: false))
    #expect(
      !RegionNotice.needsAcknowledgement(previousRegion: nil, currentRegion: "JP", hasItems: true))
    #expect(
      RegionNotice.needsAcknowledgement(previousRegion: nil, currentRegion: "US", hasItems: true))
    #expect(
      RegionNotice.needsAcknowledgement(previousRegion: "JP", currentRegion: "US", hasItems: true))
    #expect(
      !RegionNotice.needsAcknowledgement(previousRegion: "US", currentRegion: "US", hasItems: true))
    #expect(
      RegionNotice.needsAcknowledgement(previousRegion: "US", currentRegion: "JP", hasItems: true))
    #expect(
      !RegionNotice.needsAcknowledgement(previousRegion: "US", currentRegion: "JP", hasItems: false)
    )
  }

  @Test func amountsAreNotConvertedAndCategoriesRemainCompatible() throws {
    let container = try ModelContainer(
      for: Item.self, UsageNote.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let item = Item(
      name: "日本語の名前", category: .phone, purchaseDate: .now,
      purchasePrice: 159_800, targetMonths: 36)
    container.mainContext.insert(item)
    let note = UsageNote(date: .now, text: "まだ十分使える")
    item.usageNotes.append(note)
    try container.mainContext.save()
    #expect(item.categoryRawValue == "スマートフォン")
    #expect(ItemCategory(rawValue: item.categoryRawValue) == .phone)
    let dollars = item.purchasePrice.formatted(
      .currency(code: "USD").precision(.fractionLength(0)).locale(Locale(identifier: "en_US")))
    let yen = item.purchasePrice.formatted(
      .currency(code: "JPY").precision(.fractionLength(0)).locale(Locale(identifier: "ja_JP")))
    #expect(dollars == "$159,800")
    #expect(yen.contains("159,800"))
    #expect(!yen.contains(".00"))
    #expect(item.purchasePrice == 159_800)
    #expect(item.name == "日本語の名前")
    #expect(item.usageNotes.first?.text == "まだ十分使える")
  }
}
