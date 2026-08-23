import SwiftData
import SwiftUI

struct HistoryView: View {
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
              Text("最終使用期間 \(item.usageDurationText)")
              Text(
                "1日あたり \(item.currentDailyCost(), format: .currency(code: "JPY").precision(.fractionLength(0)))"
              )
              Text(item.completedPeriodText)
            }.font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }.navigationTitle("これまで使ったもの")
  }
}

extension Item {
  fileprivate var completedPeriodText: String {
    let start = purchaseDate.formatted(date: .abbreviated, time: .omitted)
    let end = (completedDate ?? .now).formatted(date: .abbreviated, time: .omitted)
    return "\(start) 〜 \(end)"
  }
}
