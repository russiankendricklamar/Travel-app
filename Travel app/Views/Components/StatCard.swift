import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            // Bold color accent bar
            Rectangle()
                .fill(color)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(color)
                    Spacer()
                }

                Text(value)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 0)

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(2)
                    .foregroundStyle(AppTheme.textSecondary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(AppTheme.spacingM)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: AppTheme.borderWidth))
    }
}

// MARK: - Progress Ring (Brutalist: Square)

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
            Rectangle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Rectangle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Category Badge (Brutalist Bold)

struct CategoryBadge: View {
    let category: PlaceCategory

    var body: some View {
        let color = AppTheme.categoryColor(for: category.rawValue)

        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
                .font(.system(size: 10, weight: .bold))
            Text(category.rawValue.uppercased())
                .font(.system(size: 9, weight: .black))
                .tracking(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(color)
        .background(color.opacity(0.15))
        .overlay(
            Rectangle()
                .stroke(color.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - Star Rating (Bolder)

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
                    .foregroundStyle(index <= rating ? AppTheme.templeGold : AppTheme.textMuted.opacity(0.4))
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
    .background(AppTheme.background)
}
