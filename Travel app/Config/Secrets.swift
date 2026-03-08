import Foundation

enum Secrets {
    // MARK: - Supabase (public by design — protected by RLS)
    static let supabaseURL = "https://lwgcacwslkchspzygvum.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx3Z2NhY3dzbGtjaHNwenlndnVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzMjY3MjQsImV4cCI6MjA4MzkwMjcyNH0.jS-0B4-snqziJYG9scu2jH4UHhhCHz1UxT4K-hnmvrM"

    private static func infoPlistValue(_ key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? ""
    }

    static var groqApiKey: String {
        KeychainHelper.readString(key: "groqApiKey") ?? infoPlistValue("GROQ_API_KEY")
    }

    static func setGroqApiKey(_ key: String) {
        KeychainHelper.save(key: "groqApiKey", string: key)
    }


    static var airLabsApiKey: String {
        KeychainHelper.readString(key: "airLabsApiKey") ?? infoPlistValue("AIRLABS_API_KEY")
    }

    static func setAirLabsApiKey(_ key: String) {
        KeychainHelper.save(key: "airLabsApiKey", string: key)
    }

    static var geminiApiKey: String {
        KeychainHelper.readString(key: "geminiApiKey") ?? infoPlistValue("GEMINI_API_KEY")
    }

    static func setGeminiApiKey(_ key: String) {
        KeychainHelper.save(key: "geminiApiKey", string: key)
    }

    static var googlePlacesApiKey: String {
        KeychainHelper.readString(key: "googlePlacesApiKey") ?? infoPlistValue("GOOGLE_PLACES_API_KEY")
    }

    static func setGooglePlacesApiKey(_ key: String) {
        KeychainHelper.save(key: "googlePlacesApiKey", string: key)
    }

    static var travelpayoutsToken: String {
        KeychainHelper.readString(key: "travelpayoutsToken") ?? infoPlistValue("TRAVELPAYOUTS_TOKEN")
    }

    static func setTravelpayoutsToken(_ key: String) {
        KeychainHelper.save(key: "travelpayoutsToken", string: key)
    }

    static var yandexClientID: String {
        KeychainHelper.readString(key: "yandexClientID") ?? infoPlistValue("YANDEX_CLIENT_ID")
    }

    static func setYandexClientID(_ key: String) {
        KeychainHelper.save(key: "yandexClientID", string: key)
    }

    static var yandexClientSecret: String {
        KeychainHelper.readString(key: "yandexClientSecret") ?? infoPlistValue("YANDEX_CLIENT_SECRET")
    }

    static func setYandexClientSecret(_ key: String) {
        KeychainHelper.save(key: "yandexClientSecret", string: key)
    }

    static func migrateFromAppStorage() {
        let defaults = UserDefaults.standard

        // Clear stale Keychain keys so xcconfig values take priority
        if !defaults.bool(forKey: "keychainApiKeysMigrated_v2") {
            KeychainHelper.delete(key: "groqApiKey")
            KeychainHelper.delete(key: "airLabsApiKey")
            defaults.set(true, forKey: "keychainApiKeysMigrated_v2")
        }

        // v3: clear all API keys from Keychain so xcconfig values take priority
        if !defaults.bool(forKey: "keychainApiKeysMigrated_v3") {
            KeychainHelper.delete(key: "geminiApiKey")
            KeychainHelper.delete(key: "googlePlacesApiKey")
            KeychainHelper.delete(key: "groqApiKey")
            KeychainHelper.delete(key: "airLabsApiKey")
            defaults.set(true, forKey: "keychainApiKeysMigrated_v3")
        }
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini

    var id: String { rawValue }

    var label: String { "Gemini" }
    var icon: String { "diamond.fill" }
    var subtitle: String { "Google AI" }

    var needsApiKey: Bool { true }

    static var current: AIProvider { .gemini }
}
