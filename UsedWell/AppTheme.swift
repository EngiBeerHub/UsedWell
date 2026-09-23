import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
  case warm
  case forest

  static let storageKey = "selectedAppTheme"
  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .warm: "Warm"
    case .forest: "Forest"
    }
  }

  func palette(colorScheme: ColorScheme) -> AppPalette {
    return switch (self, colorScheme) {
    case (.warm, .light):
      AppPalette(
        background: Color(hex: 0xFCF6ED), surface: Color(hex: 0xFFFCF7),
        secondarySurface: Color(hex: 0xF4EADB), featuredSurface: Color(hex: 0xFFFCF7),
        featuredInset: Color(hex: 0xF4EADB), primaryText: Color(hex: 0x302F2B),
        secondaryText: Color(hex: 0x746F66), featuredText: Color(hex: 0x302F2B),
        featuredSecondaryText: Color(hex: 0x746F66), accent: Color(hex: 0x9C502F),
        featuredAccent: Color(hex: 0x9C502F), divider: Color(hex: 0xDED1BF),
        photoMat: Color(hex: 0xEDE0CD), progressTrack: Color(hex: 0xD8CDBE))
    case (.warm, .dark):
      AppPalette(
        background: Color(hex: 0x211F1B), surface: Color(hex: 0x302B25),
        secondarySurface: Color(hex: 0x3B342C), featuredSurface: Color(hex: 0x302B25),
        featuredInset: Color(hex: 0x3B342C), primaryText: Color(hex: 0xF3EEE5),
        secondaryText: Color(hex: 0xBDB3A4), featuredText: Color(hex: 0xF3EEE5),
        featuredSecondaryText: Color(hex: 0xBDB3A4), accent: Color(hex: 0xE1A17B),
        featuredAccent: Color(hex: 0xE1A17B), divider: Color(hex: 0x51483D),
        photoMat: Color(hex: 0x4D453B), progressTrack: Color(hex: 0x5B5145))
    case (.forest, .light):
      AppPalette(
        background: Color(hex: 0xFAFAF2), surface: Color(hex: 0xFFFFFF),
        secondarySurface: Color(hex: 0xEEF4E9), featuredSurface: Color(hex: 0x243F35),
        featuredInset: Color(hex: 0xEFF5E9), primaryText: Color(hex: 0x273F34),
        secondaryText: Color(hex: 0x667769), featuredText: Color(hex: 0xFBFBF3),
        featuredSecondaryText: Color(hex: 0xBECFC1), accent: Color(hex: 0x285342),
        featuredAccent: Color(hex: 0xC5D7B7), divider: Color(hex: 0xD7E0D0),
        photoMat: Color(hex: 0xD8E5D4), progressTrack: Color(hex: 0xD2DDCB))
    case (.forest, .dark):
      AppPalette(
        background: Color(hex: 0x1B2620), surface: Color(hex: 0x2A3B31),
        secondarySurface: Color(hex: 0x344A3D), featuredSurface: Color(hex: 0x223D32),
        featuredInset: Color(hex: 0x344D40), primaryText: Color(hex: 0xF0F3EA),
        secondaryText: Color(hex: 0xA9B9AA), featuredText: Color(hex: 0xF0F3EA),
        featuredSecondaryText: Color(hex: 0xB8C9BA), accent: Color(hex: 0xB9D3BB),
        featuredAccent: Color(hex: 0xC5D7B7), divider: Color(hex: 0x445849),
        photoMat: Color(hex: 0x4F6655), progressTrack: Color(hex: 0x536B58))
    @unknown default:
      AppTheme.warm.palette(colorScheme: .light)
    }
  }
}

struct AppPalette {
  let background: Color
  let surface: Color
  let secondarySurface: Color
  let featuredSurface: Color
  let featuredInset: Color
  let primaryText: Color
  let secondaryText: Color
  let featuredText: Color
  let featuredSecondaryText: Color
  let accent: Color
  let featuredAccent: Color
  let divider: Color
  let photoMat: Color
  let progressTrack: Color

  // Milestone colors are semantic and never derived from a brand accent.
  static func progressColor(for status: ReplacementStatus, colorScheme: ColorScheme) -> Color {
    return switch (status, colorScheme) {
    case (.stillUsing, .light): Color(hex: 0x687B78)
    case (.stillUsing, .dark): Color(hex: 0xAAB9B4)
    case (.considerReplacing, .light): Color(hex: 0xA96D19)
    case (.considerReplacing, .dark): Color(hex: 0xD9AB5B)
    case (.goalAchieved, .light): Color(hex: 0x2F795A)
    case (.goalAchieved, .dark): Color(hex: 0xA0D4AE)
    @unknown default: Color(hex: 0x687B78)
    }
  }
}

private struct AppPaletteKey: EnvironmentKey {
  static let defaultValue = AppTheme.warm.palette(colorScheme: .light)
}

extension EnvironmentValues {
  var appPalette: AppPalette {
    get { self[AppPaletteKey.self] }
    set { self[AppPaletteKey.self] = newValue }
  }
}

extension Color {
  fileprivate init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255, opacity: 1)
  }
}
