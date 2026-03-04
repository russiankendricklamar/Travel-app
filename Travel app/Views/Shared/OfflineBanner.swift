import SwiftUI

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .bold))
            Text("ОФЛАЙН-РЕЖИМ")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.toriiRed)
        .clipShape(Capsule())
        .shadow(color: AppTheme.toriiRed.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
