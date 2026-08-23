import SwiftData
import SwiftUI

struct ContentView: View {
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
            Button("最初の愛用品を登録") { showsAdd = true }.buttonStyle(.borderedProminent)
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
                NavigationLink(value: item.notificationID) { FeaturedItemCard(item: item) }
              }
            }
            Section("使用中の愛用品") {
              ForEach(activeItems) { item in
                NavigationLink(value: item.notificationID) { ItemRow(item: item) }
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
          Button("愛用品を追加", systemImage: "plus") { showsAdd = true }
        }
      }
      .navigationDestination(for: UUID.self) { itemID in
        if let item = items.first(where: { $0.notificationID == itemID }) {
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
    .onChange(of: notificationNavigation.itemID) { _, itemID in
      openNotificationItem(itemID)
    }
    .task { openNotificationItem(notificationNavigation.itemID) }
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
    guard let itemID, items.contains(where: { $0.notificationID == itemID }) else { return }
    navigationPath = [itemID]
    notificationNavigation.itemID = nil
  }
}

private struct FeaturedItemCard: View {
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
      VStack(alignment: .leading, spacing: 4) {
        Text(item.remainingText)
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
        StatusLabel(item: item)
        ItemUsageSummary(item: item)
      }
    }
    .padding(.vertical, 5)
  }
}

private struct ProgressText: View {
  let item: Item
  var featured = false

  var body: some View {
    Text(item.progress(), format: .percent.precision(.fractionLength(0)))
      .font(featured ? .title2.bold() : .subheadline.bold())
      .monospacedDigit()
      .foregroundStyle(.primary)
  }
}

private struct ItemUsageSummary: View {
  let item: Item

  var body: some View {
    Text("使用期間 \(item.usageDurationText) ・ 1日 \(item.dailyCostText)")
      .font(.caption)
      .foregroundStyle(.secondary)
  }
}

extension Item {
  fileprivate var dailyCostText: String {
    currentDailyCost().formatted(.currency(code: "JPY").precision(.fractionLength(0)))
  }
}

struct StatusLabel: View {
  let item: Item
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: item.status().symbolName)
      Text(item.status().title)
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(item.status() == .goalAchieved ? .green : .secondary)
  }
}

#Preview { ContentView().modelContainer(for: Item.self, inMemory: true) }
