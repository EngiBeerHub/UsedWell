import Foundation
import SwiftData
import Testing

@testable import UsedWell

@MainActor struct PersistenceCommitTests {
  private let failing = PersistenceCommit { _ in throw CocoaError(.fileWriteUnknown) }

  @Test func failedInsertCanRetryWithoutDuplicateRecords() throws {
    let store = try container()
    defer { withExtendedLifetime(store) {} }
    let context = store.mainContext
    let draftName = "Keep this draft"
    func insert() -> Item {
      let item = makeItem(name: draftName)
      context.insert(item)
      return item
    }
    #expect(throws: (any Error).self) { try failing(in: context, applying: insert) }
    #expect(!context.hasChanges)
    #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
    let saved = try PersistenceCommit()(in: context, applying: insert)
    #expect(saved.name == draftName)
    #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
  }

  @Test func failedItemEditAndCompletionRestoreCommittedState() throws {
    let store = try container()
    defer { withExtendedLifetime(store) {} }
    let context = store.mainContext
    let item = makeItem()
    context.insert(item)
    try context.save()
    let purchaseDate = item.purchaseDate
    #expect(throws: (any Error).self) {
      try failing(in: context) {
        item.category = .camera
        item.purchaseDate = .distantPast
        item.name = "Unsaved name"
        item.purchasePrice = 123
        item.targetMonths = 1
        item.completedDate = .now
      }
    }
    #expect(item.name == "Phone")
    #expect(item.category == .phone)
    #expect(item.purchaseDate == purchaseDate)
    #expect(item.purchasePrice == 120_000)
    #expect(item.targetMonths == 36)
    #expect(!item.isCompleted)
    #expect(!context.hasChanges)
    #expect(Item.activeItemsForReview([item], asOf: .now).count == 1)
    let completion = Date(timeIntervalSince1970: 1_700_000_000)
    try PersistenceCommit()(in: context) { item.completedDate = completion }
    #expect(item.completedDate == completion)
    #expect(Item.activeItemsForReview([item], asOf: .now).isEmpty)
  }

  @Test func failedNoteInsertEditAndDeleteRestoreRelationships() throws {
    let store = try container()
    defer { withExtendedLifetime(store) {} }
    let context = store.mainContext
    let item = makeItem()
    context.insert(item)
    try context.save()
    func insertNote() {
      let note = UsageNote(date: .now, text: "Committed body")
      context.insert(note)
      item.usageNotes.append(note)
    }
    #expect(throws: (any Error).self) { try failing(in: context, applying: insertNote) }
    #expect(item.usageNotes.isEmpty)
    #expect(try context.fetchCount(FetchDescriptor<UsageNote>()) == 0)
    try PersistenceCommit()(in: context, applying: insertNote)
    let note = try #require(item.usageNotes.first)
    let oldDate = note.date
    let oldUpdatedAt = note.updatedAt
    #expect(throws: (any Error).self) {
      try failing(in: context) {
        note.text = "Unsaved body"
        note.date = .distantPast
        note.updatedAt = .distantFuture
      }
    }
    #expect(note.text == "Committed body")
    #expect(note.date == oldDate)
    #expect(note.updatedAt == oldUpdatedAt)
    #expect(throws: (any Error).self) {
      try failing(in: context) {
        item.usageNotes.removeAll { $0.persistentModelID == note.persistentModelID }
        context.delete(note)
      }
    }
    #expect(item.usageNotes.count == 1)
    #expect(note.item === item)
    #expect(!context.hasChanges)
    try PersistenceCommit()(in: context) { note.text = "Retried body" }
    #expect(note.text == "Retried body")
    try PersistenceCommit()(in: context) {
      item.usageNotes.removeAll()
      context.delete(note)
    }
    #expect(item.usageNotes.isEmpty)
    #expect(try context.fetchCount(FetchDescriptor<UsageNote>()) == 0)
  }

  @Test(arguments: [false, true])
  func failedItemDeleteRestoresItemAndNotes(completed: Bool) throws {
    let store = try container()
    defer { withExtendedLifetime(store) {} }
    let context = store.mainContext
    let item = makeItem()
    if completed { item.completedDate = .now }
    context.insert(item)
    item.usageNotes.append(UsageNote(date: .now, text: "Keep me"))
    try context.save()
    let id = item.navigationID
    #expect(throws: (any Error).self) { try failing(in: context) { context.delete(item) } }
    #expect(item.navigationID == id)
    #expect(item.isCompleted == completed)
    #expect(item.usageNotes.first?.text == "Keep me")
    #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<UsageNote>()) == 1)
    #expect(!context.hasChanges)
    try PersistenceCommit()(in: context) { context.delete(item) }
    #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<UsageNote>()) == 0)
  }

  @Test func unrelatedChangesAreNeitherCommittedNorDiscarded() throws {
    let store = try container()
    defer { withExtendedLifetime(store) {} }
    let context = store.mainContext
    let item = makeItem()
    context.insert(item)
    var attempted = false
    #expect(throws: PersistenceCommit.Failure.self) {
      try PersistenceCommit()(in: context) { attempted = true }
    }
    #expect(!attempted)
    #expect(context.hasChanges)
    #expect(item.modelContext === context)
  }

  @Test func failedIdentityRepairRollsBackBeforeAnySideEffect() throws {
    let store = try container()
    defer { withExtendedLifetime(store) {} }
    let context = store.mainContext
    let first = makeItem()
    let second = makeItem()
    second.notificationID = first.notificationID
    let original = first.notificationID
    context.insert(first)
    context.insert(second)
    try context.save()
    #expect(throws: (any Error).self) {
      try failing(in: context) { Item.repairDuplicateNotificationIDs(in: [first, second]) }
    }
    #expect(first.notificationID == original)
    #expect(second.notificationID == original)
    #expect(!context.hasChanges)
    let repair = try PersistenceCommit()(in: context) {
      Item.repairDuplicateNotificationIDs(in: [first, second])
    }
    #expect(repair.staleIDs == [original])
    #expect(first.notificationID != second.notificationID)
  }

  @Test func diskReopenObservesOnlySuccessfulOperations() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("test.store")
    let completion = Date(timeIntervalSince1970: 1_700_000_000)
    do {
      let store = try container(url: url)
      let context = store.mainContext
      let item = makeItem()
      try PersistenceCommit()(in: context) {
        context.insert(item)
        item.usageNotes.append(UsageNote(date: completion, text: "Saved note"))
      }
      #expect(throws: (any Error).self) {
        try failing(in: context) { item.name = "Must not persist" }
      }
      #expect(throws: (any Error).self) {
        try failing(in: context) { item.usageNotes.first?.text = "Must not persist" }
      }
      try PersistenceCommit()(in: context) { item.completedDate = completion }
      #expect(throws: (any Error).self) {
        try failing(in: context) { context.delete(item) }
      }
    }
    let reopened = try container(url: url)
    let item = try #require(reopened.mainContext.fetch(FetchDescriptor<Item>()).first)
    #expect(item.name == "Phone")
    #expect(item.completedDate == completion)
    #expect(item.usageNotes.first?.text == "Saved note")
  }

  private func container(url: URL? = nil) throws -> ModelContainer {
    let config =
      url.map { ModelConfiguration(url: $0) }
      ?? ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Item.self, UsageNote.self, configurations: config)
  }

  private func makeItem(name: String = "Phone") -> Item {
    Item(name: name, category: .phone, purchaseDate: .now, purchasePrice: 120_000, targetMonths: 36)
  }
}
