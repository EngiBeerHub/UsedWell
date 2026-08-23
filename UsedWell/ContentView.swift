import SwiftData
import SwiftUI

struct ContentView: View {
  @Query private var items: [Item]
  @State private var showsAdd = false
  private var activeItems: [Item] {
    items.filter { !$0.isCompleted }.sorted {
      let lhs = $0.reviewPriority()
      let rhs = $1.reviewPriority()
      return lhs.0 == rhs.0 ? lhs.1 > rhs.1 : lhs.0 > rhs.0
    }
  }
  private var hasHistory: Bool { items.contains(where: \.isCompleted) }
  var body: some View {
    NavigationStack {
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
                NavigationLink(value: item) { FeaturedItemCard(item: item) }
              }
            }
            Section("使用中の愛用品") {
              ForEach(activeItems) { item in NavigationLink(value: item) { ItemRow(item: item) } }
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
      .navigationTitle("UsedWell")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("愛用品を追加", systemImage: "plus") { showsAdd = true }
        }
      }
      .navigationDestination(for: Item.self) { item in
        ItemDetailView(item: item, onAddReplacement: { showsAdd = true })
      }
    }
    .sheet(isPresented: $showsAdd) { NavigationStack { ItemEditorView() } }
  }
}

private struct FeaturedItemCard: View {
  let item: Item
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: item.category.symbolName).font(.title2).foregroundStyle(.tint)
        VStack(alignment: .leading) {
          Text(item.name).font(.headline)
          StatusLabel(item: item)
        }
        Spacer()
        Text(item.progress(), format: .percent.precision(.fractionLength(0))).font(.title2.bold())
          .monospacedDigit()
      }
      ProgressView(value: min(item.progress(), 1))
      Text(item.remainingText).font(.subheadline).foregroundStyle(.secondary)
    }.padding(.vertical, 6).accessibilityIdentifier("featured-item")
  }
}

struct ItemRow: View {
  let item: Item
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: item.category.symbolName).frame(width: 32).foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.name).font(.headline)
        StatusLabel(item: item)
        Text("使用期間 \(item.usageDurationText)・1日 \(item.dailyCostText)")
          .font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Text(item.progress(), format: .percent.precision(.fractionLength(0))).font(
        .subheadline.bold()
      ).monospacedDigit()
    }.padding(.vertical, 3)
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
    Label(item.status().title, systemImage: item.status().symbolName).font(
      .caption.weight(.semibold)
    ).foregroundStyle(item.status() == .goalAchieved ? .green : .secondary)
  }
}

#Preview { ContentView().modelContainer(for: Item.self, inMemory: true) }
