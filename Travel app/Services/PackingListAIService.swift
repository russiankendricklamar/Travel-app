import Foundation

@MainActor
final class PackingListAIService {
    static let shared = PackingListAIService()
    private init() {}

    func generateSuggestions(for trip: Trip) async -> [(name: String, category: PackingCategory)] {
        let duration = Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 7
        let placeTypes = Set(trip.allPlaces.map(\.category.rawValue)).joined(separator: ", ")
        let hasFlights = trip.flightNumber != nil

        let prompt = """
        Ты — опытный путешественник. Составь список вещей для поездки:
        - Направление: \(trip.destination)
        - Длительность: \(duration) дней
        - Типы мест: \(placeTypes.isEmpty ? "разные" : placeTypes)
        - Перелёт: \(hasFlights ? "да" : "нет")

        Ответь строго в формате (каждая строка):
        КАТЕГОРИЯ|НАЗВАНИЕ

        Категории: documents, clothing, electronics, toiletries, medicine, other

        Примеры:
        documents|Загранпаспорт
        clothing|Футболки (\(min(duration, 7)) шт)
        electronics|Зарядка для телефона

        Дай 15-20 предметов. Без нумерации, без пояснений, только список.
        """

        let provider = AIProvider.current

        var response: String?

        switch provider {
        case .groq:
            response = await GroqService.shared.rawRequest(prompt: prompt)
        case .claude:
            response = await ClaudeService.shared.rawRequest(prompt: prompt)
        case .openai:
            response = await OpenAIService.shared.rawRequest(prompt: prompt)
        case .gemini:
            response = await GeminiService.shared.rawRequest(prompt: prompt)
        }

        guard let text = response else { return defaultSuggestions(duration: duration) }
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
