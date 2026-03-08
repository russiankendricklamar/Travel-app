import SwiftUI

enum AuthResult {
    case signedIn
    case skipped
}

struct AuthView: View {
    let onComplete: (AuthResult) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEmailAuth = false

    private let authManager = AuthManager.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: ColorPalette.current.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                headerSection

                Spacer()
                    .frame(height: 48)

                buttonsSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.toriiRed)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Spacer()

                skipButton

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, AppTheme.spacingL)

            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthSheet {
                onComplete(.signedIn)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: AppTheme.sakuraPink.opacity(0.2), radius: 16, x: 0, y: 8)

            Text("ULTIMA THULE")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.primary)

            Text("Ваш личный путеводитель")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(spacing: 14) {
            appleSignInButton
            googleSignInButton
            yandexSignInButton
            emailSignInButton
        }
    }

    // MARK: - Apple Sign In (stub)

    private var appleSignInButton: some View {
        Button {
            // TODO: implement Apple Sign In
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .medium))
                Text("Войти через Apple")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
    }

    // MARK: - Yandex Sign In

    private var yandexSignInButton: some View {
        Button {
            handleYandexSignIn()
        } label: {
            HStack(spacing: 10) {
                Text("Ya")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Войти через Яндекс")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(hex: "FC3F1D"))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
    }

    // MARK: - Google Sign In

    private var googleSignInButton: some View {
        Button {
            handleGoogleSignIn()
        } label: {
            HStack(spacing: 10) {
                googleLogo
                    .frame(width: 20, height: 20)
                Text("Войти через Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "1F1F1F"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(Color(hex: "DADCE0"), lineWidth: 1)
            )
        }
    }

    /// Google "G" logo drawn with shapes
    private var googleLogo: some View {
        ZStack {
            // Simplified colored G
            Text("G")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "4285F4"), Color(hex: "EA4335"), Color(hex: "FBBC05"), Color(hex: "34A853")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Email Sign In

    private var emailSignInButton: some View {
        Button {
            showEmailAuth = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Войти по Email")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Skip

    private var skipButton: some View {
        Button {
            onComplete(.skipped)
        } label: {
            HStack(spacing: 6) {
                Text("Пропустить")
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Google Sign-In Handler

    private func handleYandexSignIn() {
        isLoading = true
        Task {
            do {
                try await authManager.signInWithYandex()
                await MainActor.run {
                    isLoading = false
                    onComplete(.signedIn)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Ошибка Яндекс: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        isLoading = true
        Task {
            do {
                try await authManager.signInWithGoogle()
                await MainActor.run {
                    isLoading = false
                    onComplete(.signedIn)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Ошибка Google: \(error.localizedDescription)"
                }
            }
        }
    }
}
