import Foundation

// MARK: - Travel Pace

enum TravelPace: String, Codable, CaseIterable, Identifiable {
    case intense, relaxed, mixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .intense: return "Насыщенный"
        case .relaxed: return "Расслабленный"
        case .mixed: return "Смешанный"
        }
    }

    var icon: String {
        switch self {
        case .intense: return "bolt.fill"
        case .relaxed: return "leaf.fill"
        case .mixed: return "arrow.triangle.merge"
        }
    }
}

// MARK: - Chronotype

enum Chronotype: String, Codable, CaseIterable, Identifiable {
    case morning, evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: return "Утренний"
        case .evening: return "Вечерний"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

// MARK: - Visited City

struct VisitedCity: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
}

// MARK: - User Profile

struct UserProfile: Codable {
    var name: String = ""
    var homeCountry: String = ""
    var homeCity: String = ""
    var birthDate: Date?
    var travelPace: TravelPace = .mixed
    var interests: [String] = []
    var dietaryPreferences: [String] = []
    var visitedCountries: [String] = []
    var visitedCities: [VisitedCity] = []
    var chronotype: Chronotype = .morning

    enum CodingKeys: String, CodingKey {
        case name
        case homeCountry = "home_country"
        case homeCity = "home_city"
        case birthDate = "birth_date"
        case travelPace = "travel_pace"
        case interests
        case dietaryPreferences = "dietary_preferences"
        case visitedCountries = "visited_countries"
        case visitedCities = "visited_cities"
        case chronotype
    }

    init(
        name: String = "",
        homeCountry: String = "",
        homeCity: String = "",
        birthDate: Date? = nil,
        travelPace: TravelPace = .mixed,
        interests: [String] = [],
        dietaryPreferences: [String] = [],
        visitedCountries: [String] = [],
        visitedCities: [VisitedCity] = [],
        chronotype: Chronotype = .morning
    ) {
        self.name = name
        self.homeCountry = homeCountry
        self.homeCity = homeCity
        self.birthDate = birthDate
        self.travelPace = travelPace
        self.interests = interests
        self.dietaryPreferences = dietaryPreferences
        self.visitedCountries = visitedCountries
        self.visitedCities = visitedCities
        self.chronotype = chronotype
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        homeCountry = try c.decodeIfPresent(String.self, forKey: .homeCountry) ?? ""
        homeCity = try c.decodeIfPresent(String.self, forKey: .homeCity) ?? ""
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate)
        travelPace = try c.decodeIfPresent(TravelPace.self, forKey: .travelPace) ?? .mixed
        interests = try c.decodeIfPresent([String].self, forKey: .interests) ?? []
        dietaryPreferences = try c.decodeIfPresent([String].self, forKey: .dietaryPreferences) ?? []
        visitedCountries = try c.decodeIfPresent([String].self, forKey: .visitedCountries) ?? []
        visitedCities = try c.decodeIfPresent([VisitedCity].self, forKey: .visitedCities) ?? []
        chronotype = try c.decodeIfPresent(Chronotype.self, forKey: .chronotype) ?? .morning
    }

    var hasData: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    var ageFormatted: String? {
        guard let age else { return nil }
        let mod10 = age % 10
        let mod100 = age % 100
        let suffix: String
        if mod100 >= 11 && mod100 <= 14 {
            suffix = "лет"
        } else {
            switch mod10 {
            case 1: suffix = "год"
            case 2, 3, 4: suffix = "года"
            default: suffix = "лет"
            }
        }
        return "\(age) \(suffix)"
    }
}
