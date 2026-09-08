//
//  UsedWellApp.swift
//  UsedWell
//
//  Created by RyosukeSeki on 2026/08/23.
//

import SwiftData
import SwiftUI

@main
struct UsedWellApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  private let sharedModelContainer: ModelContainer
  private let notifications: NotificationScheduler
  private let commit: PersistenceCommit

  init() {
    let container = Self.makeContainer()
    sharedModelContainer = container
    notifications = NotificationScheduler(context: container.mainContext)
    #if DEBUG
      commit = ScreenshotFixtures.makeCommit()
    #else
      commit = PersistenceCommit()
    #endif
  }

  private static func makeContainer() -> ModelContainer {
    #if DEBUG
      if let mode = ScreenshotFixtures.mode {
        do { return try ScreenshotFixtures.makeContainer(mode: mode) } catch {
          fatalError("Failed to create isolated fixtures: \(error)")
        }
      }
    #endif
    let schema = Schema([Item.self, UsageNote.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      let items = try container.mainContext.fetch(FetchDescriptor<Item>())
      try PersistenceCommit()(in: container.mainContext) {
        _ = Item.repairDuplicateNavigationIDs(in: items)
      }
      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }

  private let preferences: UserDefaults = {
    #if DEBUG
      if ScreenshotFixtures.mode != nil {
        let suiteName = "UsedWell.UITests"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        if ProcessInfo.processInfo.environment["USEDWELL_RESET_PREFERENCES"] == "1" {
          defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
      }
    #endif
    return .standard
  }()

  var body: some Scene {
    WindowGroup {
      Group {
        #if DEBUG
          if ScreenshotFixtures.mode == "day-boundary" {
            DateRefreshFixture(notifications: notifications, commit: commit)
          } else {
            ContentView(notifications: notifications, commit: commit)
          }
        #else
          ContentView(notifications: notifications, commit: commit)
        #endif
      }.defaultAppStorage(preferences)
    }
    .modelContainer(sharedModelContainer)
  }
}
