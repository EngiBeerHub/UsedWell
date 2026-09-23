import SwiftUI

struct FeaturedItemCard: View {
  @Environment(\.locale) private var locale
  @Environment(\.appPalette) private var palette
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let item: Item
  let asOf: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 17) {
      Text("次に見直すもの")
        .font(.caption)
        .foregroundStyle(palette.featuredSecondaryText)

      identityLayout {
        ItemPhotoView(data: item.photoData, category: item.category, width: 140, maxHeight: 168)
          .frame(width: 140, alignment: .leading)
        VStack(alignment: .leading, spacing: 9) {
          Text(item.name)
            .font(.title3.bold())
            .foregroundStyle(palette.featuredText)
            .fixedSize(horizontal: false, vertical: true)
          StatusLabel(item: item, asOf: asOf, homeFont: .caption.weight(.semibold), featured: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      durationSummary

      if let note = item.sortedUsageNotes.first {
        VStack(alignment: .leading, spacing: 6) {
          Label {
            Text("使用メモ ・ \(note.date.localizedDateText(locale: locale))")
          } icon: {
            Image(systemName: "note.text")
          }
          .font(.caption)
          .foregroundStyle(palette.featuredSecondaryText)
          Text(note.text)
            .font(.subheadline)
            .lineLimit(2)
            .foregroundStyle(palette.featuredText)
        }
      }

      Rectangle().fill(palette.divider.opacity(0.65)).frame(height: 1)
      HStack {
        Text("使用メモ・コストを確認")
        Spacer()
        Image(systemName: "chevron.right").accessibilityHidden(true)
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(palette.featuredAccent)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(palette.featuredSurface, in: RoundedRectangle(cornerRadius: 24))
    .contentShape(RoundedRectangle(cornerRadius: 24))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("featured-item")
  }

  private var identityLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
  }

  private var durationSummary: some View {
    VStack(alignment: .leading, spacing: 12) {
      durationLayout {
        VStack(alignment: .leading, spacing: 4) {
          Text("使用期間").font(.caption).foregroundStyle(palette.secondaryText)
          Text(item.usageDurationText(asOf: asOf, locale: locale))
            .font(.system(.title2, design: .default, weight: .bold))
            .foregroundStyle(palette.primaryText)
        }
        Spacer(minLength: 4)
        VStack(alignment: .leading, spacing: 4) {
          Text("使用目標").font(.caption).foregroundStyle(palette.secondaryText)
          Text(item.targetDurationText(locale: locale))
            .font(.headline)
            .foregroundStyle(palette.primaryText)
        }
      }
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          remainingAndProgress
          Spacer(minLength: 4)
          Text(dailyCost)
        }
        .fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading, spacing: 4) {
          remainingAndProgress
          Text(dailyCost)
        }
      }
      .font(.caption)
      .foregroundStyle(palette.secondaryText)
      .minimumScaleFactor(0.85)
      UsageProgressBar(progress: item.progress(asOf: asOf), status: item.status(asOf: asOf))
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(palette.featuredInset, in: RoundedRectangle(cornerRadius: 13))
  }

  private var durationLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
      : AnyLayout(HStackLayout(alignment: .bottom, spacing: 16))
  }

  private var remainingAndProgress: some View {
    HStack(spacing: 8) {
      Text(item.remainingText(asOf: asOf, usesDayPrecision: true, locale: locale))
      Text(item.progress(asOf: asOf), format: .percent.precision(.fractionLength(0)))
    }
  }

  private var dailyCost: String {
    let amount = item.currentDailyCost(asOf: asOf).formatted(
      .currency(code: locale.currency?.identifier ?? "JPY")
        .precision(.fractionLength(0)).locale(locale))
    return String(localized: LocalizedStringResource("1日 \(amount)", locale: locale))
  }
}

struct ItemRow: View {
  @Environment(\.locale) private var locale
  @Environment(\.appPalette) private var palette
  let item: Item
  let asOf: Date

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ItemPhotoView(
        data: item.photoData, category: item.category, width: 46, maxHeight: 56,
        maxPixelSize: 300
      )
      .frame(width: 46, alignment: .leading)
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(item.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(item.usageDurationText(asOf: asOf, locale: locale))
            .font(.subheadline.weight(.semibold))
            .fixedSize()
          Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(palette.secondaryText)
            .accessibilityHidden(true)
        }
        .foregroundStyle(palette.primaryText)
        HStack(spacing: 4) {
          StatusLabel(item: item, asOf: asOf, homeFont: .caption2)
          Spacer(minLength: 3)
          Text(item.progress(asOf: asOf), format: .percent.precision(.fractionLength(0)))
            .font(.caption2)
            .foregroundStyle(palette.secondaryText)
        }
        HStack(spacing: 4) {
          Text("目標\(item.targetDurationText(locale: locale))")
          Text("・")
          Text(item.remainingText(asOf: asOf, usesDayPrecision: true, locale: locale))
          Spacer(minLength: 3)
          Text(dailyCost)
        }
        .font(.caption2)
        .foregroundStyle(palette.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        UsageProgressBar(progress: item.progress(asOf: asOf), status: item.status(asOf: asOf))
      }
    }
    .padding(.vertical, 14)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("regular-item-\(item.navigationID)")
  }

  private var dailyCost: String {
    let amount = item.currentDailyCost(asOf: asOf).formatted(
      .currency(code: locale.currency?.identifier ?? "JPY")
        .precision(.fractionLength(0)).locale(locale))
    return String(localized: LocalizedStringResource("1日 \(amount)", locale: locale))
  }
}

struct StatusLabel: View {
  @Environment(\.locale) private var locale
  @Environment(\.appPalette) private var palette
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AppTheme.storageKey) private var selectedTheme = AppTheme.warm.rawValue
  let item: Item
  let asOf: Date
  var homeFont: Font?
  var featured = false

  var body: some View {
    let status = item.status(asOf: asOf)
    HStack(spacing: 5) {
      Image(systemName: status.symbolName)
        .accessibilityHidden(homeFont != nil)
      Text(status.title(locale: locale))
    }
    .font(homeFont ?? .caption.weight(.semibold))
    .foregroundStyle(statusColor(for: status))
  }

  private func statusColor(for status: ReplacementStatus) -> Color {
    if status == .stillUsing {
      return featured ? palette.featuredSecondaryText : palette.secondaryText
    }
    let effectiveScheme: ColorScheme =
      featured && (selectedTheme == AppTheme.forest.rawValue || colorScheme == .dark)
      ? .dark : colorScheme
    return AppPalette.progressColor(for: status, colorScheme: effectiveScheme)
  }
}
