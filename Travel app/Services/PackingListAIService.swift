import Foundation

@MainActor
final class PackingListAIService {
    static let shared = PackingListAIService()
    private init() {}

    func generateSuggestions(for trip: Trip) async -> [(name: String, category: PackingCategory)] {
        let duration = Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 7
        let placeTypes = Set(trip.allPlaces.map(\.category.rawValue)).joined(separator: ", ")
        let hasFlights = trip.flightNumber != nil

        // Fetch country info for region-aware suggestions
        let countryInfos = await CountryInfoService.shared.fetchAll(for: trip.countries)
        let regions = countryInfos.values.compactMap(\.region).unique()
        let languages = countryInfos.values.compactMap(\.language).unique()
        let capitals = countryInfos.values.compactMap(\.capital).unique()

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "ru_RU")
        monthFormatter.dateFormat = "LLLL"
        let travelMonth = monthFormatter.string(from: trip.startDate)

        let profileCtx = AIPromptHelper.profileContext()

        let prompt = """
        Составь список вещей для поездки:
        - Куда: \(trip.countriesDisplay) (\(regions.isEmpty ? "" : regions.joined(separator: ", ")))
        - Месяц: \(travelMonth), \(duration) дней
        - Места: \(placeTypes.isEmpty ? "разные" : placeTypes)
        - Перелёт: \(hasFlights ? "да" : "нет")
        \(profileCtx)

        Учитывай климат региона и сезон.

        Формат (каждая строка): КАТЕГОРИЯ|НАЗВАНИЕ
        Категории: documents, clothing, electronics, toiletries, medicine, other

        15-20 предметов. Без нумерации, без пояснений.
        """

        let aiCacheKey = "ai:packing:\(trip.id.uuidString)"
        if let cached = AICacheManager.shared.get(key: aiCacheKey) {
            return parseSuggestions(cached)
        }

        guard let text = await GeminiService.shared.rawRequest(prompt: prompt) else {
            return defaultSuggestions(duration: duration)
        }
        AICacheManager.shared.set(key: aiCacheKey, response: text, tripID: trip.id)
        return parseSuggestions(text)
    }

    private func parseSuggestions(_ text: String) -> [(name: String, category: PackingCategory)] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "|")
                guard parts.count == 2 else { return nil }
                let catRaw = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let name = parts[1].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                let category = PackingCategory(rawValue: catRaw) ?? .other
                return (name: name, category: category)
            }
    }

    private func defaultSuggestions(duration: Int) -> [(name: String, category: PackingCategory)] {
        [
            ("Загранпаспорт", .documents),
            ("Копия паспорта", .documents),
            ("Страховка", .documents),
            ("Футболки (\(min(duration, 7)) шт)", .clothing),
            ("Нижнее бельё", .clothing),
            ("Удобная обувь", .clothing),
            ("Куртка/ветровка", .clothing),
            ("Зарядка для телефона", .electronics),
            ("Power bank", .electronics),
            ("Наушники", .electronics),
            ("Зубная щётка", .toiletries),
            ("Шампунь (мини)", .toiletries),
            ("Солнцезащитный крем", .toiletries),
            ("Обезболивающее", .medicine),
            ("Пластыри", .medicine),
        ]
    }
}
