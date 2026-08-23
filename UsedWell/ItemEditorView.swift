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
  @State private var targetYears: Int
  @State private var targetAdditionalMonths: Int

  init(item: Item? = nil) {
    self.item = item
    _name = State(initialValue: item?.name ?? "")
    _category = State(initialValue: item?.category ?? .phone)
    _purchaseDate = State(initialValue: item?.purchaseDate ?? .now)
    _purchasePrice = State(initialValue: item?.purchasePrice)
    let initialTargetMonths = item?.targetMonths ?? 36
    _targetYears = State(initialValue: initialTargetMonths / 12)
    _targetAdditionalMonths = State(initialValue: initialTargetMonths % 12)
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
          .environment(\.locale, Locale(identifier: "ja_JP"))
        LabeledContent("購入価格") {
          HStack(spacing: 4) {
            Text("¥").foregroundStyle(.secondary)
            TextField("0", value: $purchasePrice, format: .number)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .accessibilityIdentifier("purchase-price")
          }
        }
      }
      Section {
        Picker("年", selection: $targetYears) {
          ForEach(0...20, id: \.self) { years in Text("\(years)年").tag(years) }
        }
        Picker("月", selection: $targetAdditionalMonths) {
          ForEach(0...11, id: \.self) { months in Text("\(months)か月").tag(months) }
        }
        .disabled(targetYears == 20)
      } header: {
        Text("使用目標")
      } footer: {
        Text("この愛用品を使いたい期間の目安です。")
      }
    }
    .navigationTitle(item == nil ? "愛用品を追加" : "登録内容を編集").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("保存", action: save).disabled(!isValid).accessibilityIdentifier("save-item")
      }
    }
    .onChange(of: targetYears) { _, newValue in
      if newValue == 20 { targetAdditionalMonths = 0 }
    }
  }
  private var targetMonths: Int { targetYears * 12 + targetAdditionalMonths }
  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && purchasePrice != nil
      && (purchasePrice ?? -1) >= 0 && targetMonths > 0
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
