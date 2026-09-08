import Foundation
import Testing
import UserNotifications

@testable import UsedWell

@MainActor struct NotificationSchedulerTests {
  enum Change: CaseIterable { case edit, complete, delete }

  @Test(arguments: [0, 1, 2, 3, 4], Change.allCases)
  func newerCommitWinsAcrossEverySuspension(blockedOperation: Int, change: Change) async {
    let fixture = NotificationFixture()
    let id = fixture.item!.id
    let barrier = NotificationBarrier()
    let scheduler = fixture.scheduler()
    if blockedOperation >= 3 {
      scheduler.requestUpdate(itemID: id)
      await scheduler.waitForUpdates()
      fixture.pendingCount = 0
      fixture.blockedPending = (blockedOperation - 2, barrier)
    }
    if blockedOperation == 0 {
      fixture.authorizationBarrier = barrier
    } else if blockedOperation < 3 {
      fixture.blockedAdd = (blockedOperation, barrier)
    }
    scheduler.requestUpdate(itemID: id)
    await barrier.waitForArrival()
    fixture.change(change)
    scheduler.requestUpdate(itemID: id)
    barrier.release()
    await scheduler.waitForUpdates()
    if change == .edit {
      #expect(fixture.pending.count == 2)
      #expect(fixture.pending.values.allSatisfy { $0.content.body.contains("Latest name") })
      let expected = NotificationPlanner.plans(for: fixture.item!, after: fixture.now)
      for plan in expected {
        let request = fixture.pending[plan.identifier]
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        #expect(
          trigger?.dateComponents
            == Calendar.current.dateComponents(
              [.year, .month, .day, .hour, .minute], from: plan.date))
      }
    } else {
      #expect(fixture.pending.isEmpty)
    }
    // Older cleanup must not run after the latest two reservations have been written.
    #expect(!fixture.overlappedIdentifier)
  }

  @Test func unconfirmedRemovalDefersAddsUntilReconcile() async {
    let fixture = NotificationFixture()
    let id = fixture.item!.id
    let scheduler = fixture.scheduler()
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    let old = fixture.pending
    fixture.removalDelayed = true
    fixture.change(.edit)
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    #expect(fixture.addCount == 2)
    #expect(fixture.pending.keys == old.keys)
    #expect(fixture.pending.values.allSatisfy { !$0.content.body.contains("Latest name") })
    fixture.finishRemoval()
    await scheduler.reconcile()
    await scheduler.waitForUpdates()
    #expect(fixture.addCount == 4)
    #expect(fixture.pending.values.allSatisfy { $0.content.body.contains("Latest name") })
    #expect(!fixture.overlappedIdentifier)
  }

  @Test func deniedPermissionAndDeletionRemoveExistingReservations() async {
    let fixture = NotificationFixture()
    let id = fixture.item!.id
    let scheduler = fixture.scheduler()
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    fixture.status = .denied
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    #expect(fixture.pending.isEmpty)
    fixture.status = .authorized
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    fixture.item = nil
    // New scheduler simulates relaunch after a committed deletion without its OS cleanup.
    let relaunched = fixture.scheduler()
    await relaunched.reconcile()
    await relaunched.waitForUpdates()
    #expect(fixture.pending.isEmpty)
  }

  @Test func readFailureIsNotTreatedAsDeletionAndCanRetry() async {
    let fixture = NotificationFixture()
    let id = fixture.item!.id
    let scheduler = fixture.scheduler()
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    fixture.readFails = true
    scheduler.requestUpdate(itemID: id)
    await scheduler.waitForUpdates()
    #expect(fixture.pending.count == 2)
    #expect(fixture.removed.isEmpty)
    fixture.readFails = false
    fixture.change(.complete)
    await scheduler.reconcile()
    await scheduler.waitForUpdates()
    #expect(fixture.pending.isEmpty)
  }

  @Test func osAddFailureCanRetryWithoutOverlappingIdentifiers() async {
    let fixture = NotificationFixture()
    let scheduler = fixture.scheduler()
    fixture.failedAdd = 2
    scheduler.requestUpdate(itemID: fixture.item!.id)
    await scheduler.waitForUpdates()
    #expect(fixture.pending.count == 1)
    await scheduler.reconcile()
    await scheduler.waitForUpdates()
    #expect(fixture.pending.count == 2)
    #expect(!fixture.overlappedIdentifier)
  }

  @Test func dismissingCallerDoesNotCancelInFlightCleanup() async {
    let fixture = NotificationFixture()
    let barrier = NotificationBarrier()
    fixture.blockedAdd = (1, barrier)
    let scheduler = fixture.scheduler()
    let id = fixture.item!.id
    let caller = Task { scheduler.requestUpdate(itemID: id) }
    await barrier.waitForArrival()
    caller.cancel()
    fixture.item = nil
    scheduler.requestUpdate(itemID: id)
    barrier.release()
    await scheduler.waitForUpdates()
    #expect(fixture.pending.isEmpty)
  }

  @Test func milestonesPassingDuringAddAreNotBackfilled() async {
    let fixture = NotificationFixture()
    let barrier = NotificationBarrier()
    fixture.blockedAdd = (1, barrier)
    let scheduler = fixture.scheduler()
    scheduler.requestUpdate(itemID: fixture.item!.id)
    await barrier.waitForArrival()
    fixture.now = .distantFuture
    barrier.release()
    await scheduler.waitForUpdates()
    #expect(fixture.addCount == 1)
  }
}

@MainActor private final class NotificationBarrier {
  private var arrived = false
  private var arrival: CheckedContinuation<Void, Never>?
  private var continuation: CheckedContinuation<Void, Never>?

  func suspend() async {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
      arrived = true
      arrival?.resume()
      arrival = nil
    }
  }

  func waitForArrival() async {
    if arrived { return }
    await withCheckedContinuation { arrival = $0 }
  }

  func release() {
    continuation?.resume()
    continuation = nil
  }
}

@MainActor private final class NotificationFixture {
  var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
  var item: ItemNotificationDetails?
  var pending: [String: UNNotificationRequest] = [:]
  var status: UNAuthorizationStatus = .authorized
  var authorizationBarrier: NotificationBarrier?
  var blockedAdd: (Int, NotificationBarrier)?
  var blockedPending: (Int, NotificationBarrier)?
  var pendingCount = 0
  var failedAdd: Int?
  var addCount = 0
  var readFails = false
  var overlappedIdentifier = false
  var removalDelayed = false
  var removed: [String] = []

  init() {
    item = ItemNotificationDetails(
      id: UUID(), name: "Original name", purchaseDate: now, targetMonths: 12, isCompleted: false)
  }

  func change(_ change: NotificationSchedulerTests.Change) {
    guard let old = item else { return }
    item =
      change == .delete
      ? nil
      : ItemNotificationDetails(
        id: old.id, name: "Latest name", purchaseDate: old.purchaseDate, targetMonths: 24,
        isCompleted: change == .complete)
  }

  func finishRemoval() {
    for id in removed { pending[id] = nil }
    removalDelayed = false
  }

  func scheduler() -> NotificationScheduler {
    NotificationScheduler(
      readItem: { [self] _ in
        if readFails { throw CocoaError(.fileReadUnknown) }
        return item
      }, readIDs: { [self] in item.map { [$0.id] } ?? [] },
      operations: NotificationOperations(
        authorizationStatus: { [self] in
          let barrier = authorizationBarrier
          authorizationBarrier = nil
          await barrier?.suspend()
          return status
        }, requestAuthorization: { true },
        add: { [self] request in
          addCount += 1
          if blockedAdd?.0 == addCount { await blockedAdd?.1.suspend() }
          if failedAdd == addCount { throw CocoaError(.fileWriteUnknown) }
          if pending[request.identifier] != nil { overlappedIdentifier = true }
          pending[request.identifier] = request
        },
        remove: { [self] ids in
          removed += ids
          if !removalDelayed { for id in ids { pending[id] = nil } }
        },
        pending: { [self] in
          pendingCount += 1
          if blockedPending?.0 == pendingCount { await blockedPending?.1.suspend() }
          return Array(pending.values)
        }),
      now: { [self] in now })
  }
}
