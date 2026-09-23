import SwiftUI

struct ItemPhotoView: View {
  @Environment(\.appPalette) private var palette
  let data: Data?
  let category: ItemCategory
  var width: CGFloat = 108
  var maxHeight: CGFloat?
  var maxPixelSize = 720
  @State private var image: CGImage?
  @State private var renderedData: Data?

  var body: some View {
    Group {
      if let image, renderedData == data {
        let size = AdaptivePhotoLayout.fittedSize(
          pixelWidth: image.width, pixelHeight: image.height,
          maxWidth: width, maxHeight: maxHeight ?? width * 1.2)
        Image(decorative: image, scale: 1)
          .resizable()
          .frame(width: size.width, height: size.height)
          .padding(3)
          .background(palette.photoMat, in: RoundedRectangle(cornerRadius: 7))
      } else {
        Image(systemName: category.symbolName)
          .font(.system(size: min(width * 0.38, 32)))
          .foregroundStyle(palette.secondaryText)
          .frame(width: width, height: width)
          .background(palette.photoMat, in: RoundedRectangle(cornerRadius: 7))
      }
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

enum AdaptivePhotoLayout {
  static func fittedSize(
    pixelWidth: Int, pixelHeight: Int, maxWidth: CGFloat, maxHeight: CGFloat
  ) -> CGSize {
    guard pixelWidth > 0, pixelHeight > 0 else { return .zero }
    let availableWidth = max(1, maxWidth - 6)
    let availableHeight = max(1, maxHeight - 6)
    let scale = min(
      availableWidth / CGFloat(pixelWidth), availableHeight / CGFloat(pixelHeight))
    return CGSize(width: CGFloat(pixelWidth) * scale, height: CGFloat(pixelHeight) * scale)
  }
}

struct UsageProgressBar: View {
  @Environment(\.appPalette) private var palette
  @Environment(\.colorScheme) private var colorScheme
  let progress: Double
  let status: ReplacementStatus

  var body: some View {
    GeometryReader { geometry in
      Capsule().fill(palette.progressTrack)
        .overlay(alignment: .leading) {
          Capsule().fill(AppPalette.progressColor(for: status, colorScheme: colorScheme))
            .frame(width: geometry.size.width * min(max(progress, 0), 1))
        }
    }
    .frame(height: 3)
    .accessibilityHidden(true)
  }
}
