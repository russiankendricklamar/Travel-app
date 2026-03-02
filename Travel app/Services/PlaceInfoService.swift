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

    /// Fetch info about a place: Wikipedia → Groq summarize, or Groq generate if no article
    func fetchInfo(
        placeName: String,
        category: String,
        city: String? = nil
    ) async -> PlaceInfo? {
        let cacheKey = placeName.lowercased()
        if let cached = cache[cacheKey] {
            return cached
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let groq = GroqService.shared
        guard groq.hasApiKey else {
            lastError = "Добавьте Groq API-ключ в Настройках"
            return nil
        }

        // Step 1: Try Wikipedia
        if let wiki = await WikipediaService.fetchExtract(for: placeName) {
            // Step 2: Summarize with Groq
            if let info = await groq.summarize(
                wikiText: wiki.text,
                placeName: placeName,
                category: category
            ) {
                cache[cacheKey] = info
                return info
            }
        }

        // Step 3: No Wikipedia article — generate from Groq knowledge
        if let info = await groq.generateInfo(
            placeName: placeName,
            category: category,
            city: city
        ) {
            cache[cacheKey] = info
            return info
        }

        lastError = "Не удалось получить информацию"
        return nil
    }

    func clearCache() {
        cache.removeAll()
    }
}
