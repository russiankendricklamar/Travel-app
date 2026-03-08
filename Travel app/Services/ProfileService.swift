import Foundation
import Supabase

// MARK: - DTO for Supabase

private struct ProfileDTO: Codable {
    let name: String
    let homeCountry: String
    let homeCity: String
    let birthDate: String?
    let travelPace: String
    let interests: [String]
    let dietaryPreferences: [String]
    let visitedCountries: [String]
    let visitedCities: [VisitedCity]?
    let chronotype: String

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
}

private struct ProfileUpsertDTO: Codable {
    let id: String
    let name: String
    let homeCountry: String
    let homeCity: String
    let birthDate: String?
    let travelPace: String
    let interests: [String]
    let dietaryPreferences: [String]
    let visitedCountries: [String]
    let visitedCities: [VisitedCity]
    let chronotype: String

    enum CodingKeys: String, CodingKey {
        case id, name
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
}

// MARK: - Profile Service

@Observable
final class ProfileService {
    static let shared = ProfileService()

    var profile: UserProfile?
    var isLoading = false

    var hasProfile: Bool {
        guard let profile else { return false }
        return profile.hasData
    }

    private let localKey = "localUserProfile"

    private init() {
        loadLocal()
    }

    // MARK: - Local Storage

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let saved = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        self.profile = saved
    }

    private func saveLocal(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    // MARK: - Fetch

    @MainActor
    func fetchProfile() async {
        guard let userID = SupabaseManager.shared.currentUserID else {
            loadLocal()
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let dto: ProfileDTO = try await SupabaseManager.shared.client
                .from("profiles")
                .select("name, home_country, home_city, birth_date, travel_pace, interests, dietary_preferences, visited_countries, visited_cities, chronotype")
                .eq("id", value: userID.uuidString)
                .single()
                .execute()
                .value

            var fetched = UserProfile(
                name: dto.name,
                homeCountry: dto.homeCountry,
                homeCity: dto.homeCity,
                travelPace: TravelPace(rawValue: dto.travelPace) ?? .mixed,
                interests: dto.interests,
                dietaryPreferences: dto.dietaryPreferences,
                visitedCountries: dto.visitedCountries,
                visitedCities: dto.visitedCities ?? [],
                chronotype: Chronotype(rawValue: dto.chronotype) ?? .morning
            )
            if let bd = dto.birthDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                fetched.birthDate = f.date(from: bd)
            }
            self.profile = fetched
            saveLocal(fetched)
        } catch {
            print("[ProfileService] fetch error: \(error)")
            loadLocal()
        }
    }

    // MARK: - Save

    @MainActor
    func saveProfile(_ updated: UserProfile) async throws {
        // Always save locally
        self.profile = updated
        saveLocal(updated)

        // If signed in, also push to Supabase
        if let userID = SupabaseManager.shared.currentUserID {
            let birthStr: String? = updated.birthDate.map {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: $0)
            }
            let dto = ProfileUpsertDTO(
                id: userID.uuidString,
                name: updated.name,
                homeCountry: updated.homeCountry,
                homeCity: updated.homeCity,
                birthDate: birthStr,
                travelPace: updated.travelPace.rawValue,
                interests: updated.interests,
                dietaryPreferences: updated.dietaryPreferences,
                visitedCountries: updated.visitedCountries,
                visitedCities: updated.visitedCities,
                chronotype: updated.chronotype.rawValue
            )

            try await SupabaseManager.shared.client
                .from("profiles")
                .upsert(dto)
                .execute()

            print("[ProfileService] saved to Supabase for \(userID)")
        }
    }

    // MARK: - Create Initial

    @MainActor
    func createInitialProfile(name: String?) async throws {
        let initial = UserProfile(name: name ?? "")
        self.profile = initial
        saveLocal(initial)

        if let userID = SupabaseManager.shared.currentUserID {
            let dto = ProfileUpsertDTO(
                id: userID.uuidString,
                name: initial.name,
                homeCountry: "",
                homeCity: "",
                birthDate: nil,
                travelPace: TravelPace.mixed.rawValue,
                interests: [],
                dietaryPreferences: [],
                visitedCountries: [],
                visitedCities: [],
                chronotype: Chronotype.morning.rawValue
            )

            try await SupabaseManager.shared.client
                .from("profiles")
                .upsert(dto)
                .execute()
        }
    }

    // MARK: - Reset

    @MainActor
    func clearProfile() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: localKey)
    }
}
