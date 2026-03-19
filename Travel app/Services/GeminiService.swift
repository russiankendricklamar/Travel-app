import Foundation

@MainActor
@Observable
final class GeminiService {
    static let shared = GeminiService()

    private let model = "gemini-2.5-flash"

    var isLoading = false
    var lastError: String?

    var hasApiKey: Bool { true }

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

        let promptPreview = String(prompt.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        print("[GeminiService] 📤 Request: \"\(promptPreview)...\" (\(prompt.count) chars)")

        for attempt in 1...3 {
            do {
                let startTime = CFAbsoluteTimeGetCurrent()
                let data = try await SupabaseProxy.request(
                    service: "gemini",
                    params: [
                        "prompt": prompt,
                        "model": model,
                        "temperature": "0.7",
                        "maxOutputTokens": "8192"
                    ]
                )
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime

                guard let text = Self.parseGeminiResponse(data) else {
                    lastError = Self.detectGeminiError(data) ?? "Неожиданный формат ответа Gemini"
                    print("[GeminiService] ❌ Parse failed after \(String(format: "%.1f", elapsed))s: \(lastError ?? "")")
                    let preview = String(data: data.prefix(300), encoding: .utf8) ?? ""
                    print("[GeminiService] Response preview: \(preview)")
                    return nil
                }

                print("[GeminiService] ✅ Response in \(String(format: "%.1f", elapsed))s, \(text.count) chars")
                return text
            } catch {
                let msg = "\(error)"
                if msg.contains("429") && attempt < 3 {
                    let delay = attempt * 10
                    print("[GeminiService] ⏳ 429 rate limited, retrying in \(delay)s (attempt \(attempt)/3)...")
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                let desc = error.localizedDescription
                if desc.contains("timed out") || desc.contains("Timed out") {
                    lastError = "Таймаут запроса к Gemini"
                } else if desc.contains("not connected") || desc.contains("offline") {
                    lastError = "Нет подключения к интернету"
                } else if msg.contains("429") {
                    lastError = "Лимит запросов AI исчерпан. Подождите минуту"
                } else {
                    lastError = "Ошибка Gemini: \(desc)"
                }
                print("[GeminiService] ❌ Request failed (attempt \(attempt)/3): \(msg)")
                return nil
            }
        }

        return nil
    }

    // MARK: - Private

    private func request(prompt: String, source: String) async -> PlaceInfo? {
        guard hasApiKey else { return nil }
        isLoading = true
        defer { isLoading = false }

        guard let text = await rawRequest(prompt: prompt) else { return nil }
        return parseResponse(text, source: source)
    }

    /// Parse Gemini response: single JSON object (non-streaming)
    private static func parseGeminiResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            return nil
        }
        return text
    }

    private static func detectGeminiError(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let candidates = json["candidates"] as? [[String: Any]],
           let reason = candidates.first?["finishReason"] as? String,
           reason == "SAFETY" {
            return "Ответ заблокирован фильтром безопасности"
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return "Gemini API: \(message)"
        }
        return nil
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
