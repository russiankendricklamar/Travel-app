import Foundation

@Observable
final class CurrencyService {
    static let shared = CurrencyService()

    static let supportedCurrencies = ["RUB", "JPY", "USD", "CNY", "EUR"]
    static let symbols: [String: String] = [
        "JPY": "\u{00A5}",
        "USD": "$",
        "RUB": "\u{20BD}",
        "CNY": "\u{5143}",
        "EUR": "\u{20AC}"
    ]

    /// The base currency used for storage and display
    var baseCurrency: String {
        UserDefaults.standard.string(forKey: "preferredCurrency") ?? "RUB"
    }

    /// SF Symbol name for the current base currency
    static var baseCurrencyIcon: String {
        switch shared.baseCurrency {
        case "RUB": return "rublesign"
        case "USD": return "dollarsign"
        case "JPY", "CNY": return "yensign"
        case "EUR": return "eurosign"
        default: return "banknote"
        }
    }

    /// Symbol character for the current base currency
    static var baseCurrencySymbol: String {
        symbols[shared.baseCurrency] ?? shared.baseCurrency
    }

    // API rates: how much 1 base costs in each currency
    var rates: [String: Double] = [:]
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    private var lastFetchDate: Date?
    private let cacheInterval: TimeInterval = 60 * 60 // 1 hour
    private let session: URLSession

    // Fallback rates per base currency (1 base = X target)
    private static let fallbackMatrix: [String: [String: Double]] = [
        "RUB": ["JPY": 1.7, "USD": 0.011, "CNY": 0.082, "EUR": 0.010],
        "USD": ["RUB": 88.0, "JPY": 150.0, "CNY": 7.2, "EUR": 0.92],
        "EUR": ["RUB": 95.0, "JPY": 163.0, "CNY": 7.8, "USD": 1.09],
        "JPY": ["RUB": 0.59, "USD": 0.0067, "CNY": 0.048, "EUR": 0.0061],
        "CNY": ["RUB": 12.2, "JPY": 20.8, "USD": 0.139, "EUR": 0.128],
    ]

    private var fallbackRates: [String: Double] {
        Self.fallbackMatrix[baseCurrency] ?? [:]
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
        rates = Self.fallbackMatrix["RUB"] ?? [:]
    }

    // MARK: - Settings

    var useCustomRates: Bool {
        UserDefaults.standard.bool(forKey: "useCustomRates")
    }

    // Custom rates stored as "1 currency = X baseCurrency"
    func customRateBasePerUnit(of currency: String) -> Double {
        UserDefaults.standard.double(forKey: "customRate_\(currency)")
    }

    // MARK: - Active rates (custom or API)

    private var activeRates: [String: Double] {
        if useCustomRates {
            var custom: [String: Double] = [:]
            for code in Self.supportedCurrencies where code != baseCurrency {
                let basePerUnit = customRateBasePerUnit(of: code)
                if basePerUnit > 0 {
                    custom[code] = 1.0 / basePerUnit
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

        let base = baseCurrency
        let currentRates = activeRates

        if from == base {
            let rate = currentRates[to] ?? 0
            return amount * rate
        } else if to == base {
            let rate = currentRates[from] ?? 0
            guard rate > 0 else { return 0 }
            return amount / rate
        } else {
            // cross: from -> base -> to
            let rateFrom = currentRates[from] ?? 0
            guard rateFrom > 0 else { return 0 }
            let baseAmount = amount / rateFrom
            let rateTo = currentRates[to] ?? 0
            return baseAmount * rateTo
        }
    }

    /// Format amount with currency symbol
    func format(_ amount: Double, currency: String) -> String {
        let symbol = Self.symbols[currency] ?? currency
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = (currency == "JPY" || currency == "RUB") ? 0 : 2
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(symbol)\(formatted)"
    }

    /// Convenience: format amount in base currency
    static func formatBase(_ amount: Double) -> String {
        shared.format(amount, currency: shared.baseCurrency)
    }

    /// Get rate: 1 unit of `currency` = X base
    func basePerUnit(of currency: String) -> Double {
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
            let url = URL(string: "https://open.er-api.com/v6/latest/\(baseCurrency)")!
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            for code in Self.supportedCurrencies where code != baseCurrency {
                if let rate = decoded.rates[code] {
                    rates[code] = rate
                }
            }

            lastFetchDate = Date()
            lastUpdated = Date()
        } catch {
            errorMessage = "Не удалось загрузить курсы"
            rates = fallbackRates
        }

        isLoading = false
    }

    func invalidateCache() {
        lastFetchDate = nil
        rates = fallbackRates
    }
}

// MARK: - API Response

private struct ExchangeRateResponse: Codable {
    let result: String
    let rates: [String: Double]
}
