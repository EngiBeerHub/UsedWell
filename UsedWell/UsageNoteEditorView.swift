import SwiftData
import SwiftUI

struct UsageNoteEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item
  let note: UsageNote?
  @State private var date: Date
  @State private var text: String
  @State private var showsDeleteConfirmation = false

  init(item: Item, note: UsageNote? = nil) {
    self.item = item
    self.note = note
    _date = State(initialValue: note?.date ?? .now)
    _text = State(initialValue: note?.text ?? "")
  }

  var body: some View {
    Form {
      Section("日付") {
        DatePicker("メモの日付", selection: $date, in: ...Date.now, displayedComponents: .date)
          .environment(\.locale, Locale(identifier: "ja_JP"))
          .accessibilityIdentifier("usage-note-date")
      }
      Section {
        TextEditor(text: $text)
          .frame(minHeight: 140)
          .accessibilityIdentifier("usage-note-text")
      } header: {
        Text("メモ")
      } footer: {
        Text("使っていて気になったことや、まだ使い続けたい理由などを自由に残せます。")
      }
      if note != nil {
        Section {
          Button("このメモを削除", systemImage: "trash", role: .destructive) {
            showsDeleteConfirmation = true
          }
          .accessibilityIdentifier("delete-usage-note")
        }
      }
    }
    .navigationTitle(note == nil ? "使用メモを追加" : "使用メモを編集")
    .navigationBarTitleDisplayMode(.inline)
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
    dismiss()
  }

  private func delete() {
    guard let note else { return }
    item.usageNotes.removeAll { $0.persistentModelID == note.persistentModelID }
    modelContext.delete(note)
    dismiss()
  }
}
