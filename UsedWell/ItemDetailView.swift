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
          if item.isCompleted {
            Label("買い替え完了", systemImage: "checkmark.circle.fill")
              .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
          } else {
            StatusLabel(item: item)
          }
          Text(item.progress(), format: .percent.precision(.fractionLength(0))).font(
            .largeTitle.bold()
          ).monospacedDigit()
          ProgressView(value: min(item.progress(), 1))
          if item.isCompleted {
            Text("最終進捗率").font(.subheadline).foregroundStyle(.secondary)
          } else {
            Text(item.remainingText).font(.subheadline).foregroundStyle(.secondary)
          }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
      }
      Section(item.isCompleted ? "最終結果" : "使用状況") {
        LabeledContent(item.isCompleted ? "最終使用期間" : "使用期間", value: item.usageDurationText)
        LabeledContent("使用目標", value: item.targetDurationText)
        LabeledContent("目標日", value: item.targetDate().japaneseDateText)
        if item.isCompleted {
          LabeledContent("使用開始〜終了", value: item.completedPeriodText)
        } else {
          LabeledContent("購入日", value: item.purchaseDate.japaneseDateText)
        }
        LabeledContent(
          "購入価格",
          value: item.purchasePrice.formatted(.currency(code: "JPY").precision(.fractionLength(0))))
        LabeledContent("カテゴリ", value: item.category.rawValue)
      }
      if item.isCompleted {
        Section("最終コスト") {
          CostRow(title: "1日あたり", value: item.currentDailyCost(), emphasis: true)
        }
      } else {
        Section {
          CostRow(title: "現在", value: item.currentDailyCost(), emphasis: true)
          CostRow(title: "今から1年後", value: item.extendedDailyCost())
          CostRow(title: "目標達成時（\(item.targetDurationText)）", value: item.targetDailyCost())
        } header: {
          Text("1日あたりのコスト")
        } footer: {
          Text("長く使うほど、1日あたりのコストは下がります。")
        }
      }
      if !item.isCompleted {
        Section {
          Button("買い替え完了にする", systemImage: "checkmark.circle") { showsCompleteConfirmation = true }
        } footer: {
          Text("使い終えた愛用品を、これまで使ったものに移します。")
        }
      }
      Section {
        Button(role: .destructive) {
          showsDeleteConfirmation = true
        } label: {
          Label("記録を削除", systemImage: "trash")
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle(item.isCompleted ? "履歴の詳細" : "愛用品の詳細").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !item.isCompleted {
        ToolbarItem(placement: .topBarTrailing) { Button("編集") { showsEditor = true } }
      }
    }
    .sheet(isPresented: $showsEditor) {
      NavigationStack {
        ItemEditorView(item: item) { item, _ in
          Task { await NotificationScheduler.shared.rescheduleIfAuthorized(item) }
        }
      }
    }
    .alert("買い替え完了にしますか？", isPresented: $showsCompleteConfirmation) {
      Button("今日で使用を終了") {
        item.completedDate = .now
        NotificationScheduler.shared.cancel(itemID: item.notificationID)
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
    .alert("この記録を削除しますか？", isPresented: $showsDeleteConfirmation) {
      Button("完全に削除", role: .destructive) {
        NotificationScheduler.shared.cancel(itemID: item.notificationID)
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
