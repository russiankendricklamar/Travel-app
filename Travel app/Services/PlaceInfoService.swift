import Foundation
import CoreLocation

/// Result of AI place info lookup
struct PlaceInfo {
    let history: String
    let tips: String
    let source: String

    var formatted: String {
        var parts: [String] = []
        if !history.isEmpty {
            parts.append("📜 История\n\(history)")
        }
        if !tips.isEmpty {
            parts.append("💡 Советы\n\(tips)")
        }
        if !parts.isEmpty {
            parts.append("— \(source)")
        }
        return parts.joined(separator: "\n\n")
    }
}

@MainActor
@Observable
final class PlaceInfoService {
    static let shared = PlaceInfoService()

    var isLoading = false
    var lastError: String?

    private var cache: [String: PlaceInfo] = [:]

    private var provider: AIProvider {
        AIProvider.current
    }

    /// Check if the current provider has an API key configured
    private var hasApiKey: Bool {
        switch provider {
        case .groq: GroqService.shared.hasApiKey
        case .claude: ClaudeService.shared.hasApiKey
        case .openai: OpenAIService.shared.hasApiKey
        case .gemini: GeminiService.shared.hasApiKey
        }
    }

    /// Fetch info about a place using the selected AI provider
    func fetchInfo(
        placeName: String,
        category: String,
        city: String? = nil
    ) async -> PlaceInfo? {
        let cacheKey = "\(provider.rawValue):\(placeName.lowercased())"
        if let cached = cache[cacheKey] {
            return cached
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard hasApiKey else {
            lastError = provider.needsApiKey
                ? "Добавьте \(provider.label) API-ключ в Настройках"
                : "API-ключ не настроен"
            return nil
        }

        // Step 1: Try Wikipedia
        if let wiki = await WikipediaService.fetchExtract(for: placeName) {
            // Step 2: Summarize with selected provider
            if let info = await summarize(wikiText: wiki.text, placeName: placeName, category: category) {
                cache[cacheKey] = info
                return info
            }
        }

        // Step 3: No Wikipedia article — generate from AI knowledge
        if let info = await generateInfo(placeName: placeName, category: category, city: city) {
            cache[cacheKey] = info
            return info
        }

        lastError = "Не удалось получить информацию"
        return nil
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private routing

    private func summarize(wikiText: String, placeName: String, category: String) async -> PlaceInfo? {
        switch provider {
        case .groq:
            await GroqService.shared.summarize(wikiText: wikiText, placeName: placeName, category: category)
        case .claude:
            await ClaudeService.shared.summarize(wikiText: wikiText, placeName: placeName, category: category)
        case .openai:
            await OpenAIService.shared.summarize(wikiText: wikiText, placeName: placeName, category: category)
        case .gemini:
            await GeminiService.shared.summarize(wikiText: wikiText, placeName: placeName, category: category)
        }
    }

    private func generateInfo(placeName: String, category: String, city: String?) async -> PlaceInfo? {
        switch provider {
        case .groq:
            await GroqService.shared.generateInfo(placeName: placeName, category: category, city: city)
        case .claude:
            await ClaudeService.shared.generateInfo(placeName: placeName, category: category, city: city)
        case .openai:
            await OpenAIService.shared.generateInfo(placeName: placeName, category: category, city: city)
        case .gemini:
            await GeminiService.shared.generateInfo(placeName: placeName, category: category, city: city)
        }
    }
}
