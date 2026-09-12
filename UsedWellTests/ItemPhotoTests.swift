import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import UsedWell

struct ItemPhotoDraftTests {
  @Test func selectionIsDraftOnlyAndStaleResultsAreIgnored() {
    let original = Data([1])
    var draft = ItemPhotoDraft(original: original)
    draft.beginSelection()
    let old = draft.selectionID
    draft.beginSelection()
    let latest = draft.selectionID
    draft.finish(Data([2]), selectionID: old)
    #expect(draft.data == original && draft.isLoading)
    draft.finish(Data([3]), selectionID: latest)
    #expect(draft.data == Data([3]) && !draft.isLoading)
    draft.beginSelection()
    draft.finish(nil, selectionID: draft.selectionID)
    #expect(draft.data == Data([3]) && draft.loadFailed)
  }

  @Test func removeAndCancelInvalidatePendingSelection() {
    var draft = ItemPhotoDraft(original: Data([1]))
    draft.beginSelection()
    let selection = draft.selectionID
    draft.remove()
    draft.finish(Data([2]), selectionID: selection)
    #expect(draft.data == nil && !draft.isLoading)
    draft.beginSelection()
    let cancelled = draft.selectionID
    draft.cancelLoading()
    draft.finish(Data([3]), selectionID: cancelled)
    #expect(draft.data == nil)
    #expect(ItemPhotoDraft(original: Data([1])).data == Data([1]))
  }
}

struct ItemPhotoPipelineTests {
  @Test func invalidImageFailsWithoutProducingData() {
    #expect(throws: ItemPhotoPipeline.Failure.self) {
      try ItemPhotoPipeline.prepare(data: Data([0, 1, 2]))
    }
  }

  @Test func importDownsamplesAndNormalizesOrientationWithoutMetadata() throws {
    let bitmap = try #require(
      CGContext(
        data: nil, width: 3000, height: 1500, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    bitmap.setFillColor(UIColor.red.cgColor)
    bitmap.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
    let image = try #require(bitmap.makeImage())
    let input = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(input, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(
      destination, image,
      [
        kCGImagePropertyOrientation: 6,
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 35.0]
      ] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    let data = try ItemPhotoPipeline.prepare(data: input as Data)
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let properties = try #require(
      CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1024)
    #expect(properties[kCGImagePropertyPixelHeight] as? Int == 2048)
    #expect(properties[kCGImagePropertyGPSDictionary] == nil)
    let thumbnail = try ItemPhotoPipeline.thumbnail(data: data, maxPixelSize: 300)
    #expect(thumbnail.width == 150 && thumbnail.height == 300)
  }
}

@MainActor struct ItemPhotoPersistenceTests {
  private let failing = PersistenceCommit { _ in throw CocoaError(.fileWriteUnknown) }

  @Test func photoChangesAndDeletionShareTheItemCommitBoundary() throws {
    let store = try ModelContainer(
      for: Item.self, UsageNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = store.mainContext
    let original = Data(repeating: 17, count: 1_500_000)
    let replacement = Data(repeating: 42, count: 1_600_000)
    let item = Item(
      name: "Photo item", category: .camera, purchaseDate: .now, purchasePrice: 100,
      targetMonths: 36)
    try PersistenceCommit()(in: context) {
      context.insert(item)
      item.photoData = original
      item.usageNotes.append(UsageNote(date: .now, text: "Keep note"))
    }
    let id = item.navigationID
    for nextPhoto in [replacement, nil] as [Data?] {
      #expect(throws: (any Error).self) {
        try failing(in: context) {
          item.name = "Uncommitted"
          item.photoData = nextPhoto
        }
      }
      #expect(item.name == "Photo item" && item.photoData == original)
      #expect(!context.hasChanges)
    }
    try PersistenceCommit()(in: context) { item.photoData = replacement }
    #expect(item.photoData == replacement && item.navigationID == id)
    try PersistenceCommit()(in: context) { item.completedDate = .now }
    #expect(item.photoData == replacement)
    #expect(throws: (any Error).self) { try failing(in: context) { context.delete(item) } }
    #expect(item.photoData == replacement && item.usageNotes.count == 1)
    try PersistenceCommit()(in: context) { context.delete(item) }
    #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<UsageNote>()) == 0)
  }

  @Test func diskReopenPreservesOnlyCommittedPhotoAndDeletesItWithItem() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("photo.store")
    let photo = Data(repeating: 71, count: 1_500_000)
    do {
      let store = try container(url)
      let context = store.mainContext
      let item = Item(
        name: "Persistent", category: .bag, purchaseDate: .now, purchasePrice: 100, targetMonths: 36
      )
      try PersistenceCommit()(in: context) {
        context.insert(item)
        item.photoData = photo
      }
      #expect(throws: (any Error).self) { try failing(in: context) { item.photoData = nil } }
      #expect(item.photoData == photo)
    }
    do {
      let store = try container(url)
      let context = store.mainContext
      let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
      #expect(item.photoData == photo)
      try PersistenceCommit()(in: context) { item.photoData = nil }
    }
    do {
      let store = try container(url)
      let context = store.mainContext
      let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
      #expect(item.photoData == nil)
      try PersistenceCommit()(in: context) { item.photoData = photo }
      try PersistenceCommit()(in: context) { context.delete(item) }
    }
    let reopened = try container(url)
    #expect(try reopened.mainContext.fetchCount(FetchDescriptor<Item>()) == 0)
  }

  @Test func repeatedDiskReplacementAndFailedInsertionKeepOnlyCommittedState() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("replacements.store")
    var sizes: [Int] = []
    for generation in 0..<12 {
      do {
        let store = try container(url)
        let context = store.mainContext
        if generation == 0 {
          #expect(throws: (any Error).self) {
            try failing(in: context) {
              let discarded = Item(
                name: "Failed add", category: .phone, purchaseDate: .now,
                purchasePrice: 1, targetMonths: 12)
              context.insert(discarded)
              discarded.photoData = Data(repeating: 99, count: 1_500_000)
            }
          }
          #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
          try PersistenceCommit()(in: context) {
            context.insert(
              Item(
                name: "Replace", category: .phone, purchaseDate: .now,
                purchasePrice: 100, targetMonths: 12))
          }
        }
        let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
        try PersistenceCommit()(in: context) {
          item.photoData = Data(repeating: UInt8(generation), count: 1_500_000)
        }
      }
      let reopened = try container(url)
      let item = try #require(reopened.mainContext.fetch(FetchDescriptor<Item>()).first)
      #expect(item.photoData == Data(repeating: UInt8(generation), count: 1_500_000))
      sizes.append(try storeBytes(directory))
    }
    // Diagnostic evidence only: SwiftData owns blob garbage collection and WAL timing.
    print("PHOTO_STORE_BYTES_AFTER_REOPEN: \(sizes)")
    do {
      let store = try container(url)
      let item = try #require(store.mainContext.fetch(FetchDescriptor<Item>()).first)
      try PersistenceCommit()(in: store.mainContext) { store.mainContext.delete(item) }
    }
    let reopened = try container(url)
    #expect(try reopened.mainContext.fetchCount(FetchDescriptor<Item>()) == 0)
    print("PHOTO_STORE_BYTES_AFTER_DELETE: \(try storeBytes(directory))")
  }

  private func storeBytes(_ directory: URL) throws -> Int {
    let files = FileManager.default.enumerator(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
    var total = 0
    while let file = files?.nextObject() as? URL {
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      if values.isRegularFile == true { total += values.fileSize ?? 0 }
    }
    return total
  }

  @Test func legacyStoreMigratesOnIOSWithoutLosingItemsNotesOrIdentity() throws {
    let source = try #require(
      Bundle(for: PhotoFixtureBundle.self).url(
        forResource: "legacy-photo-v1", withExtension: "store"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("legacy.store")
    try FileManager.default.copyItem(at: source, to: url)
    let store = try container(url)
    let items = try store.mainContext.fetch(
      FetchDescriptor<Item>(sortBy: [SortDescriptor(\Item.name)]))
    #expect(items.count == 2)
    #expect(try store.mainContext.fetchCount(FetchDescriptor<UsageNote>()) == 4)
    for (index, item) in items.enumerated() {
      #expect(item.photoData == nil)
      #expect(item.name == (index == 0 ? "Legacy active" : "Legacy history"))
      #expect(item.purchasePrice == 123456 && item.targetMonths == 48 && item.category == .camera)
      #expect(item.purchaseDate == Date(timeIntervalSince1970: 1_700_000_000))
      #expect(item.createdAt == item.purchaseDate)
      #expect(
        item.completedDate == (index == 0 ? nil : item.purchaseDate.addingTimeInterval(86400 * 500))
      )
      #expect(item.usageNotes.count == 2 && item.sortedUsageNotes.first?.text == "Second note")
      #expect(
        item.navigationID.uuidString
          == (index == 0
            ? "11111111-1111-1111-1111-111111111111" : "22222222-2222-2222-2222-222222222222"))
      #expect(
        item.notificationID.uuidString
          == (index == 0
            ? "33333333-3333-3333-3333-333333333333" : "44444444-4444-4444-4444-444444444444"))
    }
  }

  private func container(_ url: URL) throws -> ModelContainer {
    try ModelContainer(for: Item.self, UsageNote.self, configurations: ModelConfiguration(url: url))
  }
}

private final class PhotoFixtureBundle: NSObject {}
