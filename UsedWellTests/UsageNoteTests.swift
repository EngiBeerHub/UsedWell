import Foundation
import SwiftData
import Testing

@testable import UsedWell

@MainActor struct UsageNoteTests {
  @Test func itemWithoutNotesRemainsUsable() throws {
    let container = try makeContainer()
    let item = makeItem()
    container.mainContext.insert(item)
    try container.mainContext.save()

    let fetchedItems = try container.mainContext.fetch(FetchDescriptor<Item>())

    #expect(fetchedItems.count == 1)
    #expect(fetchedItems[0].usageNotes.isEmpty)
    #expect(fetchedItems[0].sortedUsageNotes.isEmpty)
  }

  @Test func multipleNotesPersistAndSortNewestFirst() throws {
    let container = try makeContainer()
    let item = makeItem()
    container.mainContext.insert(item)
    let oldest = UsageNote(
      date: date(2026, 8, 1), text: "まだ十分使える",
      createdAt: date(2026, 8, 1, hour: 9))
    let newest = UsageNote(
      date: date(2026, 8, 20), text: "バッテリーが気になる",
      createdAt: date(2026, 8, 20, hour: 9))
    let sameDayLater = UsageNote(
      date: date(2026, 8, 20), text: "今回は新型を見送った",
      createdAt: date(2026, 8, 20, hour: 10))
    for note in [oldest, newest, sameDayLater] {
      container.mainContext.insert(note)
      item.usageNotes.append(note)
    }
    try container.mainContext.save()

    let fetchedItem = try #require(container.mainContext.fetch(FetchDescriptor<Item>()).first)

    #expect(
      fetchedItem.sortedUsageNotes.map(\.text)
        == ["今回は新型を見送った", "バッテリーが気になる", "まだ十分使える"])
  }

  @Test func noteCanBeEditedAndDeletedWithoutDeletingItem() throws {
    let container = try makeContainer()
    let item = makeItem()
    let note = UsageNote(date: date(2026, 8, 1), text: "最初の内容")
    container.mainContext.insert(item)
    container.mainContext.insert(note)
    item.usageNotes.append(note)
    try container.mainContext.save()

    note.date = date(2026, 8, 2)
    note.text = "編集後の内容"
    try container.mainContext.save()
    #expect(note.text == "編集後の内容")

    item.usageNotes.removeAll { $0.persistentModelID == note.persistentModelID }
    container.mainContext.delete(note)
    try container.mainContext.save()

    #expect(try container.mainContext.fetch(FetchDescriptor<Item>()).count == 1)
    #expect(try container.mainContext.fetch(FetchDescriptor<UsageNote>()).isEmpty)
  }

  @Test func deletingItemCascadesToItsNotes() throws {
    let container = try makeContainer()
    let item = makeItem()
    let note = UsageNote(date: date(2026, 8, 1), text: "記録")
    container.mainContext.insert(item)
    container.mainContext.insert(note)
    item.usageNotes.append(note)
    try container.mainContext.save()

    container.mainContext.delete(item)
    try container.mainContext.save()

    #expect(try container.mainContext.fetch(FetchDescriptor<Item>()).isEmpty)
    #expect(try container.mainContext.fetch(FetchDescriptor<UsageNote>()).isEmpty)
  }

  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([Item.self, UsageNote.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  private func makeItem() -> Item {
    Item(
      name: "Phone", category: .phone, purchaseDate: date(2025, 8, 1), purchasePrice: 120_000,
      targetMonths: 36)
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
    Calendar(identifier: .gregorian).date(
      from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }
}
