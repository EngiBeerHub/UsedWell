import SwiftData
import SwiftUI

struct HistoryView: View {
  @Environment(\.locale) private var locale
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
        List(completedItems) { item in
          NavigationLink {
            ItemDetailView(item: item, onAddReplacement: {})
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(item.name).font(.headline).foregroundStyle(.primary)
              HStack(spacing: 4) {
                Text("\(item.usageDurationText(locale: locale))使用")
                Text("·")
                let cost = item.currentDailyCost().formatted(
                  .currency(code: locale.currency?.identifier ?? "JPY")
                    .precision(.fractionLength(0)).locale(locale))
                Text("\(cost) / 日")
              }.font(.subheadline.weight(.medium)).foregroundStyle(.primary)
              Text(item.completedPeriodText(locale: locale))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
    }.navigationTitle("これまで使ったもの")
  }
}
