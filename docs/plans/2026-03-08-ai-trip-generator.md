# AI Trip Generator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** AI-powered trip creation wizard — user picks destination/dates/budget/style, AI generates full itinerary with real flight/hotel prices from Travelpayouts.

**Architecture:** 4-step wizard (fullScreenCover) collects input → AITripGeneratorService orchestrates Gemini + Travelpayouts in parallel → preview screen shows editable days/flights/hotels → save converts to SwiftData models.

**Tech Stack:** SwiftUI, SwiftData, Gemini API (existing GeminiService), Travelpayouts Flights API, Hotellook Hotels API, MKLocalSearchCompleter, AIPromptHelper.

---

## Task 1: TravelpayoutsService — Flight Search

**Files:**
- Create: `Travel app/Services/TravelpayoutsService.swift`
- Modify: `Travel app/Config/Secrets.swift` (add travelpayoutsToken)

**Step 1: Add API key to Secrets.swift**

Add after the last API key pair (around line 43, after googlePlacesApiKey):

```swift
static var travelpayoutsToken: String {
    KeychainHelper.readString(key: "travelpayoutsToken") ?? infoPlistValue("TRAVELPAYOUTS_TOKEN")
}

static func setTravelpayoutsToken(_ key: String) {
    KeychainHelper.save(key: "travelpayoutsToken", string: key)
}
```

**Step 2: Create TravelpayoutsService.swift**

```swift
import Foundation

struct FlightOffer: Identifiable, Codable {
    var id: String { "\(origin)-\(destination)-\(departureAt)" }
    let origin: String
    let destination: String
    let departureAt: String
    let returnAt: String?
    let price: Int
    let airline: String
    let flightNumber: Int
    let transfers: Int
    let link: String

    var deepLink: String {
        "https://www.aviasales.ru\(link)"
    }
}

struct HotelOffer: Identifiable, Codable {
    var id: String { "\(hotelId)" }
    let hotelId: Int
    let hotelName: String
    let stars: Int
    let priceFrom: Double
    let pricePerNight: Double
    let locationName: String
    let link: String

    var deepLink: String {
        "https://search.hotellook.com/hotels?hotelId=\(hotelId)"
    }
}

@MainActor
@Observable
final class TravelpayoutsService {
    static let shared = TravelpayoutsService()
    private init() {}

    var lastError: String?

    // MARK: - Flights (Aviasales Prices API)
    func searchFlights(
        origin: String,
        destination: String,
        departureAt: String,
        returnAt: String? = nil,
        currency: String = "rub",
        limit: Int = 5
    ) async -> [FlightOffer] {
        lastError = nil
        let token = Secrets.travelpayoutsToken
        guard !token.isEmpty else {
            lastError = "Travelpayouts token not set"
            return []
        }

        var components = URLComponents(string: "https://api.travelpayouts.com/aviasales/v3/prices_for_dates")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "departure_at", value: departureAt),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "sorting", value: "price"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "unique", value: "false")
        ]
        if let returnAt { components.queryItems?.append(URLQueryItem(name: "return_at", value: returnAt)) }

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "HTTP error"
                return []
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataArray = json?["data"] as? [[String: Any]] else { return [] }

            return dataArray.prefix(limit).compactMap { item in
                guard let origin = item["origin"] as? String,
                      let dest = item["destination"] as? String,
                      let departure = item["departure_at"] as? String,
                      let price = item["price"] as? Int,
                      let airline = item["airline"] as? String,
                      let flightNum = item["flight_number"] as? Int,
                      let transfers = item["transfers"] as? Int,
                      let link = item["link"] as? String else { return nil }
                let returnDate = item["return_at"] as? String
                return FlightOffer(origin: origin, destination: dest, departureAt: departure,
                                   returnAt: returnDate, price: price, airline: airline,
                                   flightNumber: flightNum, transfers: transfers, link: link)
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    // MARK: - Hotels (Hotellook Cache API)
    func searchHotels(
        location: String,
        checkIn: String,
        checkOut: String,
        currency: String = "rub",
        limit: Int = 5
    ) async -> [HotelOffer] {
        lastError = nil
        let token = Secrets.travelpayoutsToken
        guard !token.isEmpty else {
            lastError = "Travelpayouts token not set"
            return []
        }

        var components = URLComponents(string: "https://engine.hotellook.com/api/v2/cache.json")!
        components.queryItems = [
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "checkIn", value: checkIn),
            URLQueryItem(name: "checkOut", value: checkOut),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "HTTP error"
                return []
            }

            let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            return items.prefix(limit).compactMap { item in
                guard let hotelId = item["hotelId"] as? Int,
                      let hotelName = item["hotelName"] as? String,
                      let stars = item["stars"] as? Int,
                      let priceFrom = item["priceFrom"] as? Double else { return nil }
                let locationName = item["location"] as? [String: Any]
                let locName = locationName?["name"] as? String ?? location
                let nights = max(1, Calendar.current.dateComponents([.day], from: ISO8601DateFormatter().date(from: checkIn + "T00:00:00Z") ?? Date(), to: ISO8601DateFormatter().date(from: checkOut + "T00:00:00Z") ?? Date()).day ?? 1)
                return HotelOffer(hotelId: hotelId, hotelName: hotelName, stars: stars,
                                  priceFrom: priceFrom, pricePerNight: priceFrom / Double(nights),
                                  locationName: locName,
                                  link: "https://search.hotellook.com/hotels?hotelId=\(hotelId)")
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    // MARK: - Cheap Destinations (for "suggest me")
    func cheapDestinations(
        origin: String = "MOW",
        currency: String = "rub"
    ) async -> [(iata: String, price: Int, destination: String)] {
        let token = Secrets.travelpayoutsToken
        guard !token.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.travelpayouts.com/aviasales/v3/get_latest_prices")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "period_type", value: "month"),
            URLQueryItem(name: "one_way", value: "false"),
            URLQueryItem(name: "sorting", value: "price"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataArray = json?["data"] as? [[String: Any]] else { return [] }

            return dataArray.compactMap { item in
                guard let dest = item["destination"] as? String,
                      let price = item["price"] as? Int else { return nil }
                let destName = item["destination"] as? String ?? dest
                return (iata: dest, price: price, destination: destName)
            }
        } catch {
            return []
        }
    }
}
```

**Step 3: Commit**

```bash
git add "Travel app/Services/TravelpayoutsService.swift" "Travel app/Config/Secrets.swift"
git commit -m "feat: add TravelpayoutsService — flights, hotels, cheap destinations API"
```

---

## Task 2: AITripGeneratorService — AI Orchestrator

**Files:**
- Create: `Travel app/Services/AITripGeneratorService.swift`

**Step 1: Create the service**

```swift
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
```

**Step 2: Commit**

```bash
git add "Travel app/Services/AITripGeneratorService.swift"
git commit -m "feat: add AITripGeneratorService — AI itinerary + Travelpayouts orchestrator"
```

---

## Task 3: Wizard Steps (4 views)

**Files:**
- Create: `Travel app/Views/AITripWizard/WizardStepDestination.swift`
- Create: `Travel app/Views/AITripWizard/WizardStepDates.swift`
- Create: `Travel app/Views/AITripWizard/WizardStepBudget.swift`
- Create: `Travel app/Views/AITripWizard/WizardStepStyle.swift`

Each step view receives `@Binding` props from the parent wizard. All use glassmorphism style (GlassFormField, GlassSectionHeader from existing Theme/GlassComponents.swift). All text in Russian.

**Step 1: Create WizardStepDestination.swift**

Key elements:
- `@Binding var destination: String`
- `@Binding var originIata: String`
- MKLocalSearchCompleter for autocomplete
- "Подскажи мне" button that calls `AITripGeneratorService.shared.suggestDestinations()`
- Shows suggestion cards (flag + country + description + price)
- Tap suggestion fills destination + iataCode
- `onNext: () -> Void` callback

**Step 2: Create WizardStepDates.swift**

Key elements:
- `@Binding var startDate: Date`
- `@Binding var endDate: Date`
- `let destination: String`
- DatePicker pair (start/end)
- AI season hint (async call to `AITripGeneratorService.shared.seasonHint()`)
- Days counter badge
- `onNext: () -> Void`

**Step 3: Create WizardStepBudget.swift**

Key elements:
- `@Binding var budget: Double?`
- Quick chips: Эконом (50000), Средний (150000), Без ограничений (nil)
- TextField for custom amount
- `onNext: () -> Void`

**Step 4: Create WizardStepStyle.swift**

Key elements:
- `@Binding var styles: [TravelStyle]`
- Grid of style chips (TravelStyle.allCases) with icon + label
- Multi-select (toggle on tap)
- "СГЕНЕРИРОВАТЬ ПОЕЗДКУ" button → `onGenerate: () -> Void`

**Step 5: Commit**

```bash
git add "Travel app/Views/AITripWizard/"
git commit -m "feat: add 4 wizard step views for AI trip generator"
```

---

## Task 4: AITripWizardView — Wizard Container

**Files:**
- Create: `Travel app/Views/AITripWizard/AITripWizardView.swift`
- Create: `Travel app/Views/AITripWizard/AITripLoadingView.swift`

**Step 1: Create AITripWizardView.swift**

Key elements:
- `@State private var step = 0` (0-3 for 4 steps)
- `@State` vars for all wizard inputs (destination, originIata, startDate, endDate, budget, styles)
- `@State private var generatedTrip: AIGeneratedTrip?`
- `@State private var isGenerating = false`
- `@Environment(\.dismiss) var dismiss`
- TabView with `.tabViewStyle(.page(indexDisplayMode: .never))` and `selection: $step`
- Custom step indicator (4 dots at top)
- Back button + progress
- When step 4 "generate" fires: call `AITripGeneratorService.shared.generateTrip()` → show loading → navigate to preview
- `.fullScreenCover(item: $generatedTrip)` → AITripPreviewView

**Step 2: Create AITripLoadingView.swift**

Key elements:
- `let phase: String` (from AITripGeneratorService.generationPhase)
- Animated phases: "Планируем маршрут..." → "Ищем билеты..." → "Подбираем жильё..."
- Glassmorphism card with pulse animation
- Plane/globe icon rotating

**Step 3: Commit**

```bash
git add "Travel app/Views/AITripWizard/"
git commit -m "feat: add AITripWizardView container + loading animation"
```

---

## Task 5: AITripPreviewView — Preview + Edit + Save

**Files:**
- Create: `Travel app/Views/AITripWizard/AITripPreviewView.swift`

**Step 1: Create AITripPreviewView.swift**

Key elements:
- `@State var trip: AIGeneratedTrip`
- `@Environment(\.modelContext) private var modelContext`
- `@Environment(\.dismiss) var dismiss`
- Header: destination + days count + total estimate
- Day sections (ForEach trip.days): city name + places list with swipe-to-delete
- Flights section: cards with price, airline, transfers, [deep link button]
- Hotels section: grouped by city, stars, price/night, [deep link button]
- Total cost badge (flights + hotels)
- Budget warning if over user's budget
- Bottom bar: [СОЗДАТЬ ПОЕЗДКУ] + [ПЕРЕГЕНЕРИРОВАТЬ]
- "СОЗДАТЬ ПОЕЗДКУ" action:
  ```swift
  func saveTrip() {
      let newTrip = Trip(
          name: trip.destination,
          country: trip.destination,
          startDate: trip.startDate,
          endDate: trip.endDate,
          budget: trip.totalEstimate,
          currency: "RUB",
          coverSystemImage: "airplane"
      )

      // Convert flights
      let tripFlights = trip.flights.map { offer in
          TripFlight(
              number: "\(offer.airline)\(offer.flightNumber)",
              date: ISO8601DateFormatter().date(from: offer.departureAt + "T00:00:00Z"),
              departureIata: offer.origin,
              arrivalIata: offer.destination
          )
      }
      newTrip.flightsJSON = try? JSONEncoder().encode(tripFlights).flatMap { String(data: $0, encoding: .utf8) } ?? nil

      // Convert days + places
      for genDay in trip.days {
          let dayDate = Calendar.current.date(byAdding: .day, value: genDay.dayNumber - 1, to: trip.startDate) ?? trip.startDate
          let tripDay = TripDay(
              date: dayDate,
              title: "День \(genDay.dayNumber)",
              cityName: genDay.city,
              sortOrder: genDay.dayNumber - 1
          )

          for genPlace in genDay.places {
              let place = Place(
                  name: genPlace.name,
                  nameLocal: "",
                  category: mapCategory(genPlace.category),
                  address: "",
                  latitude: genPlace.latitude,
                  longitude: genPlace.longitude,
                  notes: genPlace.description,
                  timeToSpend: genPlace.timeToSpend
              )
              tripDay.places.append(place)
          }

          newTrip.days.append(tripDay)
      }

      modelContext.insert(newTrip)
      try? modelContext.save()
      dismiss()
  }
  ```

**Step 2: Commit**

```bash
git add "Travel app/Views/AITripWizard/AITripPreviewView.swift"
git commit -m "feat: add AITripPreviewView — preview, edit, save generated trip"
```

---

## Task 6: Integration — HomeView + Settings

**Files:**
- Modify: `Travel app/Views/Home/HomeView.swift` (~line 220)
- Modify: `Travel app/Views/Settings/SettingsView.swift`

**Step 1: Add AI button to HomeView**

Add `@State private var showAIWizard = false` with other state vars (~line 7).

In `quickActions` computed property, add after "Новая поездка" button:

```swift
quickActionButton(
    icon: "sparkles",
    label: "AI поездка",
    color: AppTheme.sakuraPink
) {
    showAIWizard = true
}
```

Add `.fullScreenCover(isPresented: $showAIWizard)` alongside other sheets:

```swift
.fullScreenCover(isPresented: $showAIWizard) {
    AITripWizardView()
}
```

**Step 2: Add Travelpayouts key to SettingsView**

In the API keys section of SettingsView, add a field for Travelpayouts token following the same pattern as other API key fields (GlassFormField + SecureField + save to Secrets).

**Step 3: Commit**

```bash
git add "Travel app/Views/Home/HomeView.swift" "Travel app/Views/Settings/SettingsView.swift"
git commit -m "feat: integrate AI trip wizard into HomeView + add Travelpayouts key to settings"
```

---

## Task 7: Build + Test

**Step 1:** Build the project in Xcode for iPhone 16 Pro Max simulator (iOS 26.2). Fix any compilation errors.

**Step 2:** Test the wizard flow end-to-end:
- Open app → HomeView → tap "AI поездка"
- Step through wizard: destination → dates → budget → style
- Verify AI generation works (requires Gemini API key)
- Verify Travelpayouts returns flights/hotels (requires token)
- Preview screen shows editable days
- "СОЗДАТЬ ПОЕЗДКУ" saves to SwiftData
- Trip appears in home view

**Step 3: Commit final fixes**

```bash
git add -A
git commit -m "fix: resolve build errors and polish AI trip wizard"
```

---

## Summary

| Task | Description | New Files | Modified Files |
|------|-------------|-----------|----------------|
| 1 | TravelpayoutsService | 1 | 1 (Secrets) |
| 2 | AITripGeneratorService | 1 | 0 |
| 3 | 4 Wizard Steps | 4 | 0 |
| 4 | Wizard Container + Loading | 2 | 0 |
| 5 | Preview View | 1 | 0 |
| 6 | HomeView + Settings integration | 0 | 2 |
| 7 | Build + Test | 0 | * |
| **Total** | | **9 new** | **3 modified** |
