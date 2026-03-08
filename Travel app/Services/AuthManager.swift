import Foundation
import LocalAuthentication
import AuthenticationServices

@Observable
final class AuthManager {
    static let shared = AuthManager()

    // MARK: - State

    var isLocked: Bool = false
    private(set) var isSignedIn: Bool = false

    var supabaseUserID: UUID? {
        SupabaseManager.shared.currentUserID
    }

    var userName: String? {
        SupabaseAuthService.shared.userName
    }

    var userEmail: String? {
        SupabaseAuthService.shared.userEmail
    }

    var authProvider: String? {
        SupabaseAuthService.shared.authProvider
    }

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricEnabled") }
    }

    // MARK: - Init

    private init() {
        isSignedIn = SupabaseManager.shared.currentUserID != nil
        if isBiometricEnabled && isSignedIn {
            isLocked = true
        }
    }

    func refreshAuthState() {
        isSignedIn = SupabaseManager.shared.currentUserID != nil
    }

    // MARK: - Sign in with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String? = nil) async throws {
        try await SupabaseAuthService.shared.signInWithApple(credential: credential, nonce: nonce)
        isSignedIn = true
    }

    // MARK: - Sign in with Google

    func signInWithGoogle() async throws {
        try await SupabaseAuthService.shared.signInWithGoogle()
        isSignedIn = true
    }

    // MARK: - Sign in with Email

    func signInWithEmail(email: String, password: String) async throws {
        try await SupabaseAuthService.shared.signInWithEmail(email: email, password: password)
        isSignedIn = true
    }

    func signUpWithEmail(email: String, password: String, name: String) async throws {
        try await SupabaseAuthService.shared.signUpWithEmail(email: email, password: password, name: name)
        isSignedIn = true
    }

    // MARK: - Sign in with Yandex

    func signInWithYandex() async throws {
        try await SupabaseAuthService.shared.signInWithYandex()
        isSignedIn = true
    }

    // MARK: - Sign Out

    func signOut() async {
        try? await SupabaseAuthService.shared.signOut()
        ProfileService.shared.clearProfile()
        isSignedIn = false
        isBiometricEnabled = false
        isLocked = false
    }

    // MARK: - Biometrics

    func checkBiometricAvailability() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Разблокировать Travel Planner"
            )
            if success {
                await MainActor.run {
                    isLocked = false
                }
            }
            return success
        } catch {
            return false
        }
    }

    // MARK: - Scene Phase

    func lockIfNeeded() {
        if isBiometricEnabled && isSignedIn {
            isLocked = true
        }
    }
}
