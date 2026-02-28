import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color.opacity(0.2))
        }
        .padding(AppTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(color.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Progress Ring (Glass: Circular)

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, color: Color, lineWidth: CGFloat = 6, size: CGFloat = 60) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Category Badge (Glass: Capsule)

struct CategoryBadge: View {
    let category: PlaceCategory

    var body: some View {
        let color = AppTheme.categoryColor(for: category.rawValue)

        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
                .font(.system(size: 10, weight: .bold))
            Text(category.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(color)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Star Rating

struct StarRatingView: View {
    let rating: Int
    let maxRating: Int
    var onRate: ((Int) -> Void)?

    init(rating: Int, maxRating: Int = 5, onRate: ((Int) -> Void)? = nil) {
        self.rating = rating
        self.maxRating = maxRating
        self.onRate = onRate
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(index <= rating ? AppTheme.templeGold : Color.secondary.opacity(0.3))
                    .shadow(
                        color: index <= rating ? AppTheme.templeGold.opacity(0.3) : .clear,
                        radius: 3,
                        x: 0,
                        y: 0
                    )
                    .onTapGesture {
                        onRate?(index)
                    }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatCard(
            title: "Budget",
            value: "\u{00A5}350,000",
            subtitle: "\u{00A5}102,140 spent",
            icon: "yensign.circle",
            color: AppTheme.templeGold
        )
        CategoryBadge(category: .temple)
        StarRatingView(rating: 4)
        ProgressRing(progress: 0.65, color: AppTheme.toriiRed)
    }
    .padding()
}
