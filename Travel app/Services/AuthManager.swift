import Foundation
import LocalAuthentication
import AuthenticationServices

@Observable
final class AuthManager {
    static let shared = AuthManager()

    // MARK: - Keychain Keys

    private enum Keys {
        static let userID = "auth_userID"
        static let provider = "auth_provider"
    }

    // MARK: - Published State

    var isLocked: Bool = false

    var isSignedIn: Bool {
        KeychainHelper.readString(key: Keys.userID) != nil
    }

    var userName: String? {
        get { UserDefaults.standard.string(forKey: "auth_userName") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_userName") }
    }

    var userEmail: String? {
        get { UserDefaults.standard.string(forKey: "auth_userEmail") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_userEmail") }
    }

    var authProvider: String? {
        get { UserDefaults.standard.string(forKey: "auth_provider") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_provider") }
    }

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricEnabled") }
    }

    // MARK: - Init

    private init() {
        if isBiometricEnabled && isSignedIn {
            isLocked = true
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user

        _ = KeychainHelper.save(key: Keys.userID, string: userID)
        authProvider = "apple"

        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                userName = name
            }
        }

        if let email = credential.email {
            userEmail = email
        }
    }

    // MARK: - Sign in with Google

    func signInWithGoogle(userID: String, name: String?, email: String?) {
        _ = KeychainHelper.save(key: Keys.userID, string: userID)
        authProvider = "google"
        userName = name
        userEmail = email
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.delete(key: Keys.userID)
        userName = nil
        userEmail = nil
        authProvider = nil
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
