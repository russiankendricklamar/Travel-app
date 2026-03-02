import SwiftUI

struct BiometricLockView: View {
    private let authManager = AuthManager.shared
    @State private var showError = false

    var body: some View {
        ZStack {
            // Blur background
            LinearGradient(
                colors: ColorPalette.current.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )

                    Image(systemName: "lock.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                }

                Text("Travel Planner заблокирован")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                // Unlock button
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Разблокировать")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.sakuraPink)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }
                .padding(.horizontal, AppTheme.spacingXL)

                if showError {
                    Text("Не удалось распознать. Попробуйте снова.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.toriiRed)
                        .transition(.opacity)
                }

                Spacer()

                // Sign out fallback
                Button {
                    authManager.signOut()
                } label: {
                    Text("Выйти из аккаунта")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showError)
        .task {
            authenticate()
        }
    }

    private func authenticate() {
        Task {
            let success = await authManager.authenticateWithBiometrics()
            if !success {
                showError = true
            }
        }
    }
}
