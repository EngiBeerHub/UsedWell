import SwiftUI

struct ItemPhotoView: View {
  let data: Data?
  let category: ItemCategory
  var maxPixelSize = 720
  @State private var image: CGImage?
  @State private var renderedData: Data?

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color(uiColor: .tertiarySystemGroupedBackground)
        if let image, renderedData == data {
          Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
        } else {
          Image(systemName: category.symbolName)
            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.5))
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task(id: data) {
      image = nil
      renderedData = nil
      guard let data else { return }
      let size = maxPixelSize
      let decoded = await Task.detached(priority: .userInitiated) {
        try? ItemPhotoPipeline.thumbnail(data: data, maxPixelSize: size)
      }.value
      guard !Task.isCancelled else { return }
      image = decoded
      renderedData = data
    }
  }
}

struct UsageProgressBar: View {
  let progress: Double
  let status: ReplacementStatus

  var body: some View {
    GeometryReader { geometry in
      Capsule().fill(Color(uiColor: .systemFill))
        .overlay(alignment: .leading) {
          Capsule().fill(status.progressTint)
            .frame(width: geometry.size.width * min(max(progress, 0), 1))
        }
    }
    .frame(height: 3)
    .accessibilityHidden(true)
  }
}

extension ReplacementStatus {
  var progressTint: Color {
    switch self {
    case .stillUsing: .accentColor
    case .considerReplacing: .orange
    case .goalAchieved: .green
    }
  }
}
