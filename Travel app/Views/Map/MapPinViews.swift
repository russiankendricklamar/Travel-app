import SwiftUI
import MapKit

// MARK: - Place Pin (Apple Maps style — clean circle with icon)

struct PlacePinView: View {
    let place: Place
    let isSelected: Bool

    private var pinColor: Color {
        place.isVisited
            ? AppTheme.bambooGreen
            : AppTheme.categoryColor(for: place.category.rawValue)
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)

                Image(systemName: place.category.systemImage)
                    .font(.system(size: isSelected ? 15 : 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: isSelected ? 3 : 2)
            )
            .shadow(color: pinColor.opacity(0.4), radius: isSelected ? 6 : 3, y: 2)

            // Tiny stem
            if isSelected {
                Circle()
                    .fill(pinColor)
                    .frame(width: 5, height: 5)
            }
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Search Result Pin

struct SearchResultPinView: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: isSelected ? 32 : 24, weight: .bold))
                .foregroundStyle(AppTheme.indigoPurple)
                .background(
                    Circle()
                        .fill(.white)
                        .frame(width: isSelected ? 24 : 18, height: isSelected ? 24 : 18)
                )
                .shadow(color: AppTheme.indigoPurple.opacity(0.5), radius: isSelected ? 6 : 3, y: 2)

            Circle()
                .fill(AppTheme.indigoPurple)
                .frame(width: isSelected ? 5 : 4, height: isSelected ? 5 : 4)
        }
    }
}

// MARK: - AI Result Pin

struct AIResultPinView: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink, AppTheme.indigoPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: AppTheme.sakuraPink.opacity(0.4), radius: 4, y: 2)

            Circle()
                .fill(AppTheme.sakuraPink)
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Airport Pin

struct AirportPinView: View {
    let iata: String

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(AppTheme.sakuraPink, lineWidth: 1.5))
            Text(iata)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AppTheme.sakuraPink.opacity(0.85))
                .clipShape(Capsule())
        }
    }
}
