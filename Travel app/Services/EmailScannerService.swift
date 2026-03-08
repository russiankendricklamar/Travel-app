import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
@Observable
final class EmailScannerService {
    static let shared = EmailScannerService()
    private let contextProvider = EmailAuthContextProvider()
    private init() {}

    enum Provider: String, CaseIterable {
        case gmail, yandex

        var label: String {
            switch self {
            case .gmail: return "Gmail"
            case .yandex: return "Яндекс"
            }
        }

        var icon: String { "envelope.fill" }

        var color: Color {
            switch self {
            case .gmail: return .red
            case .yandex: return .yellow
            }
        }
    }

    enum ScanState: Equatable {
        case idle, authorizing, searching, selectEmails, parsing, results, error(String)

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.authorizing, .authorizing),
                 (.searching, .searching), (.selectEmails, .selectEmails),
                 (.parsing, .parsing), (.results, .results):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default: return false
            }
        }
    }

    var state: ScanState = .idle
    var foundEmails: [EmailPreview] = []
    var scannedBookings: [ScannedBooking] = []

    private static let oauthCallbackScheme = "travelapp"
    private static let tokenExchangeURL = "\(Secrets.supabaseURL)/functions/v1/email-token-exchange"
    private static let emailScannerURL = "\(Secrets.supabaseURL)/functions/v1/email-scanner"

    // MARK: - Full Flow

    func scan(provider: Provider) async {
        state = .authorizing
        do {
            let authCode = try await authorize(provider: provider)
            let accessToken = try await exchangeToken(provider: provider, code: authCode)
            state = .searching
            foundEmails = try await fetchEmails(provider: provider, token: accessToken)
            if foundEmails.isEmpty {
                state = .error("Письма с бронированиями не найдены")
                return
            }
            state = .selectEmails
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func parseSelectedEmails() async {
        let selected = foundEmails.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        state = .parsing
        do {
            scannedBookings = try await parseEmails(selected)
            state = scannedBookings.isEmpty ? .error("Не удалось распознать бронирования") : .results
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        foundEmails = []
        scannedBookings = []
    }

    // MARK: - OAuth

    private func authorize(provider: Provider) async throws -> String {
        let authURL: URL
        let scheme = Self.oauthCallbackScheme

        switch provider {
        case .gmail:
            let clientID = Secrets.googleClientID
            guard !clientID.isEmpty else { throw EmailScanError.missingClientID }
            let redirect = "\(scheme)://gmail-callback"
            let scope = "https://www.googleapis.com/auth/gmail.readonly"
            authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirect)&response_type=code&scope=\(scope)&access_type=offline&prompt=consent")!
        case .yandex:
            let clientID = Secrets.yandexClientID
            guard !clientID.isEmpty else { throw EmailScanError.missingClientID }
            let redirect = "\(scheme)://yandex-mail-callback"
            authURL = URL(string: "https://oauth.yandex.ru/authorize?response_type=code&client_id=\(clientID)&redirect_uri=\(redirect)&scope=mail:imap_full&force_confirm=yes")!
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { url, error in
                if let error { continuation.resume(throwing: error); return }
                guard let url else { continuation.resume(throwing: EmailScanError.authFailed); return }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self.contextProvider
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw EmailScanError.authFailed
        }
        return code
    }

    // MARK: - Token Exchange

    private func exchangeToken(provider: Provider, code: String) async throws -> String {
        guard let url = URL(string: Self.tokenExchangeURL) else { throw EmailScanError.badURL }

        let redirectURI: String
        switch provider {
        case .gmail: redirectURI = "\(Self.oauthCallbackScheme)://gmail-callback"
        case .yandex: redirectURI = "\(Self.oauthCallbackScheme)://yandex-mail-callback"
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15

        let body: [String: String] = ["provider": provider.rawValue, "code": code, "redirect_uri": redirectURI]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw EmailScanError.tokenExchangeFailed(errBody ?? "Token exchange failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw EmailScanError.tokenExchangeFailed("No access_token in response")
        }
        return token
    }

    // MARK: - Fetch Emails

    private func fetchEmails(provider: Provider, token: String) async throws -> [EmailPreview] {
        guard let url = URL(string: Self.emailScannerURL) else { throw EmailScanError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let body: [String: Any] = ["provider": provider.rawValue, "access_token": token, "max_results": 20, "days_back": 90]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw EmailScanError.fetchFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["emails"] as? [[String: Any]] else { return [] }

        let rfcFmt = DateFormatter()
        rfcFmt.locale = Locale(identifier: "en_US_POSIX")
        rfcFmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        return arr.compactMap { e in
            guard let id = e["id"] as? String, let subject = e["subject"] as? String,
                  let bodyText = e["body_text"] as? String else { return nil }
            let from = e["from"] as? String ?? ""
            let dateStr = e["date"] as? String ?? ""
            let date = ISO8601DateFormatter().date(from: dateStr) ?? rfcFmt.date(from: dateStr) ?? Date()
            return EmailPreview(id: id, subject: subject, from: from, date: date, bodyText: bodyText)
        }
    }

    // MARK: - AI Parsing

    private func parseEmails(_ emails: [EmailPreview]) async throws -> [ScannedBooking] {
        var all: [ScannedBooking] = []
        for email in emails {
            let text = "Тема: \(email.subject)\nОт: \(email.from)\n\n\(email.bodyText)"
            let bookings = try await parseBookingText(text)
            all.append(contentsOf: bookings)
        }
        return all
    }

    private func parseBookingText(_ text: String) async throws -> [ScannedBooking] {
        let prompt = """
        Извлеки ВСЕ бронирования из письма. Только JSON массив:
        [{"type":"flight|hotel|train|car_rental|bus|transfer",
          "title":"SU260","subtitle":"SVO → NRT",
          "date":"2026-04-15T10:30","endDate":"2026-04-20T12:00",
          "confirmationCode":"ABC123","price":15000,"currency":"RUB",
          "departureIata":"SVO","arrivalIata":"NRT","flightNumber":"SU260",
          "hotelName":"Novotel","address":"ул. Ленина 5",
          "trainNumber":"020А","seatInfo":"Вагон 5, место 23"}]
        Только заполненные поля. Если бронирований нет — [].

        Текст письма:
        \(text.prefix(4000))
        """

        guard let raw = await GeminiService.shared.rawRequest(prompt: prompt) else {
            throw EmailScanError.aiUnavailable
        }
        return parseBookingJSON(raw)
    }

    private func parseBookingJSON(_ raw: String) -> [ScannedBooking] {
        let cleaned = raw.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = cleaned.firstIndex(of: "["), let end = cleaned.lastIndex(of: "]") else { return [] }
        let jsonString = String(cleaned[start...end])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let fallbackFmt = DateFormatter()
        fallbackFmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fallbackFmt.locale = Locale(identifier: "en_US_POSIX")

        return array.compactMap { dict -> ScannedBooking? in
            guard let typeStr = dict["type"] as? String, let type = BookingType(rawValue: typeStr),
                  let title = dict["title"] as? String else { return nil }
            func parseDate(_ key: String) -> Date? {
                guard let str = dict[key] as? String, !str.isEmpty else { return nil }
                return isoFmt.date(from: str) ?? fallbackFmt.date(from: str)
            }
            return ScannedBooking(type: type, title: title, subtitle: dict["subtitle"] as? String,
                date: parseDate("date"), endDate: parseDate("endDate"),
                confirmationCode: dict["confirmationCode"] as? String,
                price: dict["price"] as? Double, currency: dict["currency"] as? String,
                departureIata: (dict["departureIata"] as? String)?.uppercased(),
                arrivalIata: (dict["arrivalIata"] as? String)?.uppercased(),
                flightNumber: (dict["flightNumber"] as? String)?.uppercased(),
                hotelName: dict["hotelName"] as? String, address: dict["address"] as? String,
                trainNumber: dict["trainNumber"] as? String, seatInfo: dict["seatInfo"] as? String)
        }
    }

    // MARK: - Errors

    enum EmailScanError: LocalizedError {
        case missingClientID, authFailed, badURL
        case tokenExchangeFailed(String), fetchFailed(Int), aiUnavailable

        var errorDescription: String? {
            switch self {
            case .missingClientID: return "Client ID не настроен"
            case .authFailed: return "Не удалось авторизоваться"
            case .badURL: return "Некорректный URL"
            case .tokenExchangeFailed(let msg): return "Ошибка авторизации: \(msg)"
            case .fetchFailed(let code): return "Ошибка загрузки писем: HTTP \(code)"
            case .aiUnavailable: return "AI-провайдер недоступен"
            }
        }
    }
}

private class EmailAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return ASPresentationAnchor() }
        return window
    }
}
