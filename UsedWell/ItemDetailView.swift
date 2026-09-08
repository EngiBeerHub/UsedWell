import SwiftData
import SwiftUI

struct ItemDetailView: View {
  @Environment(\.locale) private var locale
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item
  let notifications: NotificationScheduler
  let asOf: Date
  var commit = PersistenceCommit()
  @State private var saveFailed = false
  let onAddReplacement: () -> Void
  @State private var showsEditor = false
  @State private var showsCompleteConfirmation = false
  @State private var showsDeleteConfirmation = false
  @State private var showsCompletionResult = false
  @State private var usageNoteEditorDestination: UsageNoteEditorDestination?
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
            StatusLabel(item: item, asOf: asOf)
          }
          Text(item.progress(asOf: asOf), format: .percent.precision(.fractionLength(0))).font(
            .largeTitle.bold()
          ).monospacedDigit()
          ProgressView(value: min(item.progress(asOf: asOf), 1))
            .tint(progressTint)
          if item.isCompleted {
            Text("最終進捗率").font(.subheadline).foregroundStyle(.secondary)
          } else {
            Text(item.remainingText(asOf: asOf, usesDayPrecision: true, locale: locale)).font(
              .subheadline
            )
            .foregroundStyle(
              .secondary)
          }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
      }
      Section(
        item.isCompleted
          ? String(localized: LocalizedStringResource("最終結果", locale: locale))
          : String(localized: LocalizedStringResource("使用状況", locale: locale))
      ) {
        LabeledContent(
          item.isCompleted
            ? String(localized: LocalizedStringResource("最終使用期間", locale: locale))
            : String(localized: LocalizedStringResource("使用期間", locale: locale)),
          value: item.usageDurationText(asOf: asOf, locale: locale))
        LabeledContent("使用目標", value: item.targetDurationText(locale: locale))
        LabeledContent("目標日", value: item.targetDate().localizedDateText(locale: locale))
        if item.isCompleted {
          LabeledContent("使用開始〜終了", value: item.completedPeriodText(locale: locale))
        } else {
          LabeledContent("購入日", value: item.purchaseDate.localizedDateText(locale: locale))
        }
        LabeledContent(
          "購入価格",
          value: item.purchasePrice.formatted(
            .currency(code: locale.currency?.identifier ?? "JPY").precision(.fractionLength(0))
              .locale(locale)))
        LabeledContent("カテゴリ", value: item.category.displayName(locale: locale))
      }
      if item.isCompleted {
        Section("最終コスト") {
          CostRow(title: "1日あたり", value: item.currentDailyCost(asOf: asOf), emphasis: true)
        }
      } else {
        Section {
          CostRow(title: "現在", value: item.currentDailyCost(asOf: asOf), emphasis: true)
          CostRow(title: "今から1年後", value: item.extendedDailyCost(asOf: asOf))
          CostRow(
            title: "目標達成時（\(item.targetDurationText(locale: locale))）",
            value: item.targetDailyCost())
        } header: {
          Text("1日あたりのコスト")
        } footer: {
          Text("長く使うほど、1日あたりのコストは下がります。")
        }
      }
      usageNotesSection
      if !item.isCompleted {
        Section {
          Button("買い替え完了にする", systemImage: "checkmark.circle") { showsCompleteConfirmation = true }
            .accessibilityIdentifier("complete-item")
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
        .accessibilityIdentifier("delete-item")
      }
    }
    .navigationTitle(
      item.isCompleted
        ? String(localized: LocalizedStringResource("履歴の詳細", locale: locale))
        : String(localized: LocalizedStringResource("愛用品の詳細", locale: locale))
    )
    .navigationBarTitleDisplayMode(.inline)
    .alert("変更を保存できませんでした。もう一度お試しください。", isPresented: $saveFailed) {
      Button("確認", role: .cancel) {}
    }
    .toolbar {
      if !item.isCompleted {
        ToolbarItem(placement: .topBarTrailing) {
          Button("編集") { showsEditor = true }.accessibilityIdentifier("edit-item")
        }
      }
    }
    .sheet(isPresented: $showsEditor) {
      NavigationStack {
        ItemEditorView(item: item, commit: commit) { id, _ in
          notifications.requestUpdate(itemID: id)
        }
      }
    }
    .sheet(item: $usageNoteEditorDestination) { destination in
      NavigationStack {
        UsageNoteEditorView(item: item, note: destination.note, commit: commit)
      }
    }
    .alert("買い替え完了にしますか？", isPresented: $showsCompleteConfirmation) {
      Button("今日で使用を終了") {
        completeItem()
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
        deleteItem()
      }
      Button("キャンセル", role: .cancel) {}
    } message: {
      Text("この操作は取り消せません。")
    }
  }

  private func completeItem() {
    do {
      try commit(in: modelContext) { item.completedDate = .now }
      saveFailed = false
      notifications.requestUpdate(itemID: item.notificationID)
      showsCompletionResult = true
    } catch {
      saveFailed = true
    }
  }

  private func deleteItem() {
    let id = item.notificationID
    do {
      try commit(in: modelContext) { modelContext.delete(item) }
      saveFailed = false
      notifications.requestUpdate(itemID: id)
      dismiss()
    } catch {
      saveFailed = true
    }
  }

  private var completionMessage: String {
    let cost = item.currentDailyCost(asOf: asOf).formatted(
      .currency(code: locale.currency?.identifier ?? "JPY").precision(.fractionLength(0)).locale(
        locale)
    )
    return String(
      localized: "最終使用期間は\(item.usageDurationText(asOf: asOf, locale: locale))、1日あたり\(cost)でした。")
  }

  @ViewBuilder private var usageNotesSection: some View {
    Section {
      if item.sortedUsageNotes.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Label("使っていて感じたことを残せます", systemImage: "note.text")
            .font(.subheadline.weight(.semibold))
          Text("気になったことや、まだ十分使えると感じたことを、日付付きで振り返れます。")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("最初のメモを追加", systemImage: "plus") {
            presentUsageNoteEditor()
          }
          .accessibilityIdentifier("add-first-usage-note")
        }
        .padding(.vertical, 4)
      } else {
        ForEach(item.sortedUsageNotes) { note in
          Button {
            presentUsageNoteEditor(note)
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(note.date.localizedDateText(locale: locale))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(note.text)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("usage-note-row")
        }
      }
    } header: {
      HStack {
        Text("使用メモ")
        Spacer()
        if !item.sortedUsageNotes.isEmpty {
          Button("メモを追加", systemImage: "plus") {
            presentUsageNoteEditor()
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("メモを追加")
          .accessibilityIdentifier("add-usage-note")
        }
      }
    }
  }

  private func presentUsageNoteEditor(_ note: UsageNote? = nil) {
    usageNoteEditorDestination = UsageNoteEditorDestination(note: note)
  }

  private var progressTint: Color {
    if item.isCompleted { return .green }
    switch item.status(asOf: asOf) {
    case .stillUsing: return .accentColor
    case .considerReplacing: return .orange
    case .goalAchieved: return .green
    }
  }
}

private struct UsageNoteEditorDestination: Identifiable {
  let id = UUID()
  let note: UsageNote?
}

private struct CostRow: View {
  @Environment(\.locale) private var locale
  let title: LocalizedStringKey
  let value: Double
  var emphasis = false
  var body: some View {
    LabeledContent(title) {
      Text(
        value,
        format: .currency(code: locale.currency?.identifier ?? "JPY").precision(.fractionLength(0))
          .locale(locale)
      ).fontWeight(
        emphasis ? .bold : .regular
      ).monospacedDigit()
    }
  }
}
