import Foundation
import SwiftData
import Testing

@testable import UsedWell

@MainActor struct NavigationIdentityTests {
  @Test func navigationIDSurvivesTemporaryPersistentIdentifierRemapping() throws {
    let container = try ModelContainer(
      for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let modelContext = container.mainContext
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: .now, purchasePrice: 100_000,
      targetMonths: 24)
    let navigationID = item.navigationID

    modelContext.insert(item)
    let temporaryPersistentModelID = item.persistentModelID

    try modelContext.save()

    #expect(item.persistentModelID != temporaryPersistentModelID)
    #expect(item.navigationID == navigationID)
    let descriptor = FetchDescriptor<Item>(
      predicate: #Predicate { $0.navigationID == navigationID })
    #expect(try modelContext.fetch(descriptor).map(\.navigationID) == [navigationID])
  }

  @Test func navigationIDSurvivesEveryEditableFieldSave() throws {
    let container = try ModelContainer(
      for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let modelContext = container.mainContext
    let item = Item(
      name: "Phone", category: .phone, purchaseDate: .now, purchasePrice: 100_000,
      targetMonths: 24)
    modelContext.insert(item)
    try modelContext.save()
    let navigationID = item.navigationID

    item.purchasePrice = 120_000
    try modelContext.save()
    #expect(item.navigationID == navigationID)

    item.name = "Updated Phone"
    try modelContext.save()
    #expect(item.navigationID == navigationID)

    item.category = .camera
    try modelContext.save()
    #expect(item.navigationID == navigationID)

    item.purchaseDate = Calendar.current.date(byAdding: .day, value: -1, to: item.purchaseDate)!
    try modelContext.save()
    #expect(item.navigationID == navigationID)

    item.targetMonths = 36
    try modelContext.save()
    #expect(item.navigationID == navigationID)
  }

  @Test func navigationIDResolvesTheCorrectItemAmongMultipleItems() throws {
    let container = try ModelContainer(
      for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let modelContext = container.mainContext
    let firstItem = Item(
      name: "First", category: .phone, purchaseDate: .now, purchasePrice: 100_000,
      targetMonths: 24)
    let secondItem = Item(
      name: "Second", category: .camera, purchaseDate: .now, purchasePrice: 200_000,
      targetMonths: 36)
    modelContext.insert(firstItem)
    modelContext.insert(secondItem)
    try modelContext.save()

    let navigationID = secondItem.navigationID
    let descriptor = FetchDescriptor<Item>(
      predicate: #Predicate { $0.navigationID == navigationID })
    #expect(try modelContext.fetch(descriptor).map(\.name) == ["Second"])
  }

  @Test func duplicateLegacyNavigationIDsAreRepairedBeforeRouting() throws {
    let container = try ModelContainer(
      for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let modelContext = container.mainContext
    let legacyNavigationID = UUID()
    let firstItem = Item(
      name: "First", category: .phone, purchaseDate: .now, purchasePrice: 100_000,
      targetMonths: 24)
    let secondItem = Item(
      name: "Second", category: .camera, purchaseDate: .now, purchasePrice: 200_000,
      targetMonths: 36)
    let thirdItem = Item(
      name: "Third", category: .computer, purchaseDate: .now, purchasePrice: 300_000,
      targetMonths: 48)
    let items = [firstItem, secondItem, thirdItem]
    for item in items {
      item.navigationID = legacyNavigationID
      modelContext.insert(item)
    }
    try modelContext.save()

    let routedNamesBeforeRepair = items.map { route in
      items.first(where: { $0.navigationID == route.navigationID })?.name
    }
    #expect(routedNamesBeforeRepair == ["First", "First", "First"])

    let repairedItems = Item.repairDuplicateNavigationIDs(in: items)
    try modelContext.save()

    #expect(repairedItems.count == 3)
    #expect(Set(items.map(\.navigationID)).count == 3)
    #expect(!items.map(\.navigationID).contains(legacyNavigationID))
    #expect(Item.repairDuplicateNavigationIDs(in: items).isEmpty)
    for item in items {
      let navigationID = item.navigationID
      let descriptor = FetchDescriptor<Item>(
        predicate: #Predicate { $0.navigationID == navigationID })
      #expect(try modelContext.fetch(descriptor).map(\.name) == [item.name])
    }
  }
}
