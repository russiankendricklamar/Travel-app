import Foundation

@Observable
final class CurrencyService {
    static let shared = CurrencyService()

    static let supportedCurrencies = ["JPY", "USD", "RUB", "CNY"]
    static let symbols: [String: String] = [
        "JPY": "\u{00A5}",
        "USD": "$",
        "RUB": "\u{20BD}",
        "CNY": "\u{5143}"
    ]

    // API rates: how much 1 JPY costs in each currency
    var rates: [String: Double] = [:]
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    private var lastFetchDate: Date?
    private let cacheInterval: TimeInterval = 60 * 60 // 1 hour
    private let session: URLSession

    // Fallback rates (approximate, 1 JPY = X currency)
    private let fallbackRates: [String: Double] = [
        "USD": 0.0067,
        "RUB": 0.58,
        "CNY": 0.048
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
        rates = fallbackRates
    }

    // MARK: - Settings

    var useCustomRates: Bool {
        UserDefaults.standard.bool(forKey: "useCustomRates")
    }

    // Custom rates stored as "1 USD = X JPY"
    func customRateJPYPer(currency: String) -> Double {
        UserDefaults.standard.double(forKey: "customRate_\(currency)")
    }

    // MARK: - Active rates (custom or API)

    private var activeRates: [String: Double] {
        if useCustomRates {
            var custom: [String: Double] = [:]
            for code in ["USD", "RUB", "CNY"] {
                let jpyPer = customRateJPYPer(currency: code)
                if jpyPer > 0 {
                    custom[code] = 1.0 / jpyPer
                }
            }
            return custom.isEmpty ? rates : custom
        }
        return rates
    }

    // MARK: - Conversion

    /// Convert amount from one currency to another
    func convert(_ amount: Double, from: String, to: String) -> Double {
        if from == to { return amount }

        let currentRates = activeRates

        if from == "JPY" {
            // JPY -> other: multiply by rate
            let rate = currentRates[to] ?? 0
            return amount * rate
        } else if to == "JPY" {
            // other -> JPY: divide by rate
            let rate = currentRates[from] ?? 0
            guard rate > 0 else { return 0 }
            return amount / rate
        } else {
            // cross: from -> JPY -> to
            let rateFrom = currentRates[from] ?? 0
            guard rateFrom > 0 else { return 0 }
            let jpyAmount = amount / rateFrom
            let rateTo = currentRates[to] ?? 0
            return jpyAmount * rateTo
        }
    }

    /// Format amount with currency symbol
    func format(_ amount: Double, currency: String) -> String {
        let symbol = Self.symbols[currency] ?? currency
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = currency == "JPY" ? 0 : 2
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(symbol)\(formatted)"
    }

    /// Get rate: 1 unit of `currency` = X JPY
    func jpyPerUnit(of currency: String) -> Double {
        let currentRates = activeRates
        guard let rate = currentRates[currency], rate > 0 else { return 0 }
        return 1.0 / rate
    }

    // MARK: - Fetch

    func fetchRates() async {
        if let lastDate = lastFetchDate,
           Date().timeIntervalSince(lastDate) < cacheInterval {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let url = URL(string: "https://open.er-api.com/v6/latest/JPY")!
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            if let usd = decoded.rates["USD"] { rates["USD"] = usd }
            if let rub = decoded.rates["RUB"] { rates["RUB"] = rub }
            if let cny = decoded.rates["CNY"] { rates["CNY"] = cny }

            lastFetchDate = Date()
            lastUpdated = Date()
        } catch {
            errorMessage = "Не удалось загрузить курсы"
            // Keep fallback rates
        }

        isLoading = false
    }

    func invalidateCache() {
        lastFetchDate = nil
    }
}

// MARK: - API Response

private struct ExchangeRateResponse: Codable {
    let result: String
    let rates: [String: Double]
}
