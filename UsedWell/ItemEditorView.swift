import PhotosUI
import SwiftData
import SwiftUI

struct ItemEditorView: View {
  @Environment(\.locale) private var locale
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let item: Item?
  let onSaved: (UUID, Bool) -> Void
  let commit: PersistenceCommit
  @State private var saveFailed = false
  @State private var name: String
  @State private var category: ItemCategory
  @State private var purchaseDate: Date
  @State private var purchasePrice: Int?
  @State private var targetYears: Int
  @State private var targetAdditionalMonths: Int
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var photoDraft: ItemPhotoDraft

  init(
    item: Item? = nil, commit: PersistenceCommit? = nil,
    onSaved: @escaping (UUID, Bool) -> Void = { _, _ in }
  ) {
    self.item = item
    self.commit = commit ?? PersistenceCommit()
    self.onSaved = onSaved
    _photoDraft = State(initialValue: ItemPhotoDraft(original: item?.photoData))
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
      photoSection
      Section("愛用品") {
        TextField("名前", text: $name).accessibilityIdentifier("item-name")
        Picker("カテゴリ", selection: $category) {
          ForEach(ItemCategory.allCases) { category in
            Label(category.displayName(locale: locale), systemImage: category.symbolName).tag(
              category)
          }
        }
      }
      Section {
        DatePicker(
          "購入日", selection: $purchaseDate, in: ...Date.now, displayedComponents: .date
        )

        .accessibilityIdentifier("purchase-date-picker")
        LabeledContent("購入価格") {
          HStack(spacing: 4) {
            Text(locale.currencySymbol ?? locale.currency?.identifier ?? "").foregroundStyle(
              .secondary)
            TextField("0", value: $purchasePrice, format: .number)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .accessibilityIdentifier("purchase-price")
              .accessibilityLabel("購入価格")
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
    .navigationTitle(
      item == nil
        ? String(localized: LocalizedStringResource("愛用品を追加", locale: locale))
        : String(localized: LocalizedStringResource("登録内容を編集", locale: locale))
    )
    .navigationBarTitleDisplayMode(.inline)
    .alert("変更を保存できませんでした。もう一度お試しください。", isPresented: $saveFailed) {
      Button("確認", role: .cancel) {}
    }
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
    .onChange(of: selectedPhoto) { _, selection in
      if selection != nil { photoDraft.beginSelection() }
    }
    .task(id: photoDraft.selectionID) {
      guard photoDraft.isLoading, let selectedPhoto else { return }
      let selectionID = photoDraft.selectionID
      do {
        let photo = try await selectedPhoto.loadTransferable(type: ImportedItemPhoto.self)
        guard !Task.isCancelled else { return }
        photoDraft.finish(photo?.data, selectionID: selectionID)
        self.selectedPhoto = nil
      } catch {
        guard !Task.isCancelled else { return }
        photoDraft.finish(nil, selectionID: selectionID)
        self.selectedPhoto = nil
      }
    }
    .onDisappear { photoDraft.cancelLoading() }
  }

  private var photoSection: some View {
    Section {
      ItemPhotoView(data: photoDraft.data, category: category)
        .frame(height: photoDraft.data == nil ? 100 : 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("item-photo-preview")
      PhotosPicker(selection: $selectedPhoto, matching: .images) {
        Label(photoDraft.data == nil ? "写真を追加" : "写真を変更", systemImage: "photo")
      }
      .accessibilityIdentifier("choose-item-photo")
      if photoDraft.data != nil {
        Button("写真を削除", role: .destructive) {
          selectedPhoto = nil
          photoDraft.remove()
        }
        .accessibilityIdentifier("remove-item-photo")
      }
      if photoDraft.isLoading {
        ProgressView("写真を読み込み中")
      }
    } header: {
      Text("写真（任意）")
    } footer: {
      if photoDraft.loadFailed {
        Text("写真を読み込めませんでした。もう一度選択してください。")
          .foregroundStyle(.red)
      }
    }
  }
  private var targetMonths: Int { targetYears * 12 + targetAdditionalMonths }
  private var purchasePriceValidationMessage: String? {
    PurchasePrice.validationMessage(for: purchasePrice, locale: locale)
  }
  private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && purchasePriceValidationMessage == nil && targetMonths > 0 && !photoDraft.isLoading
  }
  private func save() {
    guard isValid, let purchasePrice else { return }
    do {
      let savedItem = try commit(in: modelContext) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item {
          item.name = cleanName
          item.category = category
          item.purchaseDate = Calendar.current.startOfDay(for: purchaseDate)
          item.purchasePrice = purchasePrice
          item.targetMonths = targetMonths
          if photoDraft.change != .unchanged { item.photoData = photoDraft.data }
          return item
        }
        let newItem = Item(
          name: cleanName, category: category,
          purchaseDate: Calendar.current.startOfDay(for: purchaseDate),
          purchasePrice: purchasePrice, targetMonths: targetMonths)
        modelContext.insert(newItem)
        newItem.photoData = photoDraft.data
        return newItem
      }
      saveFailed = false
      onSaved(savedItem.notificationID, item == nil)
      dismiss()
    } catch {
      saveFailed = true
    }
  }
}
