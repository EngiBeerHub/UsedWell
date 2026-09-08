import OSLog
import SwiftData
import SwiftUI

struct ContentView: View {
  let notifications: NotificationScheduler
  var commit = PersistenceCommit()
  var now: () -> Date = { .now }
  @State private var asOf = Date.now
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(RegionNotice.defaultsKey) private var acknowledgedRegion: String?
  @State private var noticeRegion: String?
  @State private var showsRegionNotice = false
  @Query private var items: [Item]
  @State private var navigationPath: [UUID] = []
  @State private var notificationNavigation = NotificationNavigation.shared
  @State private var showsAdd = false
  @State private var showsNotificationExplanation = false
  @State private var pendingNotificationItem: UUID?
  private var activeItems: [Item] { Item.activeItemsForReview(items, asOf: asOf) }
  private var hasHistory: Bool { items.contains(where: \.isCompleted) }
  var body: some View {
    NavigationStack(path: $navigationPath) {
      Group {
        if activeItems.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("愛用品を登録しましょう")
              .font(.title3.bold())
            Text("使った期間とコストを見える化して、\n納得できる買い替え時期を考えられます。")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button("最初の愛用品を登録") { showsAdd = true }.accessibilityIdentifier("add-first-item")
              .buttonStyle(.borderedProminent)
            if hasHistory {
              Divider().padding(.top, 4)
              NavigationLink {
                HistoryView(notifications: notifications, asOf: asOf, commit: commit)
              } label: {
                Label("これまで使ったもの", systemImage: "clock.arrow.circlepath")
              }
              .buttonStyle(.plain).foregroundStyle(.tint)
            }
          }
          .padding(.horizontal, 32)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List {
            Section("次に見直すもの") {
              if let item = activeItems.first {
                NavigationLink(value: item.navigationID) {
                  FeaturedItemCard(item: item, asOf: asOf)
                }
              }
            }
            Section("使用中の愛用品") {
              ForEach(activeItems) { item in
                NavigationLink(value: item.navigationID) { ItemRow(item: item, asOf: asOf) }
              }
            }
            Section {
              NavigationLink {
                HistoryView(notifications: notifications, asOf: asOf, commit: commit)
              } label: {
                Label("これまで使ったもの", systemImage: "clock.arrow.circlepath")
              }
            }
          }.listStyle(.insetGrouped)
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("愛用品を追加", systemImage: "plus") { showsAdd = true }.accessibilityIdentifier(
            "add-item")
        }
      }
      .navigationDestination(for: UUID.self) { navigationID in
        if let item = items.first(where: { $0.navigationID == navigationID }) {
          ItemDetailView(
            item: item, notifications: notifications, asOf: asOf, commit: commit,
            onAddReplacement: { showsAdd = true })
        } else {
          ContentUnavailableView("記録が見つかりません", systemImage: "questionmark.folder")
        }
      }
    }
    .sheet(isPresented: $showsAdd, onDismiss: handleAddDismiss) {
      NavigationStack {
        ItemEditorView(commit: commit) { id, isNew in
          notifications.requestUpdate(itemID: id)
          if isNew { pendingNotificationItem = id }
        }
      }
    }
    .alert("見直し時期を通知します", isPresented: $showsNotificationExplanation) {
      Button("通知を許可") { requestNotificationPermission() }
      Button("後で", role: .cancel) { pendingNotificationItem = nil }
    } message: {
      Text("愛用品を見直すタイミングになったらお知らせします。")
    }
    .alert("地域設定が変更されました", isPresented: $showsRegionNotice) {
      Button("確認") {
        acknowledgedRegion = noticeRegion
        noticeRegion = nil
      }
    } message: {
      Text("購入価格は自動換算されません。必要に応じて、既存アイテムの購入価格を現在の通貨に合わせて編集してください。")
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        refreshAsOf()
        checkRegion()
        refreshNotifications()
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
    ) { _ in
      refreshAsOf()
    }
    .onChange(of: navigationPath) { _, _ in checkRegion() }
    .onChange(of: showsAdd) { _, shown in
      if !shown { checkRegion() }
    }
    .onChange(of: showsNotificationExplanation) { _, shown in
      if !shown { checkRegion() }
    }
    .onChange(of: notificationNavigation.itemID) { _, itemID in
      openNotificationItem(itemID)
    }
    .onChange(of: items.map(\.navigationID)) { _, _ in
      refreshNotifications()
      openNotificationItem(notificationNavigation.itemID)
    }
    .task {
      refreshAsOf()
      if repairLegacyNotificationIDs() { await notifications.reconcile() }
      openNotificationItem(notificationNavigation.itemID)
      checkRegion()
    }
  }

  private func refreshAsOf() { asOf = now() }

  private func refreshNotifications() {
    guard repairLegacyNotificationIDs() else { return }
    Task { await notifications.reconcile() }
  }

  private func checkRegion() {
    guard !showsRegionNotice else { return }
    let region = Locale.current.region?.identifier ?? "JP"
    guard
      RegionNotice.needsAcknowledgement(
        previousRegion: acknowledgedRegion, currentRegion: region, hasItems: !items.isEmpty
      )
    else {
      acknowledgedRegion = region
      return
    }
    // Present from Home after any item flow or permission explanation has finished.
    guard navigationPath.isEmpty, !showsAdd, !showsNotificationExplanation,
      pendingNotificationItem == nil
    else { return }
    noticeRegion = region
    showsRegionNotice = true
  }

  private func handleAddDismiss() {
    guard let item = pendingNotificationItem else { return }
    Task {
      switch await notifications.authorizationStatus() {
      case .notDetermined:
        showsNotificationExplanation = true
      case .authorized, .provisional, .ephemeral:
        notifications.requestUpdate(itemID: item)
        pendingNotificationItem = nil
      default:
        pendingNotificationItem = nil
      }
    }
  }

  private func requestNotificationPermission() {
    guard let item = pendingNotificationItem else { return }
    Task {
      if await notifications.requestAuthorization() {
        notifications.requestUpdate(itemID: item)
      }
      pendingNotificationItem = nil
    }
  }

  private func openNotificationItem(_ itemID: UUID?) {
    guard let itemID, let item = items.first(where: { $0.notificationID == itemID }) else { return }
    navigationPath = [item.navigationID]
    notificationNavigation.itemID = nil
  }

  private func repairLegacyNotificationIDs() -> Bool {
    do {
      let repair = try commit(in: modelContext) { Item.repairDuplicateNotificationIDs(in: items) }
      for id in repair.staleIDs { notifications.requestUpdate(itemID: id) }
      for item in repair.repairedItems { notifications.requestUpdate(itemID: item.notificationID) }
      return true
    } catch {
      Logger(subsystem: "UsedWell", category: "Persistence")
        .error("Notification identity repair failed; retrying on next refresh")
      return false
    }
  }

}

private struct FeaturedItemCard: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: item.category.symbolName)
          .font(.title2)
          .foregroundStyle(.tint)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.name)
              .font(.headline)
              .lineLimit(1)
            Spacer(minLength: 8)
            ProgressText(item: item, asOf: asOf, featured: true)
          }
          StatusLabel(item: item, asOf: asOf)
        }
      }
      ProgressView(value: min(item.progress(asOf: asOf), 1))
        .tint(item.status(asOf: asOf).progressTint)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.remainingText(asOf: asOf, locale: locale))
          .font(.subheadline)
        ItemUsageSummary(item: item, asOf: asOf)
      }
      .foregroundStyle(.secondary)
      .padding(.leading, 40)
    }
    .padding(.vertical, 8)
    .accessibilityIdentifier("featured-item")
  }
}

struct ItemRow: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: item.category.symbolName)
        .font(.title3)
        .foregroundStyle(.tint)
        .frame(width: 28, height: 28)
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          Text(item.name)
            .font(.headline)
            .lineLimit(1)
          Spacer(minLength: 8)
          ProgressText(item: item, asOf: asOf)
        }
        ProgressView(value: min(item.progress(asOf: asOf), 1))
          .controlSize(.small)
          .tint(item.status(asOf: asOf).progressTint)
        StatusLabel(item: item, asOf: asOf)
        ItemUsageSummary(item: item, asOf: asOf)
      }
    }
    .padding(.vertical, 5)
  }
}

private struct ProgressText: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date
  var featured = false

  var body: some View {
    Text(item.progress(asOf: asOf), format: .percent.precision(.fractionLength(0)))
      .font(featured ? .title2.bold() : .subheadline.bold())
      .monospacedDigit()
      .fixedSize(horizontal: true, vertical: false)
      .foregroundStyle(.primary)
  }
}

extension ReplacementStatus {
  fileprivate var progressTint: Color {
    switch self {
    case .stillUsing: .accentColor
    case .considerReplacing: .orange
    case .goalAchieved: .green
    }
  }
}

private struct ItemUsageSummary: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date

  var body: some View {
    let duration = item.usageDurationText(asOf: asOf, locale: locale)
    let target = item.targetDurationText(locale: locale)
    let cost = item.currentDailyCost(asOf: asOf).formatted(
      .currency(code: locale.currency?.identifier ?? "JPY").precision(.fractionLength(0)).locale(
        locale))
    Text(
      "使用期間 \(duration) / 目標\(target) ・ 1日 \(cost)"
    )
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}

struct StatusLabel: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: item.status(asOf: asOf).symbolName)
      Text(item.status(asOf: asOf).title(locale: locale))
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(item.status(asOf: asOf) == .goalAchieved ? .green : .secondary)
  }
}

#if DEBUG
  #Preview("Japanese") {
    let container = ScreenshotFixtures.previewContainer(locale: Locale(identifier: "ja_JP"))
    ContentView(notifications: NotificationScheduler(context: container.mainContext))
      .modelContainer(container)
      .environment(\.locale, Locale(identifier: "ja_JP"))
      .defaultAppStorage(UserDefaults(suiteName: "UsedWell.Previews") ?? .standard)
  }

  #Preview("English") {
    let container = ScreenshotFixtures.previewContainer(locale: Locale(identifier: "en_US"))
    ContentView(notifications: NotificationScheduler(context: container.mainContext))
      .modelContainer(container)
      .environment(\.locale, Locale(identifier: "en_US"))
      .defaultAppStorage(UserDefaults(suiteName: "UsedWell.Previews") ?? .standard)
  }
#endif
