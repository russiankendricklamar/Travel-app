import Foundation
import CoreLocation

struct TransportOption: Identifiable {
    let id = UUID()
    let type: TransportType
    let route: String       // конкретный маршрут: "Метро M1 до Aeroport, пересадка на M2..."
    let duration: String
    let priceRange: String  // диапазон: "60–100₽" или "по счётчику"
    let departureTime: String
    let steps: [String]     // пошаговые инструкции

    enum TransportType: String {
        case taxi = "Такси"
        case metro = "Метро"
        case bus = "Автобус"
        case train = "Аэроэкспресс"
        case shuttle = "Шаттл"
        case transfer = "Трансфер"

        var icon: String {
            switch self {
            case .taxi: return "car.fill"
            case .metro: return "tram.fill"
            case .bus: return "bus.fill"
            case .train: return "train.side.front.car"
            case .shuttle: return "minibus"
            case .transfer: return "arrow.triangle.swap"
            }
        }
    }
}

struct AirportTransportRecommendation {
    let options: [TransportOption]
    let tip: String
    let recommended: Int  // индекс лучшего варианта
}

@MainActor
final class FlightAIService {
    static let shared = FlightAIService()
    private init() {}

    private static let cacheVersion = 5
    private var cache: [String: AirportTransportRecommendation] = [:]

    func clearCache(for flightID: UUID) {
        let key = cacheKey(for: flightID)
        cache.removeValue(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func cacheKey(for flightID: UUID) -> String {
        "flightAI_v\(Self.cacheVersion)_\(flightID.uuidString)"
    }

    func generateRecommendation(
        originName: String,
        originAddress: String,
        originCoordinate: CLLocationCoordinate2D?,
        airportName: String,
        airportIata: String,
        departureTime: Date,
        cityName: String,
        flightID: UUID
    ) async -> AirportTransportRecommendation? {
        print("[FlightAIService] 🛫 Generating transport to \(airportIata) from '\(originName)' in \(cityName)")
        let key = cacheKey(for: flightID)

        if let cached = cache[key] {
            print("[FlightAIService] ✅ Memory cache hit: \(cached.options.count) options")
            return cached
        }

        if let data = UserDefaults.standard.data(forKey: key),
           let cached = try? JSONDecoder().decode(CachedRecommendation.self, from: data) {
            let result = cached.toRecommendation()
            cache[key] = result
            print("[FlightAIService] ✅ Disk cache hit: \(result.options.count) options")
            return result
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: departureTime)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "ru_RU")
        let dateStr = dateFormatter.string(from: departureTime)

        let currency = currencyForCity(cityName)

        // Координаты для точности
        var coordStr = ""
        if let c = originCoordinate {
            coordStr = " (координаты: \(String(format: "%.5f", c.latitude)), \(String(format: "%.5f", c.longitude)))"
        }
        var airportCoordStr = ""
        if let ac = FlightData.coordinate(forIata: airportIata) {
            airportCoordStr = " (координаты: \(String(format: "%.5f", ac.latitude)), \(String(format: "%.5f", ac.longitude)))"
        }

        let transportContext = transportContextForCity(cityName, airportIata: airportIata)

        let profileCtx = AIPromptHelper.profileContext()

        let prompt = """
        Построй маршруты от точки отправления до аэропорта.

        === ИСХОДНЫЕ ДАННЫЕ ===
        ОТКУДА: \(originName), \(originAddress)\(coordStr)
        ГОРОД: \(cityName)
        АЭРОПОРТ: \(airportName) (\(airportIata))\(airportCoordStr)
        ДАТА ВЫЛЕТА: \(dateStr) в \(timeStr)
        ПРИБЫТЬ В АЭРОПОРТ: не позднее \(arrivalTimeStr(departureTime))
        ВАЛЮТА: \(currency)
        \(transportContext)
        \(profileCtx)

        === ПРАВИЛА ===
        1. НЕ ВЫДУМЫВАЙ названия станций метро, номера автобусов, линии. Если не уверен — пиши "ближайшая станция метро" без конкретного названия.
        2. Все маршруты ВНУТРИ города \(cityName). Без междугородних переездов.
        3. Время в пути — реалистичное. Метро: 30-90 мин. Такси: 20-90 мин. Не пиши < 20 мин если расстояние > 10 км.
        4. Цены — актуальные для \(cityName) в \(currency). Метро: разовый билет. Такси: оценка по расстоянию.
        5. Первый шаг КАЖДОГО маршрута — как добраться от точки отправления до первой станции/остановки (пешком N минут).
        6. Каждый вариант — УНИКАЛЬНЫЙ тип транспорта или принципиально другой маршрут.

        === ФОРМАТ ОТВЕТА ===
        Дай 2-4 варианта. Каждый строго в формате:

        ТИП|МАРШРУТ|ВРЕМЯ|ЦЕНА|ВЫЕЗД
        ШАГИ: шаг1; шаг2; шаг3
        ---

        Где:
        - ТИП: одно из ТАКСИ, МЕТРО, АВТОБУС, АЭРОЭКСПРЕСС, ШАТТЛ, ТРАНСФЕР
        - МАРШРУТ: конкретный путь (названия станций, линий, номера маршрутов)
        - ВРЕМЯ: общее время от двери до аэропорта ("~45 мин" или "1 ч 20 мин")
        - ЦЕНА: сумма в \(currency) ("~500₽" или "2000-3000₽")
        - ВЫЕЗД: во сколько выехать ("выехать в HH:MM")
        - ШАГИ: пошаговые инструкции через точку с запятой

        После всех вариантов:
        ЛУЧШИЙ: номер самого быстрого варианта (1, 2, 3 или 4)
        СОВЕТ: один практический совет для этого аэропорта

        Отвечай ТОЛЬКО в этом формате. Без markdown, без заголовков, без нумерации вариантов.
        """

        print("[FlightAIService] 📤 Sending prompt to Gemini (\(prompt.count) chars)...")
        guard let text = await GeminiService.shared.rawRequest(prompt: prompt) else {
            print("[FlightAIService] ❌ Gemini returned nil")
            return nil
        }
        print("[FlightAIService] 📥 AI response: \(text.count) chars")
        let result = parseResponse(text)
        print("[FlightAIService] ✅ Parsed \(result.options.count) transport options, recommended=#\(result.recommended + 1)")
        for (i, opt) in result.options.enumerated() {
            print("[FlightAIService]   \(i + 1). \(opt.type.rawValue): \(opt.duration), \(opt.priceRange)")
        }

        cache[key] = result
        if let encoded = try? JSONEncoder().encode(CachedRecommendation(from: result)) {
            UserDefaults.standard.set(encoded, forKey: key)
        }

        return result
    }

    // MARK: - Helpers

    private func arrivalTimeStr(_ departure: Date) -> String {
        let arrival = departure.addingTimeInterval(-2.5 * 3600) // за 2.5 часа
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: arrival)
    }

    /// Контекст о транспорте конкретного города — реальные данные чтобы AI не галлюцинировал
    private func transportContextForCity(_ city: String, airportIata: String) -> String {
        let lower = city.lowercased()
        if lower.contains("москва") {
            let airportInfo: String
            switch airportIata {
            case "SVO": airportInfo = "До SVO: Аэроэкспресс с Белорусского вокзала (ст. м. Белорусская, 500₽, 35 мин). Или такси через М11."
            case "DME": airportInfo = "До DME: Аэроэкспресс с Павелецкого вокзала (ст. м. Павелецкая, 500₽, 45 мин). Или такси по М4."
            case "VKO": airportInfo = "До VKO: Аэроэкспресс с Киевского вокзала (ст. м. Киевская, 500₽, 35 мин). Или такси по Киевскому шоссе."
            case "ZIA": airportInfo = "До ZIA: только такси или автобус от ст. Отдых (электричка с Казанского вокзала). Аэроэкспресса нет."
            default: airportInfo = ""
            }
            return """

            === ТРАНСПОРТ МОСКВЫ ===
            Метро: линии М1-М15, БКЛ, МЦК, МЦД. Разовый билет ~61₽. Работает 05:30–01:00.
            \(airportInfo)
            Такси: Яндекс Go, Uber. Средняя цена до аэропорта 2000–5000₽ в зависимости от расстояния и пробок.
            Автобусы/маршрутки: ходят к SVO (851, 817), DME (308), VKO (611). Цена ~61₽.
            """
        }
        if lower.contains("санкт-петербург") {
            return """

            === ТРАНСПОРТ САНКТ-ПЕТЕРБУРГА ===
            Метро: 5 линий (М1-М5). Жетон ~70₽. Работает 05:30–00:30.
            До LED (Пулково): метро до Московской (М2), далее автобус 39 или 39Э (~50 мин). Или такси (~1000–2500₽, 30–60 мин).
            Аэроэкспресса НЕТ.
            """
        }
        if lower.contains("стамбул") {
            let airportInfo = airportIata == "IST"
                ? "До IST: метро M11 Gayrettepe→Аэропорт (40 мин, 90₺). Или Havaist автобус. Такси ~400–700₺."
                : "До SAW: Havabus от Taksim/Kadıköy (~90 мин, 180₺). Или такси ~300–600₺."
            return """

            === ТРАНСПОРТ СТАМБУЛА ===
            Метро: M1–M11, трамвай T1. Istanbulkart: ~20₺ за поездку.
            \(airportInfo)
            """
        }
        if lower.contains("токио") || lower.contains("осака") {
            let airportInfo: String
            switch airportIata {
            case "NRT": airportInfo = "До NRT: Narita Express (N'EX) от Tokyo Station (~60 мин, 3250¥). Или Skyliner от Ueno (~40 мин, 2520¥). Лимузин-бас ~3200¥."
            case "HND": airportInfo = "До HND: Tokyo Monorail от Hamamatsucho (~15 мин, 500¥). Или Keikyu Line от Shinagawa (~20 мин, 300¥)."
            case "KIX": airportInfo = "До KIX: Haruka Express от Tennoji/Shin-Osaka (~50 мин, 1800–3430¥). Nankai Rapi:t от Namba (~40 мин, 1450¥)."
            default: airportInfo = ""
            }
            return """

            === ТРАНСПОРТ ЯПОНИИ ===
            Метро/JR: IC-карта (Suica/ICOCA) ~200–500¥ за поездку. Работает 05:00–00:30.
            \(airportInfo)
            Такси: очень дорого (~20000–30000¥ до аэропорта). Не рекомендуется.
            """
        }
        if lower.contains("дубай") || lower.contains("абу-даби") {
            return """

            === ТРАНСПОРТ ОАЭ ===
            Дубай метро: Red/Green Line. NOL-карта ~6–8 AED за поездку. До DXB: Red Line ст. Airport Terminal 1/3.
            Такси: RTA такси, Careem. До аэропорта ~50–150 AED.
            """
        }
        if lower.contains("бангкок") {
            return """

            === ТРАНСПОРТ БАНГКОКА ===
            BTS Skytrain + MRT метро: ~20–60฿. Airport Rail Link до BKK Suvarnabhumi от Phaya Thai (~30 мин, 45฿).
            До DMK: автобус A1/A2 от BTS Mo Chit (~30 мин, 30฿). Такси ~200–400฿.
            """
        }
        if lower.contains("сеул") {
            return """

            === ТРАНСПОРТ СЕУЛА ===
            Метро: 23 линии. T-money карта ~1350₩ за поездку.
            До ICN: AREX Express от Seoul Station (~43 мин, 9500₩). Обычный AREX ~4750₩ (~58 мин). Лимузин-бас ~17000₩.
            """
        }
        // Для неизвестных городов — минимальный контекст
        return """

        === ВАЖНО ===
        Если не знаешь точных маршрутов общественного транспорта в \(city) — предложи ТОЛЬКО такси и общее описание (автобус/поезд до аэропорта без конкретных номеров).
        НЕ ВЫДУМЫВАЙ номера маршрутов и названия станций которых не знаешь наверняка.
        """
    }

    // MARK: - Currency for city

    private func currencyForCity(_ city: String) -> String {
        let lower = city.lowercased()
        if ["москва", "санкт-петербург", "сочи", "казань", "екатеринбург", "новосибирск"].contains(where: { lower.contains($0) }) { return "₽" }
        if ["стамбул", "анталья", "бодрум", "даламан", "измир"].contains(where: { lower.contains($0) }) { return "TRY (₺)" }
        if ["дубай", "абу-даби"].contains(where: { lower.contains($0) }) { return "AED" }
        if ["бангкок", "пхукет"].contains(where: { lower.contains($0) }) { return "THB (฿)" }
        if ["токио", "осака", "киото"].contains(where: { lower.contains($0) }) { return "JPY (¥)" }
        if ["сеул"].contains(where: { lower.contains($0) }) { return "KRW (₩)" }
        if ["пекин", "шанхай"].contains(where: { lower.contains($0) }) { return "CNY (¥)" }
        if ["париж", "рим", "барселона", "мадрид", "берлин", "амстердам", "вена", "прага"].contains(where: { lower.contains($0) }) { return "EUR (€)" }
        if ["лондон"].contains(where: { lower.contains($0) }) { return "GBP (£)" }
        if ["нью-йорк", "лос-анджелес", "майами", "чикаго"].contains(where: { lower.contains($0) }) { return "USD ($)" }
        if ["ташкент", "самарканд"].contains(where: { lower.contains($0) }) { return "UZS (сум)" }
        if ["алматы", "астана"].contains(where: { lower.contains($0) }) { return "KZT (₸)" }
        if ["тбилиси", "батуми"].contains(where: { lower.contains($0) }) { return "GEL (₾)" }
        if ["ереван"].contains(where: { lower.contains($0) }) { return "AMD (֏)" }
        if ["баку"].contains(where: { lower.contains($0) }) { return "AZN (₼)" }
        return "в местной валюте"
    }

    // MARK: - Parse

    private func parseResponse(_ text: String) -> AirportTransportRecommendation {
        var options: [TransportOption] = []
        var tip = ""
        var recommended = 0
        var pendingSteps: [String]? = nil
        var pendingOption: (type: TransportOption.TransportType, route: String, duration: String, price: String, departure: String)? = nil

        func flushPending() {
            guard let opt = pendingOption else { return }
            options.append(TransportOption(
                type: opt.type,
                route: opt.route,
                duration: opt.duration,
                priceRange: opt.price,
                departureTime: opt.departure,
                steps: pendingSteps ?? []
            ))
            pendingOption = nil
            pendingSteps = nil
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed != "---" else {
                if trimmed == "---" { flushPending() }
                continue
            }

            if trimmed.uppercased().hasPrefix("ЛУЧШИЙ:") {
                let numStr = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                if let num = Int(numStr.prefix(while: \.isNumber)), num > 0 {
                    recommended = num - 1
                }
                continue
            }

            if trimmed.hasPrefix("СОВЕТ:") || trimmed.hasPrefix("совет:") {
                tip = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.uppercased().hasPrefix("ШАГИ:") || trimmed.uppercased().hasPrefix("ШАГИ :") {
                let stepsStr = String(trimmed.drop(while: { $0 != ":" }).dropFirst()).trimmingCharacters(in: .whitespaces)
                pendingSteps = stepsStr.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                continue
            }

            let parts = trimmed.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 5 else { continue }

            flushPending()

            let typeStr = parts[0].uppercased()
            let type: TransportOption.TransportType
            switch typeStr {
            case "ТАКСИ": type = .taxi
            case "МЕТРО": type = .metro
            case "АВТОБУС": type = .bus
            case "АЭРОЭКСПРЕСС": type = .train
            case "ШАТТЛ": type = .shuttle
            case "ТРАНСФЕР": type = .transfer
            default: type = .taxi
            }

            pendingOption = (type: type, route: parts[1], duration: parts[2], price: parts[3], departure: parts[4])
        }

        flushPending()

        if options.isEmpty {
            options.append(TransportOption(
                type: .taxi,
                route: "По навигатору",
                duration: "уточняйте",
                priceRange: "по счётчику",
                departureTime: "за 3 часа до вылета",
                steps: ["Закажите такси через приложение", "Укажите терминал вылета"]
            ))
        }

        // Дедупликация: убираем варианты с одинаковым типом и похожим маршрутом
        var unique: [TransportOption] = []
        for option in options {
            let dominated = unique.contains { existing in
                existing.type == option.type &&
                routeSimilarity(existing.route, option.route) > 0.6
            }
            if !dominated { unique.append(option) }
        }
        options = unique

        // Определяем лучший вариант по минимальному времени (парсим минуты из duration)
        let fastest = options.enumerated().min { a, b in
            parseDurationMinutes(a.element.duration) < parseDurationMinutes(b.element.duration)
        }?.offset ?? recommended

        return AirportTransportRecommendation(
            options: options,
            tip: tip,
            recommended: min(fastest, options.count - 1)
        )
    }

    /// Извлекает минуты из строки вида "~80 мин", "40–70 мин", "1 ч 20 мин"
    private func parseDurationMinutes(_ str: String) -> Int {
        let s = str.lowercased()
        // "1 ч 20 мин" / "1ч 20мин"
        let hPattern = try? NSRegularExpression(pattern: #"(\d+)\s*ч"#)
        let mPattern = try? NSRegularExpression(pattern: #"(\d+)\s*мин"#)
        let range = NSRange(s.startIndex..., in: s)

        var total = 0
        if let hMatch = hPattern?.firstMatch(in: s, range: range),
           let hRange = Range(hMatch.range(at: 1), in: s) {
            total += (Int(s[hRange]) ?? 0) * 60
        }
        if let mMatch = mPattern?.firstMatch(in: s, range: range),
           let mRange = Range(mMatch.range(at: 1), in: s) {
            total += Int(s[mRange]) ?? 0
        }
        if total > 0 { return total }

        // Фоллбэк: первое число в строке ("~80", "40–70" → берём первое)
        let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }.first
        return digits ?? 999
    }

    /// Простое сравнение маршрутов по общим словам (Jaccard)
    private func routeSimilarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 })
        let wordsB = Set(b.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 })
        guard !wordsA.isEmpty || !wordsB.isEmpty else { return 0 }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return Double(intersection) / Double(union)
    }
}

// MARK: - Cached model for UserDefaults persistence

private struct CachedRecommendation: Codable {
    let options: [CachedOption]
    let tip: String
    let recommended: Int

    struct CachedOption: Codable {
        let type: String
        let route: String
        let duration: String
        let priceRange: String
        let departureTime: String
        let steps: [String]
    }

    init(from rec: AirportTransportRecommendation) {
        self.options = rec.options.map {
            CachedOption(type: $0.type.rawValue, route: $0.route, duration: $0.duration, priceRange: $0.priceRange, departureTime: $0.departureTime, steps: $0.steps)
        }
        self.tip = rec.tip
        self.recommended = rec.recommended
    }

    func toRecommendation() -> AirportTransportRecommendation {
        let opts = options.map { cached -> TransportOption in
            let type: TransportOption.TransportType
            switch cached.type {
            case "Такси": type = .taxi
            case "Метро": type = .metro
            case "Автобус": type = .bus
            case "Аэроэкспресс": type = .train
            case "Шаттл": type = .shuttle
            case "Трансфер": type = .transfer
            default: type = .taxi
            }
            return TransportOption(type: type, route: cached.route, duration: cached.duration, priceRange: cached.priceRange, departureTime: cached.departureTime, steps: cached.steps)
        }
        return AirportTransportRecommendation(options: opts, tip: tip, recommended: recommended)
    }
}
