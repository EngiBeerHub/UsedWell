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
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
              Text("使用中 \(activeItems.count)点")
                .font(.subheadline).foregroundStyle(.secondary)
              Text("次に見直すもの").font(.headline).padding(.top, 8)
              if let item = activeItems.first {
                NavigationLink(value: item.navigationID) {
                  FeaturedItemCard(item: item, asOf: asOf)
                }.buttonStyle(.plain)
              }
              Text("使用中の愛用品").font(.headline).padding(.top, 8)
              ForEach(activeItems) { item in
                NavigationLink(value: item.navigationID) { ItemRow(item: item, asOf: asOf) }
                  .buttonStyle(.plain)
              }
              NavigationLink {
                HistoryView(notifications: notifications, asOf: asOf, commit: commit)
              } label: {
                HStack {
                  Label("これまで使ったもの", systemImage: "clock.arrow.circlepath")
                  Spacer()
                  Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.vertical, 20)
                .contentShape(Rectangle())
              }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
          }
          .background(Color(uiColor: .systemGroupedBackground))
        }
      }
      .navigationTitle(
        String(
          localized: LocalizedStringResource(
            "home.items.title", defaultValue: "愛用品", locale: locale))
      )
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
  let item: Item
  let asOf: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ItemDurationHeader(item: item, asOf: asOf)
      HomeItemContext(item: item, asOf: asOf, featured: true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24)
    )
    .contentShape(RoundedRectangle(cornerRadius: 24))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("featured-item")
  }
}

struct ItemRow: View {
  let item: Item
  let asOf: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ItemDurationHeader(item: item, asOf: asOf, prominent: false)
      HomeItemContext(item: item, asOf: asOf)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24)
    )
    .contentShape(RoundedRectangle(cornerRadius: 24))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("regular-item-\(item.navigationID)")
  }
}

private struct HomeItemContext: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date
  var featured = false

  var body: some View {
    let target = String(
      localized: LocalizedStringResource(
        "目標\(item.targetDurationText(locale: locale))", locale: locale))
    let percentage = item.progress(asOf: asOf).formatted(
      .percent.precision(.fractionLength(0)).locale(locale))
    let amount = item.currentDailyCost(asOf: asOf).formatted(
      .currency(code: locale.currency?.identifier ?? "JPY").precision(.fractionLength(0)).locale(
        locale))
    let cost = String(localized: LocalizedStringResource("1日 \(amount)", locale: locale))
    VStack(alignment: .leading, spacing: 10) {
      if featured {
        HomeContextLine(parts: [
          target, item.remainingText(asOf: asOf, usesDayPrecision: true, locale: locale)
        ])
        .font(.footnote)
        HomeContextLine(parts: [percentage, cost]).font(.caption)
        UsageProgressBar(progress: item.progress(asOf: asOf), status: item.status(asOf: asOf))
      } else {
        HomeContextLine(parts: [
          target, item.remainingText(asOf: asOf, usesDayPrecision: true, locale: locale), percentage
        ])
        .font(.caption)
        UsageProgressBar(progress: item.progress(asOf: asOf), status: item.status(asOf: asOf))
        Text(cost).font(.caption)
      }
    }
    .foregroundStyle(.secondary)
  }
}

/// Keeps each piece of context intact when a single line no longer fits.
private struct HomeContextLine: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  let parts: [String]

  var body: some View {
    if dynamicTypeSize.isAccessibilitySize {
      stacked
    } else {
      ViewThatFits(in: .horizontal) {
        Text(
          parts.joined(separator: locale.language.languageCode?.identifier == "ja" ? " ・ " : " · ")
        )
        .fixedSize()
        stacked
      }
    }
  }

  private var stacked: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(parts.indices, id: \.self) { index in
        Text(parts[index]).fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

struct StatusLabel: View {
  @Environment(\.locale) private var locale
  let item: Item
  let asOf: Date
  var homeFont: Font?

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: item.status(asOf: asOf).symbolName)
        .accessibilityHidden(homeFont != nil)
      Text(item.status(asOf: asOf).title(locale: locale))
    }
    .font(homeFont ?? .caption.weight(.semibold))
    .foregroundStyle(
      homeFont == nil && item.status(asOf: asOf) == .goalAchieved ? .green : .secondary
    )
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
