import Foundation

@MainActor
@Observable
final class GeminiService {
    static let shared = GeminiService()

    private let model = "gemini-2.0-flash"

    var isLoading = false

    private var apiKey: String {
        Secrets.geminiApiKey
    }

    var hasApiKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var endpoint: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
    }

    // MARK: - Summarize Wikipedia article

    func summarize(wikiText: String, placeName: String, category: String) async -> PlaceInfo? {
        let prompt = """
        Ты — опытный гид-путешественник. На основе статьи из Wikipedia составь краткую справку о месте "\(placeName)" (категория: \(category)).

        Статья:
        \(wikiText.prefix(3000))

        Ответь строго на русском языке в формате:

        📜 ИСТОРИЯ
        [2-3 предложения: когда построено/основано, кем, почему важно]

        💡 СОВЕТЫ
        [2-3 практических совета: лучшее время, что не пропустить, этикет, примерная стоимость]
        """

        return await request(prompt: prompt, source: "Wikipedia + Gemini")
    }

    // MARK: - Generate from AI knowledge

    func generateInfo(placeName: String, category: String, city: String?) async -> PlaceInfo? {
        let cityHint = city.map { ", город: \($0)" } ?? ""
        let prompt = """
        Ты — опытный гид-путешественник. Расскажи о месте "\(placeName)" (категория: \(category)\(cityHint)).

        Ответь строго на русском языке в формате:

        📜 ИСТОРИЯ
        [2-3 предложения: когда построено/основано, кем, почему важно. Если это ресторан/магазин — расскажи о районе и специализации]

        💡 СОВЕТЫ
        [2-3 практических совета: лучшее время посещения, что не пропустить, этикет, примерная стоимость]

        Если ты не уверен в фактах — так и скажи, не выдумывай.
        """

        return await request(prompt: prompt, source: "Gemini")
    }

    // MARK: - Raw Request

    func rawRequest(prompt: String) async -> String? {
        guard hasApiKey else { return nil }

        guard let url = URL(string: endpoint) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 2048
            ]
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else { return nil }

            return text
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func request(prompt: String, source: String) async -> PlaceInfo? {
        guard hasApiKey else { return nil }
        isLoading = true
        defer { isLoading = false }

        guard let text = await rawRequest(prompt: prompt) else { return nil }
        return parseResponse(text, source: source)
    }

    private func parseResponse(_ text: String, source: String) -> PlaceInfo {
        let historyMarkers = ["📜 ИСТОРИЯ", "ИСТОРИЯ", "📜"]
        let tipsMarkers = ["💡 СОВЕТЫ", "СОВЕТЫ", "💡"]

        var history = ""
        var tips = ""

        let lines = text.components(separatedBy: "\n")
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if historyMarkers.contains(where: { trimmed.hasPrefix($0) }) {
                currentSection = "history"
                continue
            }
            if tipsMarkers.contains(where: { trimmed.hasPrefix($0) }) {
                currentSection = "tips"
                continue
            }
            if !trimmed.isEmpty {
                switch currentSection {
                case "history":
                    history += (history.isEmpty ? "" : "\n") + trimmed
                case "tips":
                    tips += (tips.isEmpty ? "" : "\n") + trimmed
                default:
                    history += (history.isEmpty ? "" : "\n") + trimmed
                }
            }
        }

        if history.isEmpty && tips.isEmpty {
            history = text
        }

        return PlaceInfo(history: history, tips: tips, source: source)
    }
}
