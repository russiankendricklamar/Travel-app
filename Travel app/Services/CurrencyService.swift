import Foundation

@MainActor @Observable
final class CurrencyService {
    static let shared = CurrencyService()

    static let supportedCurrencies = ["RUB", "JPY", "USD", "CNY", "EUR"]
    static let symbols: [String: String] = [
        "JPY": "\u{00A5}",
        "USD": "$",
        "RUB": "\u{20BD}",
        "CNY": "\u{00A5}",
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

    // rates: 1 base = X target
    var rates: [String: Double] = [:]
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var isAutoRefreshActive = false

    private var lastFetchDate: Date?
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5 * 60

    // Fallback rates: 1 base = X target
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
        rates = Self.fallbackMatrix[baseCurrency] ?? Self.fallbackMatrix["RUB"] ?? [:]
    }

    // MARK: - Settings

    var useCustomRates: Bool {
        UserDefaults.standard.bool(forKey: "useCustomRates")
    }

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
            let rateFrom = currentRates[from] ?? 0
            guard rateFrom > 0 else { return 0 }
            let baseAmount = amount / rateFrom
            let rateTo = currentRates[to] ?? 0
            return baseAmount * rateTo
        }
    }

    func format(_ amount: Double, currency: String) -> String {
        let symbol = Self.symbols[currency] ?? currency
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let isWholeAmount = amount.truncatingRemainder(dividingBy: 1) == 0
        formatter.maximumFractionDigits = currency == "JPY" ? 0 : (isWholeAmount ? 0 : 2)
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(symbol)\(formatted)"
    }

    static func formatBase(_ amount: Double) -> String {
        shared.format(amount, currency: shared.baseCurrency)
    }

    /// Get rate: 1 unit of `currency` = X base
    func basePerUnit(of currency: String) -> Double {
        let currentRates = activeRates
        guard let rate = currentRates[currency], rate > 0 else { return 0 }
        return 1.0 / rate
    }

    // MARK: - Auto-Refresh

    func startAutoRefresh() {
        guard refreshTimer == nil else { return }
        isAutoRefreshActive = true

        Task { await fetchRates(force: false) }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchRates(force: true)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        isAutoRefreshActive = false
    }

    func handleScenePhase(active: Bool) {
        if active {
            if refreshTimer == nil {
                startAutoRefresh()
            } else {
                Task { await fetchRates(force: false) }
            }
        } else {
            stopAutoRefresh()
        }
    }

    // MARK: - Fetch (НКО НКЦ / MOEX via Edge Function)

    private var isFetching = false

    func fetchRates(force: Bool = false) async {
        if !force, let lastDate = lastFetchDate,
           Date().timeIntervalSince(lastDate) < refreshInterval {
            return
        }

        guard !isFetching else { return }
        isFetching = true
        isLoading = true
        errorMessage = nil

        let base = baseCurrency
        let targets = Self.supportedCurrencies.filter { $0 != base }

        do {
            let data = try await SupabaseProxy.request(
                service: "moex_rates",
                params: [
                    "base": base,
                    "targets": targets.joined(separator: ",")
                ]
            )

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ratesDict = json["rates"] as? [String: Double],
               !ratesDict.isEmpty {
                // MOEX НКЦ returns: 1 unit of target = X base
                // We store: 1 base = X target (inverted)
                for (code, basePerUnit) in ratesDict where basePerUnit > 0 {
                    rates[code] = 1.0 / basePerUnit
                }
                lastFetchDate = Date()
                lastUpdated = Date()
                errorMessage = nil
                print("[CurrencyService] MOEX НКЦ rates updated: \(ratesDict.mapValues { String(format: "%.4f", $0) })")
            } else {
                errorMessage = "Не удалось загрузить курсы НКЦ"
                if lastFetchDate == nil { rates = fallbackRates }
            }
        } catch {
            print("[CurrencyService] Fetch error: \(error)")
            errorMessage = "Ошибка загрузки курсов"
            if lastFetchDate == nil { rates = fallbackRates }
        }

        isLoading = false
        isFetching = false
    }

    func invalidateCache() {
        lastFetchDate = nil
    }

    // MARK: - Historical Rate

    private var historicalRateCache: [String: Double] = [:]

    func fetchHistoricalRate(from: String, to: String, date: Date) async -> Double? {
        let cacheKey = "\(from)_\(to)_\(ISO8601DateFormatter().string(from: date))"
        if let cached = historicalRateCache[cacheKey] { return cached }

        do {
            let data = try await SupabaseProxy.request(
                service: "moex_rates",
                params: ["from": from, "to": to, "amount": "1"]
            )

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rate = json["rate"] as? Double, rate > 0 {
                historicalRateCache[cacheKey] = rate
                return rate
            }
        } catch {
            print("[CurrencyService] Historical rate error: \(error)")
        }

        if let r = rates[from], r > 0 { return r }
        if let r = rates[to], r > 0 { return 1.0 / r }
        return nil
    }

    func convertWithRate(_ amount: Double, rate: Double) -> Double {
        amount * rate
    }
}
