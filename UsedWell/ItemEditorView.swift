import SwiftData
import SwiftUI

struct ItemEditorView: View {
  private enum Field {
    case name
    case purchasePrice
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item?
  let onSaved: (ItemNotificationDetails, Bool) -> Void
  @State private var name: String
  @State private var category: ItemCategory
  @State private var purchaseDate: Date
  @State private var purchasePrice: Int?
  @State private var targetYears: Int
  @State private var targetAdditionalMonths: Int
  @State private var showsPurchaseDatePicker = false
  @FocusState private var focusedField: Field?

  init(
    item: Item? = nil,
    onSaved: @escaping (ItemNotificationDetails, Bool) -> Void = { _, _ in }
  ) {
    self.item = item
    self.onSaved = onSaved
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
        TextField("名前", text: $name)
          .focused($focusedField, equals: .name)
          .accessibilityIdentifier("item-name")
        Picker("カテゴリ", selection: $category) {
          ForEach(ItemCategory.allCases) { category in
            Label(category.rawValue, systemImage: category.symbolName).tag(category)
          }
        }
      }
      Section {
        Button {
          focusedField = nil
          showsPurchaseDatePicker.toggle()
        } label: {
          LabeledContent {
            HStack(spacing: 8) {
              Text(purchaseDate.japaneseDateText)
              Image(systemName: showsPurchaseDatePicker ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
            }
          } label: {
            Text("購入日")
          }
        }
        .accessibilityIdentifier("purchase-date-picker")
        .accessibilityValue(showsPurchaseDatePicker ? "展開中" : "折りたたみ")
        if showsPurchaseDatePicker {
          DatePicker(
            "購入日", selection: purchaseDateBinding, in: ...Date.now,
            displayedComponents: .date
          )
          .datePickerStyle(.graphical)
          .environment(\.locale, Locale(identifier: "ja_JP"))
          .labelsHidden()
          .accessibilityIdentifier("inline-purchase-date-picker")
        }
        LabeledContent("購入価格") {
          HStack(spacing: 4) {
            Text("¥").foregroundStyle(.secondary)
            TextField("0", value: $purchasePrice, format: .number)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .focused($focusedField, equals: .purchasePrice)
              .accessibilityIdentifier("purchase-price")
          }
        }
      } header: {
        Text("購入情報")
      } footer: {
        if let purchasePriceValidationMessage {
          Text(purchasePriceValidationMessage).foregroundStyle(.red)
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
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
        .accessibilityLabel("キャンセル")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(action: save) {
          Image(systemName: "checkmark")
        }
        .disabled(!isValid)
        .accessibilityLabel("保存")
        .accessibilityIdentifier("save-item")
      }
    }
    .onChange(of: targetYears) { _, newValue in
      if newValue == 20 { targetAdditionalMonths = 0 }
    }
  }
  private var purchaseDateBinding: Binding<Date> {
    Binding(
      get: { purchaseDate },
      set: { purchaseDate = Calendar.current.startOfDay(for: $0) }
    )
  }
  private var targetMonths: Int { targetYears * 12 + targetAdditionalMonths }
  private var purchasePriceValidationMessage: String? {
    PurchasePrice.validationMessage(for: purchasePrice)
  }
  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && purchasePriceValidationMessage == nil && targetMonths > 0
  }
  private func save() {
    guard isValid, let purchasePrice else { return }
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let savedItem: Item
    if let item {
      item.name = cleanName
      item.category = category
      item.purchaseDate = Calendar.current.startOfDay(for: purchaseDate)
      item.purchasePrice = purchasePrice
      item.targetMonths = targetMonths
      savedItem = item
    } else {
      let newItem = Item(
        name: cleanName, category: category,
        purchaseDate: Calendar.current.startOfDay(for: purchaseDate),
        purchasePrice: purchasePrice, targetMonths: targetMonths)
      modelContext.insert(newItem)
      savedItem = newItem
    }
    onSaved(ItemNotificationDetails(item: savedItem), item == nil)
    dismiss()
  }
}
