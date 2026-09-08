import SwiftData
import SwiftUI

struct UsageNoteEditorView: View {
  @Environment(\.locale) private var locale
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item
  let note: UsageNote?
  let commit: PersistenceCommit
  @State private var saveFailed = false
  @State private var date: Date
  @State private var text: String
  @State private var showsDeleteConfirmation = false

  init(item: Item, note: UsageNote? = nil, commit: PersistenceCommit? = nil) {
    self.item = item
    self.commit = commit ?? PersistenceCommit()
    self.note = note
    _date = State(initialValue: note?.date ?? .now)
    _text = State(initialValue: note?.text ?? "")
  }

  var body: some View {
    Form {
      Section("日付") {
        DatePicker("メモの日付", selection: $date, in: ...Date.now, displayedComponents: .date)

          .accessibilityIdentifier("usage-note-date")
      }
      Section {
        TextEditor(text: $text)
          .frame(minHeight: 140)
          .accessibilityIdentifier("usage-note-text")
          .accessibilityLabel("メモ")
      } header: {
        Text("メモ")
      } footer: {
        Text("使っていて気になったことや、まだ使い続けたい理由などを自由に残せます。")
      }
      if note != nil {
        Section {
          Button(role: .destructive) {
            showsDeleteConfirmation = true
          } label: {
            Label("このメモを削除", systemImage: "trash")
              .foregroundStyle(.red)
          }
          .accessibilityIdentifier("delete-usage-note")
        }
      }
    }
    .navigationTitle(
      note == nil
        ? String(localized: LocalizedStringResource("使用メモを追加", locale: locale))
        : String(localized: LocalizedStringResource("使用メモを編集", locale: locale))
    )
    .navigationBarTitleDisplayMode(.inline)
    .alert("変更を保存できませんでした。もう一度お試しください。", isPresented: $saveFailed) {
      Button("確認", role: .cancel) {}
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("キャンセル") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("保存", action: save)
          .disabled(trimmedText.isEmpty)
          .accessibilityIdentifier("save-usage-note")
      }
    }
    .alert("このメモを削除しますか？", isPresented: $showsDeleteConfirmation) {
      Button("削除", role: .destructive, action: delete)
      Button("キャンセル", role: .cancel) {}
    } message: {
      Text("この操作は取り消せません。")
    }
  }

  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func save() {
    guard !trimmedText.isEmpty else { return }
    perform {
      let noteDate = Calendar.current.startOfDay(for: date)
      if let note {
        note.date = noteDate
        note.text = trimmedText
        note.updatedAt = .now
      } else {
        let note = UsageNote(date: noteDate, text: trimmedText)
        modelContext.insert(note)
        item.usageNotes.append(note)
      }
    }
  }

  private func delete() {
    guard let note else { return }
    perform {
      item.usageNotes.removeAll { $0.persistentModelID == note.persistentModelID }
      modelContext.delete(note)
    }
  }

  private func perform(_ change: () -> Void) {
    do {
      try commit(in: modelContext, applying: change)
      saveFailed = false
      dismiss()
    } catch {
      saveFailed = true
    }
  }
}
