import SwiftData
import SwiftUI

struct ItemDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item
  let onAddReplacement: () -> Void
  @State private var showsEditor = false
  @State private var showsCompleteConfirmation = false
  @State private var showsDeleteConfirmation = false
  @State private var showsCompletionResult = false
  var body: some View {
    List {
      Section {
        VStack(spacing: 12) {
          Image(systemName: item.category.symbolName).font(.largeTitle).foregroundStyle(.tint)
          Text(item.name).font(.title2.bold())
          StatusLabel(item: item)
          Text(item.progress(), format: .percent.precision(.fractionLength(0))).font(
            .largeTitle.bold()
          ).monospacedDigit()
          ProgressView(value: min(item.progress(), 1))
          Text(item.remainingText).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
      }
      Section("使用状況") {
        LabeledContent("使用期間", value: item.usageDurationText)
        LabeledContent(
          "使用目標",
          value: item.targetMonths % 12 == 0
            ? "\(item.targetMonths / 12)年" : "\(item.targetMonths)か月")
        LabeledContent("購入日", value: item.purchaseDate.formatted(date: .long, time: .omitted))
        LabeledContent(
          "購入価格",
          value: item.purchasePrice.formatted(.currency(code: "JPY").precision(.fractionLength(0))))
        LabeledContent("カテゴリ", value: item.category.rawValue)
      }
      Section {
        CostRow(title: "現在", value: item.currentDailyCost(), emphasis: true)
        CostRow(title: "目標まで使う", value: item.targetDailyCost())
        CostRow(title: "さらに1年使う", value: item.extendedDailyCost())
      } header: {
        Text("1日あたりのコスト")
      } footer: {
        Text("長く使うほど、1日あたりのコストは下がります。")
      }
      if !item.isCompleted {
        Section {
          Button("買い替え完了にする", systemImage: "checkmark.circle") { showsCompleteConfirmation = true }
        } footer: {
          Text("目標達成とは別の操作です。実際に使い終えたときだけ実行してください。")
        }
      }
      Section {
        Button("記録を削除", systemImage: "trash", role: .destructive) { showsDeleteConfirmation = true }
      }
    }
    .navigationTitle(item.isCompleted ? "履歴の詳細" : "愛用品の詳細").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !item.isCompleted {
        ToolbarItem(placement: .topBarTrailing) { Button("編集") { showsEditor = true } }
      }
    }
    .sheet(isPresented: $showsEditor) { NavigationStack { ItemEditorView(item: item) } }
    .confirmationDialog(
      "買い替え完了にしますか？", isPresented: $showsCompleteConfirmation, titleVisibility: .visible
    ) {
      Button("今日で使用を終了") {
        item.completedDate = .now
        showsCompletionResult = true
      }
      Button("キャンセル", role: .cancel) {}
    } message: {
      Text("記録は削除されず、「これまで使ったもの」に残ります。")
    }
    .alert("十分に使いました", isPresented: $showsCompletionResult) {
      Button("新しい愛用品を登録") {
        dismiss()
        onAddReplacement()
      }
      Button("完了") { dismiss() }
    } message: {
      Text(completionMessage)
    }
    .confirmationDialog(
      "この記録を削除しますか？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible
    ) {
      Button("完全に削除", role: .destructive) {
        modelContext.delete(item)
        dismiss()
      }
      Button("キャンセル", role: .cancel) {}
    } message: {
      Text("この操作は取り消せません。")
    }
  }

  private var completionMessage: String {
    let cost = item.currentDailyCost().formatted(
      .currency(code: "JPY").precision(.fractionLength(0))
    )
    return "最終使用期間は\(item.usageDurationText)、1日あたり\(cost)でした。"
  }
}

private struct CostRow: View {
  let title: String
  let value: Double
  var emphasis = false
  var body: some View {
    LabeledContent(title) {
      Text(value, format: .currency(code: "JPY").precision(.fractionLength(0))).fontWeight(
        emphasis ? .bold : .regular
      ).monospacedDigit()
    }
  }
}
