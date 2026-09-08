import Foundation
import OSLog
import SwiftData
import UserNotifications

enum NotificationMilestone: String, Sendable {
  case review = "90"
  case goal = "100"

  func title(locale: Locale = .current) -> String {
    switch self {
    case .review: String(localized: LocalizedStringResource("そろそろ見直しどきです", locale: locale))
    case .goal: String(localized: LocalizedStringResource("使用目標に到達しました", locale: locale))
    }
  }

  func body(itemName: String, locale: Locale = .current) -> String {
    switch self {
    case .review:
      String(localized: LocalizedStringResource("\(itemName)が使用目標の90%に達しました。", locale: locale))
    case .goal:
      String(
        localized: LocalizedStringResource(
          "\(itemName)を目標期間まで使いました。これからも使うか、見直してみましょう。", locale: locale))
    }
  }
}

struct ItemNotificationDetails: Sendable {
  let id: UUID
  let name: String
  let purchaseDate: Date
  let targetMonths: Int
  let isCompleted: Bool

  init(id: UUID, name: String, purchaseDate: Date, targetMonths: Int, isCompleted: Bool) {
    self.id = id
    self.name = name
    self.purchaseDate = purchaseDate
    self.targetMonths = targetMonths
    self.isCompleted = isCompleted
  }

  @MainActor init(item: Item) {
    id = item.notificationID
    name = item.name
    purchaseDate = item.purchaseDate
    targetMonths = item.targetMonths
    isCompleted = item.isCompleted
  }
}

struct PlannedNotification: Equatable, Sendable {
  let identifier: String
  let milestone: NotificationMilestone
  let date: Date
}

enum NotificationPlanner {
  static func plans(
    for item: ItemNotificationDetails, after date: Date = .now, calendar: Calendar = .current
  ) -> [PlannedNotification] {
    guard !item.isCompleted else { return [] }

    let purchaseDay = calendar.startOfDay(for: item.purchaseDate)
    guard let targetDay = calendar.date(byAdding: .month, value: item.targetMonths, to: purchaseDay)
    else { return [] }
    let targetDays = max(
      1, calendar.dateComponents([.day], from: purchaseDay, to: targetDay).day ?? 1)
    let reviewDays = Int(ceil(Double(targetDays) * 0.9))
    let reviewDay = calendar.date(byAdding: .day, value: reviewDays, to: purchaseDay)

    return [(.review, reviewDay), (.goal, targetDay)].compactMap { milestone, milestoneDay in
      guard let milestoneDay,
        let milestoneDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: milestoneDay)
      else { return nil }
      guard milestoneDate > date else { return nil }
      return PlannedNotification(
        identifier: identifier(itemID: item.id, milestone: milestone),
        milestone: milestone,
        date: milestoneDate)
    }
  }

  static func identifiers(itemID: UUID) -> [String] {
    [NotificationMilestone.review, .goal].map { identifier(itemID: itemID, milestone: $0) }
  }

  private static func identifier(itemID: UUID, milestone: NotificationMilestone) -> String {
    "usedwell.item.\(itemID.uuidString).\(milestone.rawValue)"
  }
}

/// Only the OS boundary is replaceable; planning and ordering always run through the real scheduler.
@MainActor struct NotificationOperations {
  var authorizationStatus: () async -> UNAuthorizationStatus
  var requestAuthorization: () async throws -> Bool
  var add: (UNNotificationRequest) async throws -> Void
  var remove: ([String]) -> Void
  var pending: () async -> [UNNotificationRequest]

  static func live(center: UNUserNotificationCenter = .current()) -> Self {
    Self(
      authorizationStatus: { await center.notificationSettings().authorizationStatus },
      requestAuthorization: { try await center.requestAuthorization(options: [.alert, .sound]) },
      add: { try await center.add($0) },
      remove: { center.removePendingNotificationRequests(withIdentifiers: $0) },
      pending: { await center.pendingNotificationRequests() })
  }
}

@MainActor final class NotificationScheduler {
  private let readItem: (UUID) throws -> ItemNotificationDetails?
  private let readIDs: () throws -> [UUID]
  private let operations: NotificationOperations
  private let now: () -> Date
  private var generations: [UUID: UUID] = [:]
  private var workers: [UUID: Task<Void, Never>] = [:]
  private let logger = Logger(subsystem: "UsedWell", category: "Notifications")

  convenience init(context: ModelContext, operations: NotificationOperations? = nil) {
    self.init(
      readItem: { id in
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.notificationID == id })
        return try context.fetch(descriptor).first.map(ItemNotificationDetails.init(item:))
      },
      readIDs: { try context.fetch(FetchDescriptor<Item>()).map(\.notificationID) },
      operations: operations ?? .live())
  }

  init(
    readItem: @escaping (UUID) throws -> ItemNotificationDetails?,
    readIDs: @escaping () throws -> [UUID], operations: NotificationOperations,
    now: @escaping () -> Date = { .now }
  ) {
    self.readItem = readItem
    self.readIDs = readIDs
    self.operations = operations
    self.now = now
  }

  func authorizationStatus() async -> UNAuthorizationStatus {
    await operations.authorizationStatus()
  }

  func requestAuthorization() async -> Bool {
    do { return try await operations.requestAuthorization() } catch {
      logger.error(
        "Notification permission request failed: \(String(describing: error), privacy: .public)")
      return false
    }
  }

  /// Call synchronously immediately after committing, before yielding or dismissing the editor.
  func requestUpdate(itemID: UUID) {
    generations[itemID] = UUID()
    guard workers[itemID] == nil else { return }
    // Owned by this scheduler, not by a sheet task. An in-flight OS add must finish before cleanup.
    workers[itemID] = Task { await drain(itemID: itemID) }
  }

  func reconcile() async {
    do {
      let ids = Set(try readIDs())
      let pendingIDs = await operations.pending().compactMap { Self.itemID(in: $0.identifier) }
      for id in ids.union(pendingIDs) { requestUpdate(itemID: id) }
    } catch {
      logger.error(
        "Notification reconciliation failed: \(String(describing: error), privacy: .public)")
    }
  }

  private func drain(itemID: UUID) async {
    defer {
      workers[itemID] = nil
      generations[itemID] = nil
    }
    while let generation = generations[itemID] {
      do {
        // Fetch errors are not deletions: leave existing reservations alone and retry on reconcile.
        _ = try readItem(itemID)
        let status = await operations.authorizationStatus()
        guard generations[itemID] == generation else { continue }
        let item = try readItem(itemID)
        guard await removeExisting(itemID: itemID) else {
          logger.error("Pending notification removal unconfirmed; deferring update")
          return
        }
        guard generations[itemID] == generation else { continue }
        let canNotify = [.authorized, .provisional, .ephemeral].contains(status)
        if let item, !item.isCompleted, canNotify {
          for plan in NotificationPlanner.plans(for: item, after: now()) {
            guard generations[itemID] == generation else { break }
            // Recheck time after an earlier add; do not backfill a milestone that has just passed.
            guard plan.date > now() else { continue }
            try await operations.add(request(plan, item: item))
            // If a newer commit arrived during add, the next iteration removes this stale add
            // before writing anything from the new generation. Never cancel this await early.
          }
        }
      } catch {
        logger.error("Notification update failed: \(String(describing: error), privacy: .public)")
      }
      if generations[itemID] == generation { return }
    }
  }

  private func removeExisting(itemID: UUID) async -> Bool {
    let identifiers = Set(NotificationPlanner.identifiers(itemID: itemID))
    let existing = await operations.pending().map(\.identifier).filter { identifiers.contains($0) }
    guard !existing.isEmpty else { return true }
    operations.remove(existing)
    // One OS round trip to confirm removal. If still pending, do not overlap reservations or
    // spin/poll: the next foreground/commit reconciliation will retry from persisted state.
    return await operations.pending().allSatisfy { !identifiers.contains($0.identifier) }
  }

  private func request(
    _ plan: PlannedNotification, item: ItemNotificationDetails
  ) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = plan.milestone.title()
    content.body = plan.milestone.body(itemName: item.name)
    content.sound = .default
    content.userInfo = ["itemID": item.id.uuidString]
    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute], from: plan.date)
    return UNNotificationRequest(
      identifier: plan.identifier, content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
  }

  private static func itemID(in identifier: String) -> UUID? {
    let parts = identifier.split(separator: ".")
    guard parts.count == 4, parts[0] == "usedwell", parts[1] == "item",
      parts[3] == "90" || parts[3] == "100"
    else { return nil }
    return UUID(uuidString: String(parts[2]))
  }

  /// Also lets tests wait for OS completion without timing assumptions or canceling a worker.
  func waitForUpdates() async {
    while let worker = workers.values.first { await worker.value }
  }
}
