import Observation
import UIKit
import UserNotifications

@MainActor @Observable final class NotificationNavigation {
  static let shared = NotificationNavigation()
  var itemID: UUID?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    guard let value = response.notification.request.content.userInfo["itemID"] as? String,
      let itemID = UUID(uuidString: value)
    else { return }
    await MainActor.run { NotificationNavigation.shared.itemID = itemID }
  }
}
