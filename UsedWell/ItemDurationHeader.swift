import SwiftUI

/// The same time-owned hierarchy anchors Home and Detail, with a compact variant for rows.
struct ItemDurationHeader: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.appPalette) private var palette
  @ScaledMetric(relativeTo: .title2) private var prominentDurationSize = 24
  let item: Item
  let asOf: Date
  var prominent = true

  private var layout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
  }

  var body: some View {
    layout {
      ItemPhotoView(
        data: item.photoData, category: item.category,
        width: prominent ? 120 : 64, maxHeight: prominent ? 144 : 76
      )
      .frame(width: prominent ? 120 : 64, alignment: .leading)
      VStack(alignment: .leading, spacing: prominent ? 12 : 6) {
        Text(item.name).font(.headline).fixedSize(horizontal: false, vertical: true)
        if prominent {
          Text(item.isCompleted ? "最終使用期間" : "使用期間")
            .font(.caption).foregroundStyle(palette.secondaryText)
        }
        Text(item.usageDurationText(asOf: asOf, locale: locale))
          .font(prominent ? .system(size: prominentDurationSize, weight: .bold) : .title2.bold())
          .fixedSize(horizontal: false, vertical: true)
        if item.isCompleted {
          Text("使用終了").font(.caption).foregroundStyle(palette.secondaryText)
        } else {
          StatusLabel(item: item, asOf: asOf, homeFont: .caption)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
