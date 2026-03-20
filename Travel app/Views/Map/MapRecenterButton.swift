import SwiftUI

/// Capsule button that re-centers the map on the user's location
/// after a manual pan during active navigation.
struct MapRecenterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Вернуться")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(AppTheme.sakuraPink))
            .shadow(color: AppTheme.sakuraPink.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
