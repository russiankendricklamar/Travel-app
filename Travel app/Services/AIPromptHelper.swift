import Foundation
import SwiftData

// MARK: - Traveler Level

enum TravelerLevel: String {
    case beginner   // 0-2 trips, 0-3 countries
    case experienced // 3-7 trips, 4-10 countries
    case veteran    // 8+ trips, 11+ countries

    var label: String {
        switch self {
        case .beginner: return "новичок"
        case .experienced: return "опытный"
        case .veteran: return "бывалый"
        }
    }
}

// MARK: - AI Prompt Helper

enum AIPromptHelper {

    /// Determine traveler level from stats
    static func travelerLevel(tripCount: Int, countriesCount: Int) -> TravelerLevel {
        if tripCount >= 8 || countriesCount >= 11 {
            return .veteran
        } else if tripCount >= 3 || countriesCount >= 4 {
            return .experienced
        }
        return .beginner
    }

    /// Build personalization context string from profile + stats + bucket list
    /// Returns empty string if no profile data available
    static func profileContext(
        tripCount: Int = 0,
        bucketItems: [String] = []
    ) -> String {
        let profile = ProfileService.shared.profile
        guard let profile, profile.hasData else { return "" }

        var parts: [String] = []

        // Traveler level
        let level = travelerLevel(
            tripCount: tripCount,
            countriesCount: profile.visitedCountries.count
        )
        parts.append("Уровень путешественника: \(level.label)")

        // Interests
        if !profile.interests.isEmpty {
            parts.append("Интересы: \(profile.interests.joined(separator: ", "))")
        }

        // Diet
        if !profile.dietaryPreferences.isEmpty {
            parts.append("Диета: \(profile.dietaryPreferences.joined(separator: ", "))")
        }

        // Pace
        parts.append("Темп: \(profile.travelPace.label.lowercased())")

        // Chronotype
        parts.append("Тип: \(profile.chronotype.label.lowercased())")

        // Age bracket (not exact)
        if let age = profile.age {
            let bracket: String
            switch age {
            case ..<25: bracket = "до 25"
            case 25..<35: bracket = "25-35"
            case 35..<50: bracket = "35-50"
            case 50..<65: bracket = "50-65"
            default: bracket = "65+"
            }
            parts.append("Возраст: \(bracket)")
        }

        // Visited countries (brief)
        if !profile.visitedCountries.isEmpty {
            let sample = profile.visitedCountries.prefix(5).joined(separator: ", ")
            let suffix = profile.visitedCountries.count > 5 ? " (+\(profile.visitedCountries.count - 5))" : ""
            parts.append("Был в: \(sample)\(suffix)")
        }

        // Bucket list matches
        if !bucketItems.isEmpty {
            let sample = bucketItems.prefix(3).joined(separator: ", ")
            parts.append("Хочет увидеть: \(sample)")
        }

        guard !parts.isEmpty else { return "" }

        return """

        === ПРОФИЛЬ ПУТЕШЕСТВЕННИКА ===
        \(parts.joined(separator: "\n"))
        Учитывай профиль: для новичка — больше базовых советов, для бывалого — нетривиальные находки. Подстраивайся под интересы и темп.
        """
    }
}
