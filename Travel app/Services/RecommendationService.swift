import Foundation

@MainActor
@Observable
final class RecommendationService {
    static let shared = RecommendationService()

    var isLoading = false
    var lastError: String?
    var recommendations: [PlaceRecommendation] = []

    private var cache: [String: [PlaceRecommendation]] = [:]

    private var provider: AIProvider {
        AIProvider.current
    }

    private var hasApiKey: Bool {
        switch provider {
        case .groq: GroqService.shared.hasApiKey
        case .claude: ClaudeService.shared.hasApiKey
        case .openai: OpenAIService.shared.hasApiKey
        case .gemini: GeminiService.shared.hasApiKey
        }
    }

    func fetchRecommendations(city: String, categories: Set<String>) async {
        let categoriesKey = categories.sorted().joined(separator: ",")
        let cacheKey = "\(provider.rawValue):\(city.lowercased())|\(categoriesKey)"

        if let cached = cache[cacheKey] {
            recommendations = cached
            return
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard hasApiKey else {
            lastError = "Добавьте API-ключ в Настройках"
            return
        }

        let categoriesText = categories.isEmpty ? "любые" : categories.joined(separator: ", ")

        let prompt = """
        Ты — опытный гид-путешественник. Порекомендуй 8 интересных мест в городе "\(city)".
        Категории: \(categoriesText).

        Ответь СТРОГО в формате JSON-массива, без пояснений, без markdown:
        [
          {
            "name": "Название места",
            "description": "Краткое описание на 1-2 предложения",
            "category": "Категория (Еда/Культура/Природа/Шопинг/Храм/Святилище)",
            "estimatedTime": "1-2 часа",
            "latitude": 35.6762,
            "longitude": 139.6503
          }
        ]

        Все тексты на русском языке. Координаты должны быть реальными.
        """

        let rawContent: String?
        switch provider {
        case .groq:
            rawContent = await GroqService.shared.rawRequest(prompt: prompt)
        case .claude:
            rawContent = await ClaudeService.shared.rawRequest(prompt: prompt)
        case .openai:
            rawContent = await OpenAIService.shared.rawRequest(prompt: prompt)
        case .gemini:
            rawContent = await GeminiService.shared.rawRequest(prompt: prompt)
        }

        guard let content = rawContent else {
            lastError = "Не удалось получить рекомендации"
            return
        }

        if let parsed = parseRecommendations(from: content) {
            recommendations = parsed
            cache[cacheKey] = parsed
        } else {
            lastError = "Ошибка разбора ответа ИИ"
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - JSON Parsing

    private func parseRecommendations(from text: String) -> [PlaceRecommendation]? {
        // Strip markdown code fences if present
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON array bounds
        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else { return nil }

        cleaned = String(cleaned[start...end])

        guard let data = cleaned.data(using: .utf8) else { return nil }

        do {
            let items = try JSONDecoder().decode([PlaceRecommendation].self, from: data)
            return items
        } catch {
            print("[RecommendationService] JSON decode error: \(error)")
            return nil
        }
    }
}
