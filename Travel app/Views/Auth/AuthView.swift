import SwiftUI
import AuthenticationServices

enum AuthResult {
    case signedIn
    case skipped
}

struct AuthView: View {
    let onComplete: (AuthResult) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    private let authManager = AuthManager.shared

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: ColorPalette.current.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + Title
                headerSection

                Spacer()
                    .frame(height: 48)

                // Sign-in buttons
                buttonsSection

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.toriiRed)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Spacer()

                // Skip button
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )

                Image(systemName: "airplane")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .rotationEffect(.degrees(-30))
            }

            Text("TRAVEL PLANNER")
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
            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            // Sign in with Google
            googleSignInButton
        }
    }

    private var googleSignInButton: some View {
        Button {
            handleGoogleSignIn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .bold))

                Text("Войти через Google")
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

    // MARK: - Apple Sign-In Handler

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Не удалось получить данные Apple ID"
                return
            }
            authManager.signInWithApple(credential: credential)
            onComplete(.signedIn)

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Ошибка входа: \(error.localizedDescription)"
        }
    }

    // MARK: - Google Sign-In Handler

    private func handleGoogleSignIn() {
        #if canImport(GoogleSignIn)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Не удалось открыть окно входа"
            return
        }

        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            isLoading = false

            if let error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    return
                }
                errorMessage = "Ошибка Google: \(error.localizedDescription)"
                return
            }

            guard let user = result?.user,
                  let userID = user.userID else {
                errorMessage = "Не удалось получить данные Google"
                return
            }

            authManager.signInWithGoogle(
                userID: userID,
                name: user.profile?.name,
                email: user.profile?.email
            )
            onComplete(.signedIn)
        }
        #else
        errorMessage = "Google Sign-In не настроен. Добавьте GoogleSignIn SPM-пакет."
        #endif
    }
}
