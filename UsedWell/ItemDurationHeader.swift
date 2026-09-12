import SwiftUI

/// The same time-owned hierarchy anchors Home and Detail, with a compact variant for rows.
struct ItemDurationHeader: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
      ItemPhotoView(data: item.photoData, category: item.category)
        .frame(
          width: item.photoData == nil ? 48 : (prominent ? 108 : 64),
          height: item.photoData == nil ? 48 : (prominent ? 140 : 76)
        )
        .clipShape(RoundedRectangle(cornerRadius: prominent ? 16 : 12))
      VStack(alignment: .leading, spacing: prominent ? 12 : 6) {
        Text(item.name).font(.headline).fixedSize(horizontal: false, vertical: true)
        if prominent {
          Text(item.isCompleted ? "最終使用期間" : "使用期間")
            .font(.caption).foregroundStyle(.secondary)
        }
        Text(item.usageDurationText(asOf: asOf, locale: locale))
          .font(prominent ? .title.bold() : .title2.bold())
          .fixedSize(horizontal: false, vertical: true)
        if item.isCompleted {
          Text("使用終了").font(.caption).foregroundStyle(.secondary)
        } else {
          StatusLabel(item: item, asOf: asOf, homeFont: .caption)
            .fixedSize(horizontal: false, vertical: true)
          if item.status(asOf: asOf) == .goalAchieved {
            Text("使用中").font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
