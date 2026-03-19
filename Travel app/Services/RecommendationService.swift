import Foundation
import SwiftData

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
        GeminiService.shared.hasApiKey
    }

    func fetchRecommendations(city: String, categories: Set<String>, tripID: UUID? = nil, tripCount: Int = 0, bucketItems: [String] = []) async {
        let categoriesKey = categories.sorted().joined(separator: ",")
        let cacheKey = "\(provider.rawValue):\(city.lowercased())|\(categoriesKey)"

        print("[RecommendationService] 🔍 Fetching recommendations for '\(city)', categories: \(categoriesKey)")

        if let cached = cache[cacheKey] {
            print("[RecommendationService] ✅ Cache hit: \(cached.count) recommendations")
            recommendations = cached
            return
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard hasApiKey else {
            lastError = "Добавьте API-ключ в Настройках"
            print("[RecommendationService] ❌ No API key")
            return
        }

        let categoriesText = categories.isEmpty ? "любые" : categories.joined(separator: ", ")
        let profileCtx = AIPromptHelper.profileContext(tripCount: tripCount, bucketItems: bucketItems)

        let prompt = """
        Порекомендуй 8 интересных мест в городе "\(city)".
        Категории: \(categoriesText).
        \(profileCtx)

        Для каждого места напиши описание в 1-2 предложения: что конкретно там делать, чем место примечательно. Конкретика, не общие слова.

        Ответь ТОЛЬКО JSON-массивом. Никакого текста до или после, никакого markdown.

        Формат каждого элемента:
        {
          "name": "Название места",
          "description": "Описание на 1-2 предложения",
          "category": "Одна из категорий",
          "estimated_time": "1-2 часа",
          "latitude": 35.6762,
          "longitude": 139.6503
        }

        Правила:
        - category — одна из: \(categoriesText)
        - estimated_time — примерное время на посещение
        - latitude/longitude — реальные координаты этого места
        - Все тексты на русском языке
        - Ответ — ТОЛЬКО JSON-массив из 8 объектов, ничего больше
        """

        let aiCacheKey = "ai:recommend:\(city.lowercased())|\(categoriesKey)"
        if let cached = AICacheManager.shared.get(key: aiCacheKey) {
            if let parsed = parseRecommendations(from: cached) {
                recommendations = parsed
                cache[cacheKey] = parsed
                return
            }
        }

        print("[RecommendationService] 📤 Sending prompt to Gemini (\(prompt.count) chars)...")
        let rawContent = await GeminiService.shared.rawRequest(prompt: prompt)

        guard let content = rawContent else {
            let geminiError = GeminiService.shared.lastError ?? "Не удалось получить рекомендации"
            lastError = geminiError
            print("[RecommendationService] ❌ Gemini error: \(geminiError)")
            return
        }

        print("[RecommendationService] 📥 AI response: \(content.count) chars")
        if let parsed = parseRecommendations(from: content) {
            print("[RecommendationService] ✅ Parsed \(parsed.count) recommendations")
            recommendations = parsed
            cache[cacheKey] = parsed
            AICacheManager.shared.set(key: aiCacheKey, response: content, tripID: tripID)
        } else {
            lastError = "Ошибка разбора ответа ИИ"
            print("[RecommendationService] ❌ Failed to parse AI response: \(content.prefix(200))")
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

        // CodingKeys handles snake_case mapping natively

        guard let data = cleaned.data(using: .utf8) else { return nil }

        do {
            let items = try JSONDecoder().decode([PlaceRecommendation].self, from: data)
            return items
        } catch {
            print("[RecommendationService] JSON parse error: \(error)")
            return nil
        }
    }
}
