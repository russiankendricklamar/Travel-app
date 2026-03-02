import Foundation

@MainActor
@Observable
final class GroqService {
    static let shared = GroqService()

    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    private let model = "llama-3.3-70b-versatile"

    var isLoading = false

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
    }

    var hasApiKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Summarize Wikipedia article

    func summarize(wikiText: String, placeName: String, category: String) async -> PlaceInfo? {
        let prompt = """
        Ты — опытный гид по Японии. На основе статьи из Wikipedia составь краткую справку о месте "\(placeName)" (категория: \(category)).

        Статья:
        \(wikiText.prefix(3000))

        Ответь строго на русском языке в формате:

        📜 ИСТОРИЯ
        [2-3 предложения: когда построено/основано, кем, почему важно]

        💡 СОВЕТЫ
        [2-3 практических совета: лучшее время, что не пропустить, этикет, примерная стоимость]
        """

        return await request(prompt: prompt, source: "Wikipedia + AI")
    }

    // MARK: - Generate from AI knowledge

    func generateInfo(placeName: String, category: String, city: String?) async -> PlaceInfo? {
        let cityHint = city.map { ", город: \($0)" } ?? ""
        let prompt = """
        Ты — опытный гид по Японии. Расскажи о месте "\(placeName)" (категория: \(category)\(cityHint)) в Японии.

        Ответь строго на русском языке в формате:

        📜 ИСТОРИЯ
        [2-3 предложения: когда построено/основано, кем, почему важно. Если это ресторан/магазин — расскажи о районе и специализации]

        💡 СОВЕТЫ
        [2-3 практических совета: лучшее время посещения, что не пропустить, этикет, примерная стоимость]

        Если ты не уверен в фактах — так и скажи, не выдумывай.
        """

        return await request(prompt: prompt, source: "AI")
    }

    // MARK: - Private

    private func request(prompt: String, source: String) async -> PlaceInfo? {
        guard hasApiKey else { return nil }
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 1024
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[GroqService] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return nil
            }

            return parseResponse(content, source: source)
        } catch {
            print("[GroqService] Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseResponse(_ text: String, source: String) -> PlaceInfo {
        // Try to split by sections
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
                    // Before any marker — treat as history
                    history += (history.isEmpty ? "" : "\n") + trimmed
                }
            }
        }

        // If parsing failed, use full text as history
        if history.isEmpty && tips.isEmpty {
            history = text
        }

        return PlaceInfo(history: history, tips: tips, source: source)
    }
}
