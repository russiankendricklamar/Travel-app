import Foundation
import AuthenticationServices
import Supabase

final class SupabaseAuthService {
    static let shared = SupabaseAuthService()
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let contextProvider = WebAuthContextProvider()
    private init() {}

    static let oauthCallbackScheme = "travelapp"

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String? = nil) async throws {
        guard let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        // Update profile with name if provided (Apple only sends name on first auth)
        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                let attrs = UserAttributes(data: ["full_name": AnyJSON.string(name)])
                _ = try? await client.auth.update(user: attrs)
            }
        }
    }

    // MARK: - Google Sign In (OAuth via ASWebAuthenticationSession)

    func signInWithGoogle() async throws {
        let redirectURL = URL(string: "\(Self.oauthCallbackScheme)://auth-callback")!

        let url = try client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: redirectURL
        )

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.oauthCallbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.missingToken)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self.contextProvider
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        try await client.auth.session(from: callbackURL)
    }

    // MARK: - Yandex Sign In (OAuth via ASWebAuthenticationSession)

    func signInWithYandex() async throws {
        let clientID = Secrets.yandexClientID
        guard !clientID.isEmpty else {
            throw AuthError.missingToken
        }

        let authURL = URL(string: "https://oauth.yandex.ru/authorize?response_type=code&client_id=\(clientID)&redirect_uri=\(Self.oauthCallbackScheme)://yandex-callback&force_confirm=yes")!

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Self.oauthCallbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.missingToken)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self.contextProvider
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Extract code from callback
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.missingToken
        }

        // Exchange code for token
        let tokenURL = URL(string: "https://oauth.yandex.ru/token")!
        var tokenRequest = URLRequest(url: tokenURL)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let clientSecret = Secrets.yandexClientSecret
        let bodyString = "grant_type=authorization_code&code=\(code)&client_id=\(clientID)&client_secret=\(clientSecret)"
        tokenRequest.httpBody = bodyString.data(using: .utf8)

        let (tokenData, _) = try await URLSession.shared.data(for: tokenRequest)
        guard let tokenJSON = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let accessToken = tokenJSON["access_token"] as? String else {
            throw AuthError.missingToken
        }

        // Fetch Yandex user info
        var infoRequest = URLRequest(url: URL(string: "https://login.yandex.ru/info?format=json")!)
        infoRequest.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        let (infoData, _) = try await URLSession.shared.data(for: infoRequest)
        guard let userInfo = try? JSONSerialization.jsonObject(with: infoData) as? [String: Any],
              let email = userInfo["default_email"] as? String else {
            throw AuthError.missingToken
        }

        let name = userInfo["display_name"] as? String ?? userInfo["real_name"] as? String ?? ""

        // Sign into Supabase with email — try sign-in first, then sign-up
        do {
            try await client.auth.signIn(email: email, password: "yandex_oauth_\(accessToken.prefix(32))")
        } catch {
            try await client.auth.signUp(
                email: email,
                password: "yandex_oauth_\(accessToken.prefix(32))",
                data: ["full_name": .string(name), "provider": .string("yandex")]
            )
        }
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    // MARK: - Email Sign Up

    func signUpWithEmail(email: String, password: String, name: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(name)]
        )
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Session

    func restoreSession() async throws -> Bool {
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }

    func handleOAuthCallback(url: URL) async throws {
        try await client.auth.session(from: url)
    }

    var currentUser: User? {
        client.auth.currentUser
    }

    var userName: String? {
        guard let user = currentUser else { return nil }
        if let name = user.userMetadata["full_name"]?.stringValue, !name.isEmpty {
            return name
        }
        if let name = user.userMetadata["name"]?.stringValue, !name.isEmpty {
            return name
        }
        return nil
    }

    var userEmail: String? {
        currentUser?.email
    }

    var authProvider: String? {
        currentUser?.appMetadata["provider"]?.stringValue
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case missingToken

        var errorDescription: String? {
            switch self {
            case .missingToken: return String(localized: "Не удалось получить токен авторизации")
            }
        }
    }
}

// MARK: - ASWebAuthenticationSession context

private class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// Helper to extract string from JSON
private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        default: return nil
        }
    }
}
