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
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([Item.self, UsageNote.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      let items = try container.mainContext.fetch(FetchDescriptor<Item>())
      if !Item.repairDuplicateNavigationIDs(in: items).isEmpty {
        try container.mainContext.save()
      }
      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
