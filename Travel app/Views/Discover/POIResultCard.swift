import SwiftUI

struct POIResultCard: View {
    let result: POIResult
    var categoryIcon: String?
    var onAdd: (() -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: categoryIcon ?? "mappin.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(AppTheme.sakuraPink.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !result.address.isEmpty {
                    Text(result.address)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let distance = result.distanceMeters {
                    HStack(spacing: 3) {
                        Image(systemName: "location")
                            .font(.system(size: 9, weight: .bold))
                        Text(distance >= 1000 ? "\(String(format: "%.1f", distance / 1000)) км" : "\(Int(distance)) м")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}
