import SwiftUI

struct SuicaWalletButton: View {
    var body: some View {
        Button {
            if let url = URL(string: "shoebox://") {
                UIApplication.shared.open(url) { success in
                    if !success {
                        if let appStore = URL(string: "https://apps.apple.com/app/suica/id1156875272") {
                            UIApplication.shared.open(appStore)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.bambooGreen, AppTheme.bambooGreen.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                VStack(alignment: .leading, spacing: 2) {
                    Text("SUICA")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.primary)
                    Text("ОТКРЫТЬ APPLE WALLET")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.bambooGreen)
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(AppTheme.bambooGreen.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}
