import Foundation
import CoreLocation

/// Result of AI place info lookup
struct PlaceInfo {
    let sections: [Section]
    let source: String

    struct Section {
        let icon: String
        let title: String
        let text: String
        let color: String // "gold", "green", "blue", "pink", "red"
    }

    // Legacy accessors for backward compatibility
    var history: String {
        sections.first { $0.title == "ИСТОРИЯ" || $0.title == "О МЕСТЕ" || $0.title == "КУХНЯ" || $0.title == "О РАЙОНЕ" }?.text ?? ""
    }
    var tips: String {
        sections.first { $0.title == "СОВЕТЫ" }?.text ?? ""
    }

    var formatted: String {
        var parts = sections.map { "[\($0.title)] \($0.text)" }
        parts.append("— \(source)")
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

    private var hasApiKey: Bool {
        switch provider {
        case .groq: GroqService.shared.hasApiKey
        case .claude: ClaudeService.shared.hasApiKey
        case .openai: OpenAIService.shared.hasApiKey
        case .gemini: GeminiService.shared.hasApiKey
        }
    }

    func fetchInfo(
        placeName: String,
        category: String,
        city: String? = nil
    ) async -> PlaceInfo? {
        let cacheKey = "\(provider.rawValue):\(category):\(placeName.lowercased())"
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

        let placeCategory = PlaceCategory(rawValue: category)

        // Step 1: Try Wikipedia context
        var wikiContext = ""
        if let wiki = await WikipediaService.fetchExtract(for: placeName) {
            wikiContext = "\n\nКонтекст из Wikipedia:\n\(wiki.text.prefix(2500))"
        }

        let prompt = buildPrompt(
            placeName: placeName,
            category: placeCategory,
            city: city,
            wikiContext: wikiContext
        )

        let rawContent: String?
        switch provider {
        case .groq: rawContent = await GroqService.shared.rawRequest(prompt: prompt)
        case .claude: rawContent = await ClaudeService.shared.rawRequest(prompt: prompt)
        case .openai: rawContent = await OpenAIService.shared.rawRequest(prompt: prompt)
        case .gemini: rawContent = await GeminiService.shared.rawRequest(prompt: prompt)
        }

        guard let content = rawContent else {
            lastError = "Не удалось получить информацию"
            return nil
        }

        let info = parseResponse(content, category: placeCategory, source: wikiContext.isEmpty ? provider.label : "Wikipedia + \(provider.label)")
        cache[cacheKey] = info
        return info
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Category-Specific Prompts

    private func buildPrompt(placeName: String, category: PlaceCategory?, city: String?, wikiContext: String) -> String {
        let cityHint = city.map { " в городе \($0)" } ?? ""
        let base = "Ты — опытный гид-путешественник. Расскажи о месте \"\(placeName)\"\(cityHint)."

        let format: String
        switch category {
        case .temple, .shrine:
            format = """
            📜 ИСТОРИЯ
            [2-3 предложения: когда основано, кем, религиозное значение, архитектурный стиль]

            🙏 ЭТИКЕТ
            [2-3 правила поведения: дресс-код, обувь, фотографирование, ритуалы для посетителей]

            💡 СОВЕТЫ
            [2-3 совета: лучшее время посещения, что не пропустить, стоимость входа, особые церемонии]
            """

        case .food:
            format = """
            🍽 КУХНЯ
            [2-3 предложения: тип кухни, фирменные блюда, ценовая категория, атмосфера]

            ⭐️ ЧТО ЗАКАЗАТЬ
            [3-4 конкретных блюда которые стоит попробовать, с кратким описанием]

            💡 СОВЕТЫ
            [2-3 совета: время работы, нужна ли бронь, чаевые, очереди, рекомендации по времени визита]
            """

        case .shopping:
            format = """
            🛍 О МЕСТЕ
            [2-3 предложения: что продаётся, ценовой уровень, атмосфера, популярность]

            🎁 ЧТО КУПИТЬ
            [3-4 товара/сувенира которые стоит рассмотреть]

            💡 СОВЕТЫ
            [2-3 совета: торг, время работы, налоговый возврат (tax-free), лучшие отделы/этажи]
            """

        case .nature:
            format = """
            🌿 О МЕСТЕ
            [2-3 предложения: что за место, чем известно, площадь/протяжённость]

            🥾 МАРШРУТЫ
            [2-3 рекомендуемых маршрута или точки интереса внутри]

            💡 СОВЕТЫ
            [2-3 совета: лучший сезон, что взять с собой, стоимость, время на осмотр]
            """

        case .culture:
            format = """
            📜 ИСТОРИЯ
            [2-3 предложения: когда основано, кем, почему важно, основные коллекции/экспозиции]

            🎭 ЧТО ПОСМОТРЕТЬ
            [3-4 главных экспоната или зоны которые нельзя пропустить]

            💡 СОВЕТЫ
            [2-3 совета: лучшее время, стоимость, аудиогид, фотографирование, время на осмотр]
            """

        case .accommodation:
            format = """
            🏨 О РАЙОНЕ
            [2-3 предложения: район, транспортная доступность, что рядом]

            🔑 УДОБСТВА
            [3-4 ключевых особенности: Wi-Fi, завтрак, вид, парковка]

            💡 СОВЕТЫ
            [2-3 совета: чек-ин/чек-аут, депозит, что рядом из еды и магазинов]
            """

        case .transport:
            format = """
            🚆 О МАРШРУТЕ
            [2-3 предложения: тип транспорта, маршрут, длительность поездки]

            🎫 БИЛЕТЫ
            [стоимость, где купить, нужна ли бронь, классы обслуживания]

            💡 СОВЕТЫ
            [2-3 совета: лучшие места, что взять в дорогу, пересадки, багаж]
            """

        case nil:
            format = """
            📜 ИСТОРИЯ
            [2-3 предложения: когда построено/основано, кем, почему важно]

            💡 СОВЕТЫ
            [2-3 практических совета: лучшее время, что не пропустить, этикет, стоимость]
            """
        }

        return """
        \(base)
        \(wikiContext)

        Ответь строго на русском языке в формате:

        \(format)

        Если ты не уверен в фактах — так и скажи, не выдумывай.
        """
    }

    // MARK: - Response Parsing

    private func parseResponse(_ text: String, category: PlaceCategory?, source: String) -> PlaceInfo {
        let sectionDefs = sectionDefinitions(for: category)
        var sections: [PlaceInfo.Section] = []
        var currentDef: (icon: String, title: String, color: String)?
        var currentText = ""

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let matched = sectionDefs.first(where: { trimmed.contains($0.marker) }) {
                // Save previous section
                if let def = currentDef, !currentText.isEmpty {
                    sections.append(PlaceInfo.Section(icon: def.icon, title: def.title, text: currentText.trimmingCharacters(in: .whitespacesAndNewlines), color: def.color))
                }
                currentDef = (matched.icon, matched.title, matched.color)
                currentText = ""
            } else if !trimmed.isEmpty {
                currentText += (currentText.isEmpty ? "" : "\n") + trimmed
            }
        }

        // Save last section
        if let def = currentDef, !currentText.isEmpty {
            sections.append(PlaceInfo.Section(icon: def.icon, title: def.title, text: currentText.trimmingCharacters(in: .whitespacesAndNewlines), color: def.color))
        }

        // Fallback: if no sections parsed, put everything in one section
        if sections.isEmpty {
            sections.append(PlaceInfo.Section(icon: "info.circle", title: "ИНФОРМАЦИЯ", text: text, color: "blue"))
        }

        return PlaceInfo(sections: sections, source: source)
    }

    private struct SectionDef {
        let marker: String
        let icon: String
        let title: String
        let color: String
    }

    private func sectionDefinitions(for category: PlaceCategory?) -> [SectionDef] {
        switch category {
        case .temple, .shrine:
            return [
                SectionDef(marker: "ИСТОРИЯ", icon: "scroll", title: "ИСТОРИЯ", color: "gold"),
                SectionDef(marker: "ЭТИКЕТ", icon: "hands.sparkles", title: "ЭТИКЕТ", color: "pink"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .food:
            return [
                SectionDef(marker: "КУХНЯ", icon: "fork.knife", title: "КУХНЯ", color: "gold"),
                SectionDef(marker: "ЧТО ЗАКАЗАТЬ", icon: "star", title: "ЧТО ЗАКАЗАТЬ", color: "pink"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .shopping:
            return [
                SectionDef(marker: "О МЕСТЕ", icon: "bag", title: "О МЕСТЕ", color: "gold"),
                SectionDef(marker: "ЧТО КУПИТЬ", icon: "gift", title: "ЧТО КУПИТЬ", color: "pink"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .nature:
            return [
                SectionDef(marker: "О МЕСТЕ", icon: "leaf", title: "О МЕСТЕ", color: "green"),
                SectionDef(marker: "МАРШРУТЫ", icon: "figure.walk", title: "МАРШРУТЫ", color: "blue"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "gold"),
            ]
        case .culture:
            return [
                SectionDef(marker: "ИСТОРИЯ", icon: "scroll", title: "ИСТОРИЯ", color: "gold"),
                SectionDef(marker: "ЧТО ПОСМОТРЕТЬ", icon: "theatermasks", title: "ЧТО ПОСМОТРЕТЬ", color: "pink"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .accommodation:
            return [
                SectionDef(marker: "О РАЙОНЕ", icon: "building.2", title: "О РАЙОНЕ", color: "blue"),
                SectionDef(marker: "УДОБСТВА", icon: "key", title: "УДОБСТВА", color: "gold"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .transport:
            return [
                SectionDef(marker: "О МАРШРУТЕ", icon: "tram", title: "О МАРШРУТЕ", color: "blue"),
                SectionDef(marker: "БИЛЕТЫ", icon: "ticket", title: "БИЛЕТЫ", color: "gold"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case nil:
            return [
                SectionDef(marker: "ИСТОРИЯ", icon: "scroll", title: "ИСТОРИЯ", color: "gold"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        }
    }
}
