import SwiftUI

struct BucketItemCard: View {
    let item: BucketListItem

    private var categoryEnum: PlaceCategory {
        PlaceCategory(rawValue: item.category) ?? .culture
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: item.isConverted ? "checkmark.circle.fill" : "bookmark.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(item.isConverted ? AppTheme.bambooGreen : AppTheme.sakuraPink)
                .frame(width: 36, height: 36)
                .background(
                    (item.isConverted ? AppTheme.bambooGreen : AppTheme.sakuraPink).opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(item.isConverted ? .secondary : .primary)
                    .strikethrough(item.isConverted, color: AppTheme.bambooGreen.opacity(0.5))

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9, weight: .bold))
                        Text(item.destination)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thinMaterial)
                    .clipShape(Capsule())

                    HStack(spacing: 3) {
                        Image(systemName: categoryEnum.systemImage)
                            .font(.system(size: 9, weight: .bold))
                        Text(categoryEnum.rawValue)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.tertiary)
                }

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if item.isConverted {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.bambooGreen)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(
                    (item.isConverted ? AppTheme.bambooGreen : AppTheme.sakuraPink).opacity(0.15),
                    lineWidth: 0.5
                )
        )
        .opacity(item.isConverted ? 0.7 : 1.0)
    }
}
