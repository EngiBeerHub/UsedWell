import SwiftData
import SwiftUI

struct ItemEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item?
  @State private var name: String
  @State private var category: ItemCategory
  @State private var purchaseDate: Date
  @State private var purchasePrice: Int?
  @State private var targetMonths: Int

  init(item: Item? = nil) {
    self.item = item
    _name = State(initialValue: item?.name ?? "")
    _category = State(initialValue: item?.category ?? .phone)
    _purchaseDate = State(initialValue: item?.purchaseDate ?? .now)
    _purchasePrice = State(initialValue: item?.purchasePrice)
    _targetMonths = State(initialValue: item?.targetMonths ?? 36)
  }
  var body: some View {
    Form {
      Section("愛用品") {
        TextField("名前", text: $name).accessibilityIdentifier("item-name")
        Picker("カテゴリ", selection: $category) {
          ForEach(ItemCategory.allCases) { category in
            Label(category.rawValue, systemImage: category.symbolName).tag(category)
          }
        }
      }
      Section("購入情報") {
        DatePicker("購入日", selection: $purchaseDate, in: ...Date.now, displayedComponents: .date)
        TextField("購入価格", value: $purchasePrice, format: .number).keyboardType(.numberPad)
          .accessibilityIdentifier("purchase-price")
      }
      Section("使用目標") {
        Stepper(value: $targetMonths, in: 1...240) { LabeledContent("目標期間", value: targetText) }
        Text("カテゴリに関係なく、自分が使いたい期間を設定します。").font(.footnote).foregroundStyle(.secondary)
      }
    }
    .navigationTitle(item == nil ? "愛用品を追加" : "登録内容を編集").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("保存", action: save).disabled(!isValid).accessibilityIdentifier("save-item")
      }
    }
  }
  private var targetText: String {
    let years = targetMonths / 12
    let months = targetMonths % 12
    if years == 0 { return "\(months)か月" }
    if months == 0 { return "\(years)年" }
    return "\(years)年\(months)か月"
  }
  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (purchasePrice ?? 0) >= 0
  }
  private func save() {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let item {
      item.name = cleanName
      item.category = category
      item.purchaseDate = purchaseDate
      item.purchasePrice = purchasePrice ?? 0
      item.targetMonths = targetMonths
    } else {
      modelContext.insert(
        Item(
          name: cleanName, category: category, purchaseDate: purchaseDate,
          purchasePrice: purchasePrice ?? 0, targetMonths: targetMonths))
    }
    dismiss()
  }
}
