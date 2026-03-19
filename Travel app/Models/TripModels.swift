import Foundation
import CoreLocation
import SwiftUI
import SwiftData

// MARK: - Trip Flight

struct TripFlight: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var number: String
    var date: Date?
    var departureIata: String?
    var arrivalIata: String?
    var airlineCode: String?
    var aircraftType: String?
}

// MARK: - Trip

@Model
final class Trip: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(originalName: "destination") var country: String
    var startDate: Date
    var endDate: Date
    var budget: Double
    var currency: String
    var coverSystemImage: String
    var flightDate: Date?
    var flightNumber: String?
    var flightsJSON: String?
    var isCorporateTrip: Bool = false
    var countryFlags: String = ""
    var budgetSourcesJSON: String?
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \TripDay.trip)
    var days: [TripDay] = []

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense] = []

    @Relationship(deleteRule: .cascade, inverse: \Ticket.trip)
    var tickets: [Ticket] = []

    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
    var packingItems: [PackingItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        country: String,
        startDate: Date,
        endDate: Date,
        budget: Double,
        currency: String,
        coverSystemImage: String,
        flightDate: Date? = nil,
        flightNumber: String? = nil,
        flightsJSON: String? = nil,
        isCorporateTrip: Bool = false,
        countryFlags: String = ""
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.startDate = startDate
        self.endDate = endDate
        self.budget = budget
        self.currency = currency
        self.coverSystemImage = coverSystemImage
        self.flightDate = flightDate
        self.flightNumber = flightNumber
        self.flightsJSON = flightsJSON
        self.isCorporateTrip = isCorporateTrip
        self.countryFlags = countryFlags
    }

    // MARK: - Flights (multi-flight support)

    var flights: [TripFlight] {
        get {
            let raw: [TripFlight]
            if let json = flightsJSON, let data = json.data(using: .utf8) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                raw = (try? decoder.decode([TripFlight].self, from: data)) ?? []
            } else if let num = flightNumber {
                raw = [TripFlight(number: num, date: flightDate)]
            } else {
                raw = []
            }
            return raw.sorted { a, b in
                switch (a.date, b.date) {
                case let (ad?, bd?): return ad < bd
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
        }
        set {
            let sorted = newValue.sorted { a, b in
                switch (a.date, b.date) {
                case let (ad?, bd?): return ad < bd
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if sorted.isEmpty {
                flightsJSON = nil
            } else if let data = try? encoder.encode(sorted) {
                flightsJSON = String(data: data, encoding: .utf8)
            }
            flightNumber = sorted.first?.number
            flightDate = sorted.first?.date
        }
    }

    // MARK: - Budget Sources (multi-currency)

    var budgetSources: [BudgetSource] {
        get {
            guard let json = budgetSourcesJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([BudgetSource].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                budgetSourcesJSON = nil
            } else if let data = try? JSONEncoder().encode(newValue) {
                budgetSourcesJSON = String(data: data, encoding: .utf8)
            }
        }
    }

    /// Total budget computed from sources (converted to base currency)
    var computedBudget: Double {
        let sources = budgetSources
        guard !sources.isEmpty else { return budget }
        let cs = CurrencyService.shared
        return sources.reduce(0) { total, source in
            if source.currency == cs.baseCurrency {
                return total + source.amount
            }
            return total + cs.convert(source.amount, from: source.currency, to: cs.baseCurrency)
        }
    }

    // MARK: - Multi-Country Support

    /// Parsed array of countries from the comma-separated `country` field
    var countries: [String] {
        get {
            country.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            country = newValue.joined(separator: ", ")
        }
    }

    /// Display string: "Япония, Италия" or single country
    var countriesDisplay: String {
        countries.joined(separator: ", ")
    }

    /// Display with flag emoji prepended: "🇯🇵 Япония, 🇮🇹 Италия"
    var flaggedCountriesDisplay: String {
        if countryFlags.isEmpty {
            return countriesDisplay
        }
        return "\(countryFlags) \(countriesDisplay)"
    }

    /// Calendar in the destination's local timezone (uses first day with resolved TZ, falls back to device)
    private var destinationCalendar: Calendar {
        var cal = Calendar.current
        if let tz = days.first(where: { $0.resolvedTimeZone != nil })?.resolvedTimeZone {
            cal.timeZone = tz
        }
        return cal
    }

    var totalDays: Int {
        let cal = destinationCalendar
        let startDay = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: endDate)
        return cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }

    var currentDay: Int {
        let cal = destinationCalendar
        let now = Date()
        if now < startDate { return 0 }
        if now > endDate { return totalDays }
        // Compare start-of-day in destination timezone to avoid off-by-one from timezone shifts
        let startDay = cal.startOfDay(for: startDate)
        let todayDay = cal.startOfDay(for: now)
        return (cal.dateComponents([.day], from: startDay, to: todayDay).day ?? 0) + 1
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var isUpcoming: Bool {
        Date() < startDate
    }

    var isPast: Bool {
        Date() > endDate
    }

    var progress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay) / Double(totalDays)
    }

    // MARK: - Countdown

    var countdownToFlight: DateComponents? {
        let now = Date()
        let nextFlightDate = flights
            .compactMap(\.date)
            .filter { $0 > now }
            .min()
        guard let flight = nextFlightDate else { return nil }
        return Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: now,
            to: flight
        )
    }

    func updateFlightIata(flightID: UUID, data: FlightData) {
        var updated = flights
        guard let idx = updated.firstIndex(where: { $0.id == flightID }) else { return }
        updated[idx].departureIata = data.departureIata
        updated[idx].arrivalIata = data.arrivalIata
        updated[idx].airlineCode = String(data.flightIata.prefix(while: \.isLetter))
        updated[idx].aircraftType = data.aircraftType
        flights = updated
    }

    var countdownToStart: DateComponents? {
        guard Date() < startDate else { return nil }
        return Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: Date(),
            to: startDate
        )
    }
}

// MARK: - Trip Computed (from TripStore)

extension Trip {
    var phase: TripPhase {
        if isUpcoming { return .preTrip }
        if isActive { return .active }
        return .postTrip
    }

    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var effectiveBudget: Double {
        budgetSources.isEmpty ? budget : computedBudget
    }

    var remainingBudget: Double {
        effectiveBudget - totalSpent
    }

    var budgetUsedPercent: Double {
        guard effectiveBudget > 0 else { return 0 }
        return totalSpent / effectiveBudget
    }

    var allPlaces: [Place] {
        days.flatMap(\.places)
    }

    var placesVisitedCount: Int {
        allPlaces.filter(\.isVisited).count
    }

    var totalPlacesCount: Int {
        allPlaces.count
    }

    var expensesByCategory: [(category: ExpenseCategory, total: Double)] {
        ExpenseCategory.allCases.compactMap { category in
            let total = expenses
                .filter { $0.category == category }
                .reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil }
            return (category: category, total: total)
        }
        .sorted { $0.total > $1.total }
    }

    var recentExpenses: [Expense] {
        Array(expenses.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }

    var todayDay: TripDay? {
        days.first { $0.isToday }
    }

    var sortedDays: [TripDay] {
        days.sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalPacked: Int {
        packingItems.filter(\.isPacked).count
    }

    var packingProgress: Double {
        guard !packingItems.isEmpty else { return 0 }
        return Double(totalPacked) / Double(packingItems.count)
    }

    var allJournalEntries: [JournalEntry] {
        days.flatMap(\.journalEntries).sorted { $0.timestamp > $1.timestamp }
    }

    func migrateSortOrdersIfNeeded() {
        let key = "sortOrderMigrated_\(id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let byDate = days.sorted { $0.date < $1.date }
        for (i, day) in byDate.enumerated() {
            day.sortOrder = i
            for (j, place) in day.places.enumerated() {
                place.sortOrder = j
            }
            for (j, event) in day.events.sorted(by: { $0.startTime < $1.startTime }).enumerated() {
                event.sortOrder = j
            }
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    var activeDay: TripDay? {
        if let today = todayDay { return today }
        return days
            .filter { $0.isFuture }
            .sorted { $0.date < $1.date }
            .first
    }

    func autoCompletePastDays() {
        for day in days where day.isPast {
            for place in day.places where !place.isVisited {
                place.isVisited = true
            }
        }
    }
}

// MARK: - Trip Phase

enum TripPhase: String, Codable {
    case preTrip
    case active
    case postTrip

    var label: String {
        switch self {
        case .preTrip: return String(localized: "До поездки")
        case .active: return String(localized: "В путешествии")
        case .postTrip: return String(localized: "Поездка завершена")
        }
    }
}

// MARK: - Trip Day

@Model
final class TripDay: Syncable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var cityName: String
    var notes: String
    var sortOrder: Int = 0
    var timezoneIdentifier: String = ""
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Place.day)
    var places: [Place] = []

    @Relationship(deleteRule: .cascade, inverse: \TripEvent.day)
    var events: [TripEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.day)
    var routePoints: [RoutePoint] = []

    @Relationship(deleteRule: .cascade, inverse: \Ticket.day)
    var tickets: [Ticket] = []

    @Relationship(deleteRule: .cascade, inverse: \TripPhoto.day)
    var photos: [TripPhoto] = []

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.day)
    var journalEntries: [JournalEntry] = []

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        cityName: String,
        notes: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.cityName = cityName
        self.notes = notes
        self.sortOrder = sortOrder
    }

    /// Cached timezone resolved from cityName
    var resolvedTimeZone: TimeZone? {
        guard !timezoneIdentifier.isEmpty else { return nil }
        return TimeZone(identifier: timezoneIdentifier)
    }

    var sortedPlaces: [Place] {
        places.sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedEvents: [TripEvent] {
        events.sorted { $0.sortOrder < $1.sortOrder }
    }

    var visitedCount: Int {
        places.filter(\.isVisited).count
    }

    /// Calendar in the day's local timezone (falls back to device timezone)
    private var localCalendar: Calendar {
        var cal = Calendar.current
        if let tz = resolvedTimeZone {
            cal.timeZone = tz
        }
        return cal
    }

    var isToday: Bool {
        localCalendar.isDateInToday(date)
    }

    var isPast: Bool {
        let cal = localCalendar
        let dayEnd = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: date)!)
        return Date() >= dayEnd
    }

    var isFuture: Bool {
        let cal = localCalendar
        return cal.startOfDay(for: date) > cal.startOfDay(for: Date())
    }
}

// MARK: - Trip Event

@Model
final class TripEvent: Syncable {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var category: EventCategory
    var startTime: Date
    var endTime: Date
    var notes: String
    var sortOrder: Int = 0
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    // Location for regular events (museum, checkin, etc.)
    var latitude: Double?
    var longitude: Double?

    // Location for transport events (start/end points)
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?

    var day: TripDay?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        category: EventCategory,
        startTime: Date,
        endTime: Date,
        notes: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var isOngoing: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }

    var isPast: Bool {
        Date() > endTime
    }

    var isFuture: Bool {
        Date() < startTime
    }

    var timeUntilStart: TimeInterval? {
        guard isFuture else { return nil }
        return startTime.timeIntervalSince(Date())
    }

    var timeUntilEnd: TimeInterval? {
        guard isOngoing else { return nil }
        return endTime.timeIntervalSince(Date())
    }

    var progress: Double {
        guard isOngoing else {
            return isPast ? 1.0 : 0.0
        }
        let total = endTime.timeIntervalSince(startTime)
        let elapsed = Date().timeIntervalSince(startTime)
        return min(max(elapsed / total, 0), 1)
    }

    var formattedTimeRange: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        if let tz = day?.resolvedTimeZone {
            f.timeZone = tz
        }
        return "\(f.string(from: startTime))–\(f.string(from: endTime))"
    }

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return remainingMinutes > 0 ? "\(hours)ч \(remainingMinutes)мин" : "\(hours)ч"
        }
        return "\(minutes)мин"
    }

    // MARK: - Location Computed Properties

    var isTransportEvent: Bool {
        category.isTransport
    }

    var hasLocation: Bool {
        if isTransportEvent {
            return startLatitude != nil && startLongitude != nil
        }
        return latitude != nil && longitude != nil
    }

    /// Primary coordinate: for regular events — the location; for transport — departure point
    var primaryCoordinate: CLLocationCoordinate2D? {
        if isTransportEvent {
            guard let lat = startLatitude, let lon = startLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Arrival coordinate: only for transport events — the destination
    var arrivalCoordinate: CLLocationCoordinate2D? {
        guard isTransportEvent, let lat = endLatitude, let lon = endLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Effective end coordinate: where the person ends up after this event
    var effectiveEndCoordinate: CLLocationCoordinate2D? {
        if isTransportEvent {
            return arrivalCoordinate ?? primaryCoordinate
        }
        return primaryCoordinate
    }
}

enum EventCategory: String, CaseIterable, Identifiable, Codable {
    case flight = "Перелёт"
    case shinkansen = "Синкансен"
    case train = "Поезд"
    case bus = "Автобус"
    case f1 = "Формула 1"
    case tour = "Экскурсия"
    case reservation = "Бронь"
    case checkin = "Заселение"
    case other = "Событие"

    var id: String { rawValue }

    var isTransport: Bool {
        switch self {
        case .flight, .shinkansen, .train, .bus: return true
        default: return false
        }
    }

    /// Whether this is any kind of rail transport (train or shinkansen)
    var isRail: Bool {
        self == .train || self == .shinkansen
    }

    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .shinkansen: return "train.side.front.car"
        case .train: return "tram.fill"
        case .bus: return "bus.fill"
        case .f1: return "flag.checkered"
        case .tour: return "figure.walk"
        case .reservation: return "fork.knife"
        case .checkin: return "key.fill"
        case .other: return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .flight: return AppTheme.oceanBlue
        case .shinkansen: return AppTheme.oceanBlue
        case .train: return AppTheme.sakuraPink
        case .bus: return AppTheme.templeGold
        case .f1: return AppTheme.toriiRed
        case .tour: return AppTheme.bambooGreen
        case .reservation: return AppTheme.templeGold
        case .checkin: return AppTheme.oceanBlue
        case .other: return AppTheme.textSecondary
        }
    }
}

// MARK: - Place

@Model
final class Place: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameLocal: String
    var category: PlaceCategory
    var address: String
    var latitude: Double
    var longitude: Double
    var isVisited: Bool
    var rating: Int?
    var notes: String
    var timeToSpend: String
    var sortOrder: Int = 0
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    var day: TripDay?

    @Relationship(deleteRule: .cascade, inverse: \TripPhoto.place)
    var photos: [TripPhoto] = []

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        nameLocal: String,
        category: PlaceCategory,
        address: String,
        latitude: Double,
        longitude: Double,
        isVisited: Bool = false,
        rating: Int? = nil,
        notes: String = "",
        timeToSpend: String = ""
    ) {
        self.id = id
        self.name = name
        self.nameLocal = nameLocal
        self.category = category
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.isVisited = isVisited
        self.rating = rating
        self.notes = notes
        self.timeToSpend = timeToSpend
    }
}

enum PlaceCategory: String, CaseIterable, Identifiable, Codable {
    case temple = "Храм"
    case shrine = "Святилище"
    case food = "Еда"
    case shopping = "Шопинг"
    case nature = "Природа"
    case culture = "Культура"
    case accommodation = "Жильё"
    case transport = "Транспорт"
    case museum = "Музей"
    case gallery = "Галерея"
    case palace = "Дворец"
    case park = "Парк"
    case garden = "Сад"
    case lake = "Озеро"
    case mountains = "Горы"
    case airport = "Аэропорт"
    case station = "Вокзал"
    case metro = "Метро"
    case sport = "Спорт"
    case stadium = "Стадион"
    case viewpoint = "Смотровая"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .temple: return "building.columns"
        case .shrine: return "sparkles"
        case .food: return "fork.knife"
        case .shopping: return "bag"
        case .nature: return "leaf"
        case .culture: return "theatermasks"
        case .accommodation: return "bed.double"
        case .transport: return "tram"
        case .museum: return "building.columns.fill"
        case .gallery: return "photo.artframe"
        case .palace: return "crown.fill"
        case .park: return "tree.fill"
        case .garden: return "camera.macro"
        case .lake: return "water.waves"
        case .mountains: return "mountain.2.fill"
        case .airport: return "airplane"
        case .station: return "train.side.front.car"
        case .metro: return "tram.fill.tunnel"
        case .sport: return "figure.run"
        case .stadium: return "sportscourt.fill"
        case .viewpoint: return "binoculars.fill"
        }
    }
}

// MARK: - Budget Source

struct BudgetSource: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String           // e.g. "Карта Тинькофф", "Наличные"
    var currency: String       // e.g. "JPY", "USD", "RUB"
    var amount: Double         // Amount in that currency
    var icon: String           // SF Symbol e.g. "creditcard.fill"

    enum SourceIcon: String, CaseIterable {
        case card = "creditcard.fill"
        case cash = "banknote.fill"
        case savings = "building.columns.fill"
        case wallet = "wallet.bifold.fill"
        case gift = "gift.fill"

        var label: String {
            switch self {
            case .card: return "Карта"
            case .cash: return "Наличные"
            case .savings: return "Счёт"
            case .wallet: return "Кошелёк"
            case .gift: return "Подарок"
            }
        }
    }
}

// MARK: - Expense

@Model
final class Expense: Syncable {
    @Attribute(.unique) var id: UUID
    var title: String
    var amount: Double              // Converted to base currency
    var originalAmount: Double = 0  // Amount in original currency
    var originalCurrency: String = ""  // Currency code used at input
    var exchangeRate: Double = 1.0  // Rate used: 1 originalCurrency = X baseCurrency
    var category: ExpenseCategory
    var date: Date
    var notes: String
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \TripPhoto.expense)
    var photos: [TripPhoto] = []

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: ExpenseCategory,
        date: Date,
        notes: String = "",
        originalAmount: Double = 0,
        originalCurrency: String = "",
        exchangeRate: Double = 1.0
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.originalAmount = originalAmount.isZero ? amount : originalAmount
        self.originalCurrency = originalCurrency.isEmpty ? (UserDefaults.standard.string(forKey: "preferredCurrency") ?? "RUB") : originalCurrency
        self.exchangeRate = exchangeRate
    }
}

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food = "Еда"
    case transport = "Транспорт"
    case accommodation = "Жильё"
    case activities = "Развлечения"
    case shopping = "Шопинг"
    case other = "Другое"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "tram"
        case .accommodation: return "bed.double"
        case .activities: return "ticket"
        case .shopping: return "bag"
        case .other: return "ellipsis.circle"
        }
    }

    /// AI-категоризация по названию расхода (локальный keyword matching)
    static func guess(from title: String) -> ExpenseCategory {
        let t = title.lowercased()

        let foodKeys = ["ресторан", "кафе", "кофе", "coffee", "обед", "ужин", "завтрак", "еда",
                        "рамен", "суши", "пицца", "бургер", "макдональдс", "mcdonald", "starbucks",
                        "старбакс", "бар", "паб", "pub", "food", "restaurant", "cafe", "lunch",
                        "dinner", "breakfast", "булочная", "пекарня", "bakery", "фастфуд",
                        "столовая", "буфет", "снек", "snack", "напиток", "drink", "сок", "чай",
                        "пиво", "beer", "вино", "wine", "продукты", "grocery", "супермаркет",
                        "market", "магнит", "пятёрочка", "перекрёсток", "convenience", "combini",
                        "konbini", "izakaya", "ramen", "sushi", "bento", "matcha"]

        let transportKeys = ["такси", "taxi", "uber", "яндекс", "метро", "metro", "subway",
                             "автобус", "bus", "трамвай", "tram", "поезд", "train", "жд",
                             "электричка", "бензин", "fuel", "gas", "парковка", "parking",
                             "toll", "прокат", "rental", "каршеринг", "grab", "bolt",
                             "suica", "pasmo", "ic card", "проездной", "билет на"]

        let accommodationKeys = ["отель", "hotel", "хостел", "hostel", "airbnb", "booking",
                                 "квартира", "apartment", "жильё", "гостиница", "номер",
                                 "ночь", "night", "проживание", "stay", "lodge", "ryokan",
                                 "capsule", "inn"]

        let activityKeys = ["билет", "ticket", "музей", "museum", "парк", "park", "экскурсия",
                           "tour", "аттракцион", "зоопарк", "zoo", "аквариум", "aquarium",
                           "кино", "cinema", "movie", "театр", "theater", "концерт", "concert",
                           "спа", "spa", "массаж", "massage", "онсэн", "onsen", "храм",
                           "temple", "shrine", "вход", "entrance", "admission", "pass"]

        let shoppingKeys = ["магазин", "shop", "store", "покупка", "purchase", "сувенир",
                           "souvenir", "одежда", "clothes", "обувь", "shoes", "подарок", "gift",
                           "аптека", "pharmacy", "электроника", "electronics", "uniqlo",
                           "sim", "сим-карта", "чемодан", "сумка", "bag"]

        if foodKeys.contains(where: { t.contains($0) }) { return .food }
        if transportKeys.contains(where: { t.contains($0) }) { return .transport }
        if accommodationKeys.contains(where: { t.contains($0) }) { return .accommodation }
        if activityKeys.contains(where: { t.contains($0) }) { return .activities }
        if shoppingKeys.contains(where: { t.contains($0) }) { return .shopping }

        return .other
    }
}


// MARK: - Preview Support

#if DEBUG
extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, configurations: config)
        SampleData.seed(into: container.mainContext)
        return container
    }
}

extension Trip {
    @MainActor
    static var preview: Trip {
        let container = ModelContainer.preview
        let descriptor = FetchDescriptor<Trip>()
        return try! container.mainContext.fetch(descriptor).first!
    }
}
#endif
