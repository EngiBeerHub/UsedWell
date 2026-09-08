import Foundation
import SwiftData
import Testing
import UserNotifications

@testable import UsedWell

/// Opt in on a disposable Simulator; changes its notification permission and only its fixture IDs.
@MainActor struct NotificationRuntimeTests {
  @Test(
    .enabled(if: ProcessInfo.processInfo.environment["USEDWELL_NOTIFICATION_RUNTIME"] == "1"),
    arguments: [false, true])
  func committedEditsCompletionAndDeletionReconcileWithUserNotifications(
    complete: Bool
  ) async throws {
    let center = UNUserNotificationCenter.current()
    let allowed = try await center.requestAuthorization(options: [.provisional, .alert, .sound])
    #expect(allowed)
    let store = try ModelContainer(
      for: Item.self, UsageNote.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = store.mainContext
    let item = Item(
      name: "Notification runtime fixture", category: .phone, purchaseDate: .now,
      purchasePrice: 100, targetMonths: 12)
    try PersistenceCommit()(in: context) { context.insert(item) }
    let id = item.notificationID
    let ids = Set(NotificationPlanner.identifiers(itemID: id))
    defer { center.removePendingNotificationRequests(withIdentifiers: Array(ids)) }
    func pending() async -> [UNNotificationRequest] {
      await center.pendingNotificationRequests().filter { ids.contains($0.identifier) }
    }
    var operations = NotificationOperations.live(center: center)
    operations.pending = pending
    let scheduler = NotificationScheduler(context: context, operations: operations)
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    #expect(await pending().count == 2)
    let failing = PersistenceCommit { _ in throw CocoaError(.fileWriteUnknown) }
    #expect(throws: (any Error).self) {
      try failing(in: context) { item.completedDate = .now }
    }
    await scheduler.reconcile()
    await scheduler.waitForUpdates()
    #expect(await pending().count == 2)
    for name in ["Second saved name", "Latest saved name"] {
      try PersistenceCommit()(in: context) { item.name = name }
      scheduler.requestUpdate(itemID: id)
    }
    await scheduler.waitForUpdates()
    #expect(await pending().count == 2)
    #expect(await pending().allSatisfy { $0.content.body.contains("Latest saved name") })
    if complete {
      try PersistenceCommit()(in: context) { item.completedDate = .now }
      scheduler.requestUpdate(itemID: id)
      await scheduler.waitForUpdates()
      #expect(await pending().isEmpty)
    }
    try PersistenceCommit()(in: context) { context.delete(item) }
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    #expect(await pending().isEmpty)
    withExtendedLifetime(store) {}
  }
}
