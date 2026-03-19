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

    init(sections: [Section], source: String) {
        self.sections = sections
        self.source = source
    }

    /// Legacy init for backward compatibility with individual AI services
    init(history: String, tips: String, source: String) {
        var sections: [Section] = []
        if !history.isEmpty {
            sections.append(Section(icon: "scroll", title: "ИСТОРИЯ", text: history, color: "gold"))
        }
        if !tips.isEmpty {
            sections.append(Section(icon: "lightbulb", title: "СОВЕТЫ", text: tips, color: "green"))
        }
        self.sections = sections
        self.source = source
    }

    // Legacy accessors for backward compatibility
    var history: String {
        sections.first { $0.title == "ИСТОРИЯ" || $0.title == "О МЕСТЕ" || $0.title == "КУХНЯ" || $0.title == "О РАЙОНЕ" }?.text ?? ""
    }
    var tips: String {
        sections.first { $0.title == "СОВЕТЫ" }?.text ?? ""
    }

    var formatted: String {
        let parts = sections.map { section in
            let cleanText = section.text
                .replacingOccurrences(of: "**", with: "")
            return "\(section.title)\n\(cleanText)"
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

    private var hasApiKey: Bool {
        GeminiService.shared.hasApiKey
    }

    func fetchInfo(
        placeName: String,
        category: String,
        city: String? = nil,
        tripID: UUID? = nil
    ) async -> PlaceInfo? {
        print("[PlaceInfoService] 🔍 Fetching info for '\(placeName)' (category: \(category), city: \(city ?? "nil"))")
        let cacheKey = "\(provider.rawValue):\(category):\(placeName.lowercased())"
        if let cached = cache[cacheKey] {
            print("[PlaceInfoService] ✅ Cache hit: \(cached.sections.count) sections")
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
        print("[PlaceInfoService] 📚 Fetching Wikipedia context...")
        var wikiContext = ""
        if let wiki = await WikipediaService.fetchExtract(for: placeName) {
            wikiContext = "\n\nКонтекст из Wikipedia:\n\(wiki.text.prefix(2500))"
            print("[PlaceInfoService] 📚 Wikipedia found: \(wiki.text.count) chars")
        } else {
            print("[PlaceInfoService] 📚 No Wikipedia article found")
        }

        let prompt = buildPrompt(
            placeName: placeName,
            category: placeCategory,
            city: city,
            wikiContext: wikiContext
        )

        let aiCacheKey = "ai:placeinfo:\(category):\(placeName.lowercased())"
        if let cached = AICacheManager.shared.get(key: aiCacheKey) {
            let info = parseResponse(cached, category: placeCategory, source: "Cache")
            cache[cacheKey] = info
            return info
        }

        print("[PlaceInfoService] 📤 Sending prompt to Gemini (\(prompt.count) chars)...")
        let rawContent = await GeminiService.shared.rawRequest(prompt: prompt)

        guard let content = rawContent else {
            lastError = GeminiService.shared.lastError ?? "Не удалось получить информацию"
            print("[PlaceInfoService] ❌ Gemini error: \(lastError ?? "")")
            return nil
        }

        print("[PlaceInfoService] 📥 AI response: \(content.count) chars")
        let info = parseResponse(content, category: placeCategory, source: wikiContext.isEmpty ? provider.label : "Wikipedia + \(provider.label)")
        print("[PlaceInfoService] ✅ Parsed \(info.sections.count) sections: \(info.sections.map(\.title).joined(separator: ", "))")
        cache[cacheKey] = info
        AICacheManager.shared.set(key: aiCacheKey, response: content, tripID: tripID)
        return info
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Category-Specific Prompts

    private func buildPrompt(placeName: String, category: PlaceCategory?, city: String?, wikiContext: String) -> String {
        let cityHint = city.map { " в городе \($0)" } ?? ""
        let profileCtx = AIPromptHelper.profileContext()

        let base = "Расскажи о месте \"\(placeName)\"\(cityHint)."

        let format: String
        switch category {
        case .temple, .shrine:
            format = """
            📜 ИСТОРИЯ
            [2-3 предложения: когда и кем основано, религиозное значение, архитектурный стиль. Если есть интересная легенда или исторический факт — добавь.]

            🙏 ЭТИКЕТ
            [2-3 конкретных правила: дресс-код, обувь, можно ли фотографировать, ритуалы для посетителей]

            💡 СОВЕТЫ
            [2-3 совета: лучшее время посещения, стоимость входа, что обязательно посмотреть, особые церемонии по дням]
            """

        case .food:
            format = """
            🍽 КУХНЯ
            [2-3 предложения: тип кухни, фирменные блюда, ценовая категория (средний чек), атмосфера заведения]

            ⭐️ ЧТО ЗАКАЗАТЬ
            [3-4 конкретных блюда с кратким описанием каждого — почему именно это стоит попробовать]

            💡 СОВЕТЫ
            [2-3 совета: часы работы, нужна ли бронь, особенности чаевых, лучшее время для визита без очереди]
            """

        case .shopping:
            format = """
            🛍 О МЕСТЕ
            [2-3 предложения: что здесь продаётся, ценовой уровень, атмосфера, чем отличается от других]

            🎁 ЧТО КУПИТЬ
            [3-4 конкретных товара или сувенира, которые стоит рассмотреть, с примерными ценами]

            💡 СОВЕТЫ
            [2-3 совета: можно ли торговаться, часы работы, налоговый возврат (tax-free), лучшие отделы или этажи]
            """

        case .nature, .park, .garden, .lake, .mountains:
            format = """
            🌿 О МЕСТЕ
            [2-3 предложения: что за место, чем известно, площадь или протяжённость, что увидишь]

            🥾 МАРШРУТЫ
            [2-3 конкретных маршрута или точки интереса внутри с примерным временем]

            💡 СОВЕТЫ
            [2-3 совета: лучший сезон для визита, что взять с собой, стоимость входа, сколько времени закладывать]
            """

        case .culture, .museum, .gallery, .palace, .viewpoint:
            format = """
            📜 ИСТОРИЯ
            [2-3 предложения: когда основано, кем, почему важно, что составляет коллекцию/экспозицию]

            🎭 ЧТО ПОСМОТРЕТЬ
            [3-4 конкретных экспоната, зала или точки, которые нельзя пропустить — с пояснением почему]

            💡 СОВЕТЫ
            [2-3 совета: лучшее время (когда меньше людей), стоимость, есть ли аудиогид, правила фотографирования, сколько времени нужно]
            """

        case .accommodation:
            format = """
            🏨 О РАЙОНЕ
            [2-3 предложения: какой район, транспортная доступность, что интересного рядом]

            🔑 УДОБСТВА
            [3-4 ключевых особенности: Wi-Fi, завтрак, вид из окон, парковка, бассейн]

            💡 СОВЕТЫ
            [2-3 совета: время чек-ина/чек-аута, депозит, ближайшие кафе и магазины]
            """

        case .transport:
            format = """
            🚆 О МАРШРУТЕ
            [2-3 предложения: тип транспорта, маршрут, длительность поездки, частота рейсов]

            🎫 БИЛЕТЫ
            [Конкретная стоимость, где купить, нужна ли бронь, классы обслуживания]

            💡 СОВЕТЫ
            [2-3 совета: лучшие места в вагоне, что взять в дорогу, пересадки, правила багажа]
            """

        case .stadium, .sport:
            format = """
            🏟 О МЕСТЕ
            [2-3 предложения: какой вид спорта, вместимость, история, знаковые события или матчи]

            🎫 БИЛЕТЫ И СОБЫТИЯ
            [Где и как купить билеты, сезон, ближайшие крупные события]

            💡 СОВЕТЫ
            [2-3 совета: как добраться, что рядом, фан-зоны, за сколько приезжать до матча]
            """

        case .airport, .station, .metro:
            format = """
            📜 ИСТОРИЯ
            [1-2 предложения: когда построено, кем, архитектурные особенности]

            💡 СОВЕТЫ
            [2-3 практических совета для путешественника: навигация, камеры хранения, еда, Wi-Fi]
            """

        case nil:
            format = """
            📜 ИСТОРИЯ
            [2-3 предложения: когда построено/основано, кем, почему это место важно или интересно]

            💡 СОВЕТЫ
            [2-3 практических совета: лучшее время для визита, что не пропустить, стоимость, этикет]
            """
        }

        return """
        \(base)
        \(wikiContext)
        \(profileCtx)

        Ответь строго на русском языке в формате:

        \(format)

        ПРАВИЛА:
        - Пиши простым текстом, без markdown (###, ##, #), без звёздочек (**), без нумерованных списков
        - Давай конкретные факты: даты, цены, названия, часы работы — а не общие фразы
        - Если для секции нет достоверной информации — ПРОПУСТИ секцию целиком
        - Если не уверен в факте — так и напиши, не выдумывай
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
                if let def = currentDef {
                    let cleaned = cleanSectionText(currentText)
                    if !cleaned.isEmpty && !isEmptyContent(cleaned) {
                        sections.append(PlaceInfo.Section(icon: def.icon, title: def.title, text: cleaned, color: def.color))
                    }
                }
                currentDef = (matched.icon, matched.title, matched.color)
                currentText = ""
            } else if !trimmed.isEmpty {
                currentText += (currentText.isEmpty ? "" : "\n") + trimmed
            }
        }

        // Save last section
        if let def = currentDef {
            let cleaned = cleanSectionText(currentText)
            if !cleaned.isEmpty && !isEmptyContent(cleaned) {
                sections.append(PlaceInfo.Section(icon: def.icon, title: def.title, text: cleaned, color: def.color))
            }
        }

        // Fallback: if no sections parsed, put everything in one section
        if sections.isEmpty {
            let cleaned = cleanSectionText(text)
            if !cleaned.isEmpty {
                sections.append(PlaceInfo.Section(icon: "info.circle", title: "ИНФОРМАЦИЯ", text: cleaned, color: "blue"))
            }
        }

        return PlaceInfo(sections: sections, source: source)
    }

    /// Strip markdown headers and formatting artifacts
    private func cleanSectionText(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove markdown headers (### Header → Header)
        result = result.replacingOccurrences(
            of: #"^#{1,4}\s+"#,
            with: "",
            options: .regularExpression
        )
        // Multi-line: remove ### at line starts
        result = result.replacingOccurrences(
            of: #"\n#{1,4}\s+"#,
            with: "\n",
            options: .regularExpression
        )
        // Remove ** bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        // Remove standalone emoji prefixes on section-like lines
        result = result.replacingOccurrences(
            of: #"^[\p{So}\p{Sk}]\s+"#,
            with: "",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if text is essentially empty / "no data"
    private func isEmptyContent(_ text: String) -> Bool {
        let lower = text.lowercased()
        let emptyMarkers = [
            "информация отсутствует", "нет данных", "данные отсутствуют",
            "информация недоступна", "нет информации", "не удалось найти",
            "к сожалению, информация", "к сожалению, данные"
        ]
        return emptyMarkers.contains { lower.contains($0) } && text.count < 100
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
        case .airport, .station, .metro:
            return [
                SectionDef(marker: "ИСТОРИЯ", icon: "scroll", title: "ИСТОРИЯ", color: "gold"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .museum, .gallery, .palace, .viewpoint, .stadium:
            return [
                SectionDef(marker: "ИСТОРИЯ", icon: "scroll", title: "ИСТОРИЯ", color: "gold"),
                SectionDef(marker: "ЧТО ПОСМОТРЕТЬ", icon: "theatermasks", title: "ЧТО ПОСМОТРЕТЬ", color: "pink"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "green"),
            ]
        case .park, .garden, .lake, .mountains:
            return [
                SectionDef(marker: "О МЕСТЕ", icon: "leaf", title: "О МЕСТЕ", color: "green"),
                SectionDef(marker: "МАРШРУТЫ", icon: "figure.walk", title: "МАРШРУТЫ", color: "blue"),
                SectionDef(marker: "СОВЕТЫ", icon: "lightbulb", title: "СОВЕТЫ", color: "gold"),
            ]
        case .sport:
            return [
                SectionDef(marker: "О МЕСТЕ", icon: "sportscourt", title: "О МЕСТЕ", color: "blue"),
                SectionDef(marker: "БИЛЕТЫ И СОБЫТИЯ", icon: "ticket", title: "БИЛЕТЫ И СОБЫТИЯ", color: "gold"),
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
