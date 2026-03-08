import Foundation

@MainActor
@Observable
final class GeminiService {
    static let shared = GeminiService()

    private let model = "gemini-2.5-flash"

    var isLoading = false
    var lastError: String?

    private var localApiKey: String {
        Secrets.geminiApiKey
    }

    private var hasLocalApiKey: Bool {
        !localApiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Always available: proxy works without a local key
    var hasApiKey: Bool {
        true
    }

    private var useProxy: Bool {
        !hasLocalApiKey
    }

    private var endpoint: String {
        if useProxy {
            return "\(Secrets.supabaseURL)/functions/v1/gemini-proxy"
        }
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(localApiKey)"
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
        lastError = nil

        guard let url = URL(string: endpoint) else {
            lastError = "Некорректный URL Gemini API"
            return nil
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        // Supabase Edge Function proxy auth
        if useProxy {
            req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 65536
            ]
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                lastError = "Нет ответа от сервера"
                return nil
            }
            guard (200...299).contains(http.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                if http.statusCode == 400 {
                    lastError = "Ошибка запроса (400). Проверьте API-ключ"
                } else if http.statusCode == 403 {
                    lastError = "Доступ запрещён (403). API-ключ недействителен"
                } else if http.statusCode == 429 {
                    lastError = "Превышен лимит запросов (429)"
                } else {
                    lastError = "Ошибка Gemini API: HTTP \(http.statusCode)"
                }
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                // Check for blocked/safety responses
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let reason = candidates.first?["finishReason"] as? String,
                   reason == "SAFETY" {
                    lastError = "Ответ заблокирован фильтром безопасности"
                } else {
                    lastError = "Неожиданный формат ответа Gemini"
                }
                return nil
            }

            return text
        } catch let error as URLError where error.code == .timedOut {
            lastError = "Таймаут запроса к Gemini"
            return nil
        } catch let error as URLError where error.code == .notConnectedToInternet {
            lastError = "Нет подключения к интернету"
            return nil
        } catch {
            lastError = "Ошибка сети: \(error.localizedDescription)"
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
