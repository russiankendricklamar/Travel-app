import Foundation
import UIKit
import Vision
import PDFKit

// MARK: - Scanned Flight

struct ScannedFlight: Identifiable {
    let id = UUID()
    var number: String
    var date: Date?
    var departureIata: String?
    var arrivalIata: String?
}

// MARK: - Booking Scan Service

@MainActor
final class BookingScanService {
    static let shared = BookingScanService()
    private init() {}

    // MARK: - Scan Image (OCR + AI)

    func scanImage(_ image: UIImage) async throws -> [ScannedFlight] {
        print("[BookingScan] 📷 Scanning image (\(Int(image.size.width))x\(Int(image.size.height)))...")
        let text = try await recognizeText(from: image)
        print("[BookingScan] 📝 OCR result: \(text.count) chars")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[BookingScan] ❌ No text found in image")
            throw ScanError.noTextFound
        }
        return try await parseFlights(from: text)
    }

    // MARK: - Scan PDF (PDFKit + OCR + AI)

    func scanPDF(_ url: URL) async throws -> [ScannedFlight] {
        guard let document = PDFDocument(url: url) else {
            throw ScanError.invalidPDF
        }
        guard document.pageCount > 0 else {
            throw ScanError.noTextFound
        }

        // First try extracting text directly from PDF (works for digital PDFs)
        var directText = ""
        for i in 0..<min(document.pageCount, 10) {
            if let page = document.page(at: i), let pageText = page.string {
                directText += pageText + "\n"
            }
        }

        // If direct text extraction yielded useful content, use it
        let trimmedDirect = directText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDirect.count > 50 {
            return try await parseFlights(from: trimmedDirect)
        }

        // Fallback: render pages to images and OCR them (for scanned PDFs)
        var allText = ""
        let pageLimit = min(document.pageCount, 10)
        for i in 0..<pageLimit {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            if let pageText = try? await recognizeText(from: image) {
                allText += pageText + "\n"
            }
        }

        guard !allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScanError.noTextFound
        }
        return try await parseFlights(from: allText)
    }

    // MARK: - Scan Text (AI only)

    func scanText(_ text: String) async throws -> [ScannedFlight] {
        print("[BookingScan] 📝 Scanning text input (\(text.count) chars)...")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ScanError.emptyInput
        }
        return try await parseFlights(from: trimmed)
    }

    // MARK: - OCR via Vision

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
            request.recognitionLanguages = ["ru-RU", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - AI Flight Extraction

    private func parseFlights(from text: String) async throws -> [ScannedFlight] {
        print("[BookingScan] 🤖 Sending to Gemini for flight extraction (\(min(text.count, 4000)) chars)...")
        let prompt = """
        Извлеки все рейсы из текста. Только JSON:
        [{"number":"SU260","date":"2025-04-15T10:30","from":"SVO","to":"NRT"}]

        number — обязательно. date — ISO8601 без таймзоны. from/to — IATA коды. Если рейсов нет — [].

        Текст:
        \(text.prefix(4000))
        """

        guard let raw = await GeminiService.shared.rawRequest(prompt: prompt) else {
            print("[BookingScan] ❌ Gemini unavailable")
            throw ScanError.aiUnavailable
        }

        print("[BookingScan] 📥 AI response: \(raw.count) chars")
        let flights = parseJSON(raw)
        print("[BookingScan] ✅ Extracted \(flights.count) flights: \(flights.map(\.number).joined(separator: ", "))")
        return flights
    }

    // MARK: - JSON Parsing

    private func parseJSON(_ raw: String) -> [ScannedFlight] {
        // Extract JSON array from response (AI may wrap it in markdown code block)
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the JSON array bounds
        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else {
            return []
        }

        let jsonString = String(cleaned[start...end])
        guard let data = jsonString.data(using: .utf8) else { return [] }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        // Also try a simpler format without seconds
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")

        return array.compactMap { dict -> ScannedFlight? in
            guard let number = dict["number"] as? String, !number.isEmpty else { return nil }

            var date: Date?
            if let dateStr = dict["date"] as? String, !dateStr.isEmpty {
                date = isoFormatter.date(from: dateStr) ?? fallbackFormatter.date(from: dateStr)
            }

            let from = dict["from"] as? String
            let to = dict["to"] as? String

            return ScannedFlight(
                number: number.uppercased(),
                date: date,
                departureIata: from?.uppercased(),
                arrivalIata: to?.uppercased()
            )
        }
    }

    // MARK: - Errors

    enum ScanError: LocalizedError {
        case noTextFound
        case emptyInput
        case invalidImage
        case invalidPDF
        case aiUnavailable

        var errorDescription: String? {
            switch self {
            case .noTextFound: return "Текст на изображении не найден"
            case .emptyInput: return "Введите текст бронирования"
            case .invalidImage: return "Не удалось обработать изображение"
            case .invalidPDF: return "Не удалось открыть PDF-файл"
            case .aiUnavailable: return "AI-провайдер недоступен. Проверьте API-ключ в настройках"
            }
        }
    }
}
