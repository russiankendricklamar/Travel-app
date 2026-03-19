import Foundation
import UIKit
import Vision

struct ScannedExpense: Identifiable {
    let id = UUID()
    var title: String
    var amount: Double
    var currency: String
    var category: ExpenseCategory
    var date: Date
    var isSelected: Bool = true
}

@MainActor
final class ReceiptScanService {
    static let shared = ReceiptScanService()
    private init() {}

    func scanImage(_ image: UIImage) async throws -> [ScannedExpense] {
        let text = try await recognizeText(from: image)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScanError.noTextFound
        }
        return try await parseReceipt(from: text)
    }

    // MARK: - OCR

    private func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ScanError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ru-RU", "en-US", "ja-JP"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - AI Extraction

    private func parseReceipt(from text: String) async throws -> [ScannedExpense] {
        let baseCurrency = CurrencyService.shared.baseCurrency
        let prompt = """
        Извлеки расходы из чека/квитанции. Только JSON массив:
        [{"title":"Название товара или магазина","amount":1500.0,"currency":"RUB","category":"еда","date":"2025-04-15"}]

        Правила:
        - title: название магазина или краткое описание покупки
        - amount: итоговая сумма (ИТОГО, TOTAL). Если несколько позиций — верни итог одной строкой
        - currency: код валюты (RUB, USD, EUR, JPY, CNY). Определи по символам ₽/$/€/¥ или контексту
        - category: одна из: еда, транспорт, жильё, развлечения, шопинг, другое
        - date: дата в формате YYYY-MM-DD. Если нет на чеке — "\(ISO8601DateFormatter().string(from: Date()).prefix(10))"
        - Если на чеке несколько отдельных покупок (разные магазины) — верни несколько объектов
        - Базовая валюта пользователя: \(baseCurrency)
        - Если текст нечитаемый или не похож на чек — верни []

        Текст чека:
        \(text.prefix(4000))
        """

        guard let raw = await GeminiService.shared.rawRequest(prompt: prompt) else {
            throw ScanError.aiUnavailable
        }

        return parseJSON(raw)
    }

    private func parseJSON(_ raw: String) -> [ScannedExpense] {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else { return [] }

        let jsonString = String(cleaned[start...end])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        return array.compactMap { dict -> ScannedExpense? in
            guard let title = dict["title"] as? String, !title.isEmpty,
                  let amount = (dict["amount"] as? Double) ?? (dict["amount"] as? Int).map(Double.init) else {
                return nil
            }
            guard amount > 0 else { return nil }

            let currency = (dict["currency"] as? String)?.uppercased() ?? CurrencyService.shared.baseCurrency
            let categoryStr = (dict["category"] as? String)?.lowercased() ?? ""
            let category: ExpenseCategory = switch categoryStr {
            case "еда", "food": .food
            case "транспорт", "transport": .transport
            case "жильё", "accommodation", "hotel": .accommodation
            case "развлечения", "activities", "entertainment": .activities
            case "шопинг", "shopping": .shopping
            default: ExpenseCategory.guess(from: title)
            }

            let date: Date
            if let dateStr = dict["date"] as? String, let d = dateFormatter.date(from: dateStr) {
                date = d
            } else {
                date = Date()
            }

            return ScannedExpense(title: title, amount: amount, currency: currency, category: category, date: date)
        }
    }

    enum ScanError: LocalizedError {
        case noTextFound, invalidImage, aiUnavailable

        var errorDescription: String? {
            switch self {
            case .noTextFound: return "Текст на чеке не найден"
            case .invalidImage: return "Не удалось обработать изображение"
            case .aiUnavailable: return "AI недоступен"
            }
        }
    }
}
