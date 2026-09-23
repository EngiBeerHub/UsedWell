import SwiftUI

struct SettingsView: View {
  @Environment(\.appPalette) private var palette
  @AppStorage(AppTheme.storageKey) private var selectedTheme = AppTheme.warm.rawValue

  var body: some View {
    Form {
      Section {
        Picker("テーマ", selection: $selectedTheme) {
          ForEach(AppTheme.allCases) { theme in
            Text(theme.title).tag(theme.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("theme-picker")
      } header: {
        Text("テーマ")
      } footer: {
        Text("画面の色を選べます。ライト・ダーク表示はiPhoneの設定に従います。")
      }
      .listRowBackground(palette.surface)
    }
    .scrollContentBackground(.hidden)
    .background(palette.background)
    .foregroundStyle(palette.primaryText)
    .navigationTitle("設定")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(palette.background, for: .navigationBar)
  }
}
