import Foundation

// MARK: - Input/Output Models

struct WizardInput {
    let destination: String
    let originIata: String
    let startDate: Date
    let endDate: Date
    let budget: Double?
    let currency: String
    let styles: [TravelStyle]
}

enum TravelStyle: String, CaseIterable, Identifiable {
    case active = "active"
    case relaxed = "relaxed"
    case cultural = "cultural"
    case gastro = "gastro"
    case adventure = "adventure"
    case shopping = "shopping"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .active: "Активный"
        case .relaxed: "Расслабленный"
        case .cultural: "Культурный"
        case .gastro: "Гастро"
        case .adventure: "Приключения"
        case .shopping: "Шоппинг"
        }
    }
    var icon: String {
        switch self {
        case .active: "figure.run"
        case .relaxed: "sun.horizon.fill"
        case .cultural: "building.columns.fill"
        case .gastro: "fork.knife"
        case .adventure: "mountain.2.fill"
        case .shopping: "bag.fill"
        }
    }
}

struct GeneratedDay: Identifiable {
    let id = UUID()
    let dayNumber: Int
    let city: String
    var places: [GeneratedPlace]
}

struct GeneratedPlace: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
    let timeToSpend: String
    let description: String
}

struct AIGeneratedTrip {
    let destination: String
    let startDate: Date
    let endDate: Date
    var days: [GeneratedDay]
    var flights: [FlightOffer]
    var hotels: [HotelOffer]
    var totalEstimate: Double

    var totalDays: Int { days.count }
}

struct DestinationSuggestion: Identifiable {
    let id = UUID()
    let country: String
    let flag: String
    let description: String
    let estimatedCost: String
    let iataCode: String
    let bestFor: String
}

// MARK: - Service

@MainActor
@Observable
final class AITripGeneratorService {
    static let shared = AITripGeneratorService()
    private init() {}

    var isGenerating = false
    var generationPhase: String = ""
    var lastError: String?

    // MARK: - Suggest Destinations
    func suggestDestinations(
        dates: (start: Date, end: Date)?,
        budget: Double?,
        profileContext: String
    ) async -> [DestinationSuggestion] {
        let dateInfo: String
        if let dates {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            fmt.locale = Locale(identifier: "ru_RU")
            dateInfo = "Период: \(fmt.string(from: dates.start)) — \(fmt.string(from: dates.end))"
        } else {
            dateInfo = "Период: не определён"
        }

        let budgetInfo = budget.map { "Бюджет: \(Int($0)) руб" } ?? "Бюджет: не ограничен"

        // Get cheap flights for context
        let cheapFlights = await TravelpayoutsService.shared.cheapDestinations()
        let cheapContext = cheapFlights.prefix(10).map { "\($0.iata): \($0.price) руб" }.joined(separator: ", ")

        let prompt = """
        Предложи 5 направлений для путешествия.
        \(dateInfo)
        \(budgetInfo)
        Дешёвые билеты сейчас: \(cheapContext)

        \(profileContext)

        Ответь СТРОГО в JSON формате, без markdown:
        [{"country":"Турция","flag":"🇹🇷","description":"Краткое описание почему стоит ехать","estimatedCost":"~50000 руб","iataCode":"IST","bestFor":"пляж, культура"}]
        """

        guard let response = await GeminiService.shared.rawRequest(prompt: prompt) else { return [] }

        return parseDestinationSuggestions(response)
    }

    // MARK: - Generate Full Trip
    func generateTrip(input: WizardInput, profileContext: String) async -> AIGeneratedTrip? {
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let startStr = fmt.string(from: input.startDate)
        let endStr = fmt.string(from: input.endDate)
        let days = Calendar.current.dateComponents([.day], from: input.startDate, to: input.endDate).day ?? 1

        let stylesStr = input.styles.map(\.label).joined(separator: ", ")
        let budgetStr = input.budget.map { "\(Int($0)) \(input.currency)" } ?? "без ограничений"

        // Phase 1: AI generates itinerary
        generationPhase = "Планируем маршрут..."

        let prompt = """
        Составь подробный план путешествия.
        Направление: \(input.destination)
        Даты: \(startStr) — \(endStr) (\(days) дней)
        Бюджет: \(budgetStr)
        Стиль: \(stylesStr)

        \(profileContext)

        Ответь СТРОГО в JSON формате, без markdown:
        {
          "days": [
            {
              "dayNumber": 1,
              "city": "Название города",
              "places": [
                {
                  "name": "Название места",
                  "category": "attraction|restaurant|museum|park|shopping|beach|temple|viewpoint|cafe|market",
                  "latitude": 41.0082,
                  "longitude": 28.9784,
                  "timeToSpend": "2ч",
                  "description": "Краткое описание на 1-2 предложения"
                }
              ]
            }
          ],
          "suggestedFlights": [
            {"from": "\(input.originIata)", "to": "IST", "date": "\(startStr)"},
            {"from": "IST", "to": "\(input.originIata)", "date": "\(endStr)"}
          ],
          "cities": ["Istanbul"]
        }

        Правила:
        - 3-5 мест на день, разнообразные категории
        - Реалистичные координаты
        - Учитывай логистику: места в одном городе рядом друг с другом
        - Если несколько городов — логичный порядок переездов
        """

        guard let aiResponse = await GeminiService.shared.rawRequest(prompt: prompt) else {
            lastError = "AI не ответил"
            return nil
        }

        guard let parsed = parseAIResponse(aiResponse) else {
            lastError = "Не удалось распарсить ответ AI"
            return nil
        }

        // Phase 2: Search flights in parallel
        generationPhase = "Ищем билеты..."
        let flights = await searchFlightsForTrip(parsed: parsed, startStr: startStr, endStr: endStr, input: input)

        // Phase 3: Search hotels in parallel
        generationPhase = "Подбираем жильё..."
        let hotels = await searchHotelsForTrip(parsed: parsed, startStr: startStr, endStr: endStr)

        // Combine
        generationPhase = "Готово!"
        let flightTotal = flights.reduce(0) { $0 + $1.price }
        let hotelTotal = hotels.reduce(0) { $0 + Int($1.priceFrom) }
        let totalEstimate = Double(flightTotal + hotelTotal)

        return AIGeneratedTrip(
            destination: input.destination,
            startDate: input.startDate,
            endDate: input.endDate,
            days: parsed.days,
            flights: flights,
            hotels: hotels,
            totalEstimate: totalEstimate
        )
    }

    // MARK: - Season Hint
    func seasonHint(destination: String, month: String) async -> String? {
        let prompt = """
        Кратко (2 предложения) опиши погоду и сезон в \(destination) в \(month).
        Формат: "Температура X°C. Хорошее/плохое время для поездки потому что..."
        Без markdown, просто текст.
        """
        return await GeminiService.shared.rawRequest(prompt: prompt)
    }

    // MARK: - Private Helpers

    private func searchFlightsForTrip(parsed: ParsedAITrip, startStr: String, endStr: String, input: WizardInput) async -> [FlightOffer] {
        let suggestedFlights = parsed.suggestedFlights
        var allFlights: [FlightOffer] = []

        await withTaskGroup(of: [FlightOffer].self) { group in
            for flight in suggestedFlights {
                group.addTask {
                    await TravelpayoutsService.shared.searchFlights(
                        origin: flight.from,
                        destination: flight.to,
                        departureAt: flight.date,
                        limit: 3
                    )
                }
            }
            for await result in group {
                allFlights.append(contentsOf: result)
            }
        }

        return allFlights
    }

    private func searchHotelsForTrip(parsed: ParsedAITrip, startStr: String, endStr: String) async -> [HotelOffer] {
        let cities = parsed.cities
        var allHotels: [HotelOffer] = []

        await withTaskGroup(of: [HotelOffer].self) { group in
            for city in cities {
                group.addTask {
                    await TravelpayoutsService.shared.searchHotels(
                        location: city,
                        checkIn: startStr,
                        checkOut: endStr,
                        limit: 3
                    )
                }
            }
            for await result in group {
                allHotels.append(contentsOf: result)
            }
        }

        return allHotels
    }

    private struct ParsedAITrip {
        let days: [GeneratedDay]
        let suggestedFlights: [(from: String, to: String, date: String)]
        let cities: [String]
    }

    private func parseAIResponse(_ response: String) -> ParsedAITrip? {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else { return nil }
        let jsonStr = String(cleaned[start...end])

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daysArray = json["days"] as? [[String: Any]] else { return nil }

        var days: [GeneratedDay] = []
        for dayObj in daysArray {
            guard let dayNum = dayObj["dayNumber"] as? Int,
                  let city = dayObj["city"] as? String,
                  let placesArr = dayObj["places"] as? [[String: Any]] else { continue }

            let places = placesArr.compactMap { p -> GeneratedPlace? in
                guard let name = p["name"] as? String,
                      let cat = p["category"] as? String,
                      let lat = p["latitude"] as? Double,
                      let lng = p["longitude"] as? Double else { return nil }
                return GeneratedPlace(
                    name: name, category: cat,
                    latitude: lat, longitude: lng,
                    timeToSpend: p["timeToSpend"] as? String ?? "1ч",
                    description: p["description"] as? String ?? ""
                )
            }
            days.append(GeneratedDay(dayNumber: dayNum, city: city, places: places))
        }

        let suggestedFlights: [(from: String, to: String, date: String)] = (json["suggestedFlights"] as? [[String: String]] ?? []).compactMap { f in
            guard let from = f["from"], let to = f["to"], let date = f["date"] else { return nil }
            return (from: from, to: to, date: date)
        }

        let cities = json["cities"] as? [String] ?? Array(Set(days.map(\.city)))

        guard !days.isEmpty else { return nil }

        return ParsedAITrip(days: days, suggestedFlights: suggestedFlights, cities: cities)
    }

    private func parseDestinationSuggestions(_ response: String) -> [DestinationSuggestion] {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else { return [] }
        let jsonStr = String(cleaned[start...end])

        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return arr.compactMap { item in
            guard let country = item["country"] as? String,
                  let flag = item["flag"] as? String,
                  let desc = item["description"] as? String,
                  let cost = item["estimatedCost"] as? String,
                  let iata = item["iataCode"] as? String,
                  let bestFor = item["bestFor"] as? String else { return nil }
            return DestinationSuggestion(country: country, flag: flag, description: desc,
                                         estimatedCost: cost, iataCode: iata, bestFor: bestFor)
        }
    }
}
