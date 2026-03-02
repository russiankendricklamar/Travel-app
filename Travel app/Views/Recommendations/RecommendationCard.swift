import SwiftUI

struct RecommendationCard: View {
    let recommendation: PlaceRecommendation
    let onAdd: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: icon + name
            HStack(spacing: 10) {
                Image(systemName: recommendation.categoryIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [categoryColor, categoryColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(recommendation.category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(categoryColor)
                }

                Spacer()

                // Time badge
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .bold))
                    Text(recommendation.estimatedTime)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            // Description
            Text(recommendation.description)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Add to itinerary button
            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("В МАРШРУТ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(AppTheme.sakuraPink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.sakuraPink.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(scheme == .dark ? 0.12 : 0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private var categoryColor: Color {
        AppTheme.categoryColor(for: recommendation.category)
    }
}
