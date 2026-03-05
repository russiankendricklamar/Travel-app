import SwiftUI

struct ARHUDView: View {
    let place: Place

    private var manager: ARNavigationManager { ARNavigationManager.shared }

    var body: some View {
        #if !targetEnvironment(simulator)
        hudContent
        #else
        simulatorPlaceholder
        #endif
    }

    #if !targetEnvironment(simulator)
    private var hudContent: some View {
        VStack {
            Spacer()

            VStack(spacing: AppTheme.spacingS) {
                // Place name
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Divider()
                    .background(.white.opacity(0.3))

                HStack(spacing: AppTheme.spacingL) {
                    // Distance
                    VStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.sakuraPink)
                        Text(formattedDistance)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // Walking time
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.bambooGreen)
                        Text("~\(manager.walkingTimeMinutes) \(String(localized: "мин"))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // Compass heading
                    VStack(spacing: 4) {
                        Image(systemName: "compass.drawing")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.oceanBlue)
                            .rotationEffect(.degrees(manager.bearing))
                        Text(cardinalDirection)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }
    #endif

    #if targetEnvironment(simulator)
    private var simulatorPlaceholder: some View {
        VStack {
            Spacer()
            Text("AR доступна только на устройстве")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .padding()
        }
    }
    #endif

    // MARK: - Formatting

    private var formattedDistance: String {
        let distance = manager.currentDistance
        if distance < 1000 {
            return "\(Int(distance)) \(String(localized: "м"))"
        }
        return String(format: "%.1f \(String(localized: "км"))", distance / 1000)
    }

    private var cardinalDirection: String {
        let bearing = manager.bearing
        switch bearing {
        case 0..<22.5, 337.5..<360: return String(localized: "С")
        case 22.5..<67.5: return String(localized: "СВ")
        case 67.5..<112.5: return String(localized: "В")
        case 112.5..<157.5: return String(localized: "ЮВ")
        case 157.5..<202.5: return String(localized: "Ю")
        case 202.5..<247.5: return String(localized: "ЮЗ")
        case 247.5..<292.5: return String(localized: "З")
        case 292.5..<337.5: return String(localized: "СЗ")
        default: return String(localized: "С")
        }
    }
}
