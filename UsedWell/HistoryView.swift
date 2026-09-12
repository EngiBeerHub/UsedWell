import SwiftData
import SwiftUI

struct HistoryView: View {
  let notifications: NotificationScheduler
  let asOf: Date
  var commit = PersistenceCommit()
  @Query private var items: [Item]
  private var completedItems: [Item] {
    items.filter(\.isCompleted).sorted {
      ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast)
    }
  }
  var body: some View {
    Group {
      if completedItems.isEmpty {
        ContentUnavailableView(
          "履歴はまだありません", systemImage: "clock.arrow.circlepath",
          description: Text("買い替え完了にした愛用品がここに残ります。"))
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            Text("使用終了 \(completedItems.count)点")
              .font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 4)
            ForEach(completedItems) { item in
              NavigationLink {
                ItemDetailView(
                  item: item, notifications: notifications, asOf: asOf, commit: commit,
                  onAddReplacement: {})
              } label: {
                HistoryItemRow(item: item, asOf: asOf)
              }.buttonStyle(.plain)
            }
          }.padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
      }
    }.navigationTitle("これまで使ったもの")
  }
}

private struct HistoryItemRow: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let item: Item
  let asOf: Date

  private var layout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      layout {
        ItemPhotoView(data: item.photoData, category: item.category, maxPixelSize: 300)
          .frame(width: 64, height: 76)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 8) {
          Text(item.name).font(.headline)
          Text(item.usageDurationText(asOf: asOf, locale: locale))
            .font(.title2.bold())
          let cost = item.currentDailyCost(asOf: asOf).formatted(
            .currency(code: locale.currency?.identifier ?? "JPY")
              .precision(.fractionLength(0)).locale(locale))
          Text("\(cost) / 日").font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        if !dynamicTypeSize.isAccessibilitySize {
          Image(systemName: "chevron.right")
            .font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
      }
      Text("\(item.completedPeriodText(locale: locale)) 使用終了")
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20)
    )
    .contentShape(RoundedRectangle(cornerRadius: 20))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("history-item-\(item.navigationID)")
  }
}
