import SwiftData
import SwiftUI

struct ContentView: View {
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
  @State private var pendingNotificationItem: ItemNotificationDetails?
  private var activeItems: [Item] {
    items.filter { !$0.isCompleted }.sorted {
      let lhs = $0.reviewPriority()
      let rhs = $1.reviewPriority()
      return lhs.0 == rhs.0 ? lhs.1 > rhs.1 : lhs.0 > rhs.0
    }
  }
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
                HistoryView()
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
                NavigationLink(value: item.navigationID) { FeaturedItemCard(item: item) }
              }
            }
            Section("使用中の愛用品") {
              ForEach(activeItems) { item in
                NavigationLink(value: item.navigationID) { ItemRow(item: item) }
              }
            }
            Section {
              NavigationLink {
                HistoryView()
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
          ItemDetailView(item: item, onAddReplacement: { showsAdd = true })
        } else {
          ContentUnavailableView("記録が見つかりません", systemImage: "questionmark.folder")
        }
      }
    }
    .sheet(isPresented: $showsAdd, onDismiss: handleAddDismiss) {
      NavigationStack {
        ItemEditorView { item, isNew in
          if isNew { pendingNotificationItem = item }
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
      if phase == .active { checkRegion() }
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
      Task { await repairLegacyNotificationIDs() }
      openNotificationItem(notificationNavigation.itemID)
    }
    .task {
      await repairLegacyNotificationIDs()
      for item in items where !item.isCompleted {
        await NotificationScheduler.shared.rescheduleIfAuthorized(
          ItemNotificationDetails(item: item))
      }
      openNotificationItem(notificationNavigation.itemID)
      checkRegion()
    }
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
      switch await NotificationScheduler.shared.authorizationStatus() {
      case .notDetermined:
        showsNotificationExplanation = true
      case .authorized, .provisional, .ephemeral:
        await NotificationScheduler.shared.reschedule(item)
        pendingNotificationItem = nil
      default:
        pendingNotificationItem = nil
      }
    }
  }

  private func requestNotificationPermission() {
    guard let item = pendingNotificationItem else { return }
    Task {
      if await NotificationScheduler.shared.requestAuthorization() {
        await NotificationScheduler.shared.reschedule(item)
      }
      pendingNotificationItem = nil
    }
  }

  private func openNotificationItem(_ itemID: UUID?) {
    guard let itemID, let item = items.first(where: { $0.notificationID == itemID }) else { return }
    navigationPath = [item.navigationID]
    notificationNavigation.itemID = nil
  }

  private func repairLegacyNotificationIDs() async {
    let repair = Item.repairDuplicateNotificationIDs(in: items)
    guard !repair.repairedItems.isEmpty else { return }
    do {
      try modelContext.save()
    } catch {
      return
    }
    repair.staleIDs.forEach(NotificationScheduler.shared.cancel)
    for item in repair.repairedItems where !item.isCompleted {
      await NotificationScheduler.shared.rescheduleIfAuthorized(ItemNotificationDetails(item: item))
    }
  }
}

private struct FeaturedItemCard: View {
  @Environment(\.locale) private var locale
  let item: Item
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
            ProgressText(item: item, featured: true)
          }
          StatusLabel(item: item)
        }
      }
      ProgressView(value: min(item.progress(), 1))
        .tint(item.status().progressTint)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.remainingText(locale: locale))
          .font(.subheadline)
        ItemUsageSummary(item: item)
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
          ProgressText(item: item)
        }
        ProgressView(value: min(item.progress(), 1))
          .controlSize(.small)
          .tint(item.status().progressTint)
        StatusLabel(item: item)
        ItemUsageSummary(item: item)
      }
    }
    .padding(.vertical, 5)
  }
}

private struct ProgressText: View {
  @Environment(\.locale) private var locale
  let item: Item
  var featured = false

  var body: some View {
    Text(item.progress(), format: .percent.precision(.fractionLength(0)))
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

  var body: some View {
    let duration = item.usageDurationText(locale: locale)
    let target = item.targetDurationText(locale: locale)
    let cost = item.currentDailyCost().formatted(
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
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: item.status().symbolName)
      Text(item.status().title(locale: locale))
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(item.status() == .goalAchieved ? .green : .secondary)
  }
}

#if DEBUG
  #Preview("Japanese") {
    ContentView()
      .modelContainer(
        ScreenshotFixtures.previewContainer(
          locale: Locale(identifier: "ja_JP"))
      )
      .environment(\.locale, Locale(identifier: "ja_JP"))
      .defaultAppStorage(UserDefaults(suiteName: "UsedWell.Previews") ?? .standard)
  }

  #Preview("English") {
    ContentView()
      .modelContainer(
        ScreenshotFixtures.previewContainer(
          locale: Locale(identifier: "en_US"))
      )
      .environment(\.locale, Locale(identifier: "en_US"))
      .defaultAppStorage(UserDefaults(suiteName: "UsedWell.Previews") ?? .standard)
  }

#endif
