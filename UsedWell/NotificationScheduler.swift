import Foundation
import UserNotifications

enum NotificationMilestone: String, Sendable {
  case review = "90"
  case goal = "100"

  func title() -> String {
    switch self {
    case .review: "そろそろ見直しどきです"
    case .goal: "使用目標に到達しました"
    }
  }

  func body(itemName: String) -> String {
    switch self {
    case .review: "\(itemName)が使用目標の90%に達しました。"
    case .goal: "\(itemName)を目標期間まで使いました。これからも使うか、見直してみましょう。"
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

final class NotificationScheduler: Sendable {
  static let shared = NotificationScheduler()
  private let center = UNUserNotificationCenter.current()

  func authorizationStatus() async -> UNAuthorizationStatus {
    await center.notificationSettings().authorizationStatus
  }

  func requestAuthorization() async -> Bool {
    (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
  }

  func rescheduleIfAuthorized(_ item: ItemNotificationDetails) async {
    let status = await authorizationStatus()
    guard status == .authorized || status == .provisional || status == .ephemeral else {
      cancel(itemID: item.id)
      return
    }
    await reschedule(item)
  }

  func reschedule(_ item: ItemNotificationDetails, after date: Date = .now) async {
    cancel(itemID: item.id)
    for plan in NotificationPlanner.plans(for: item, after: date) {
      let content = UNMutableNotificationContent()
      content.title = plan.milestone.title()
      content.body = plan.milestone.body(itemName: item.name)
      content.sound = .default
      content.userInfo = ["itemID": item.id.uuidString]

      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: plan.date)
      let request = UNNotificationRequest(
        identifier: plan.identifier,
        content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
      try? await center.add(request)
    }
  }

  func cancel(itemID: UUID) {
    center.removePendingNotificationRequests(
      withIdentifiers: NotificationPlanner.identifiers(itemID: itemID))
  }
}
