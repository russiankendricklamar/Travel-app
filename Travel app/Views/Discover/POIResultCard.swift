import SwiftUI

struct POIResultCard: View {
    let result: POIResult
    var category: GooglePOICategory?
    var onAdd: (() -> Void)?

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            thumbnail

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

                HStack(spacing: 8) {
                    if let rating = result.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.templeGold)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            if let count = result.totalRatings {
                                Text("(\(count))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if let distance = result.distanceMeters {
                        HStack(spacing: 3) {
                            Image(systemName: "location")
                                .font(.system(size: 9, weight: .bold))
                            Text(distance >= 1000 ? String(format: "%.1f \(String(localized: "км"))", distance / 1000) : "\(Int(distance)) \(String(localized: "м"))")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let isOpen = result.isOpenNow {
                        Text(isOpen ? "Открыто" : "Закрыто")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isOpen ? AppTheme.bambooGreen : AppTheme.toriiRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isOpen ? AppTheme.bambooGreen : AppTheme.toriiRed).opacity(0.1))
                            .clipShape(Capsule())
                    }
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

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        let photoURL = result.photoReference.flatMap {
            GooglePlacesService.shared.photoURL(for: $0)
        }

        if let photoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    categoryIcon
                default:
                    ProgressView()
                        .frame(width: 48, height: 48)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        } else {
            categoryIcon
        }
    }

    private var categoryIcon: some View {
        Image(systemName: category?.systemImage ?? "mappin.circle.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(AppTheme.sakuraPink.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    }
}
