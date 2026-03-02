import Foundation
import CoreLocation
import SwiftUI
import SwiftData

// MARK: - Trip

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var budget: Double
    var currency: String
    var coverSystemImage: String
    var flightDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \TripDay.trip)
    var days: [TripDay] = []

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense] = []

    @Relationship(deleteRule: .cascade, inverse: \Ticket.trip)
    var tickets: [Ticket] = []

    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        budget: Double,
        currency: String,
        coverSystemImage: String,
        flightDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.budget = budget
        self.currency = currency
        self.coverSystemImage = coverSystemImage
        self.flightDate = flightDate
    }

    var totalDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var currentDay: Int {
        let now = Date()
        if now < startDate { return 0 }
        if now > endDate { return totalDays }
        return (Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 0) + 1
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
        guard let flight = flightDate, Date() < flight else { return nil }
        return Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: Date(),
            to: flight
        )
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

    var remainingBudget: Double {
        budget - totalSpent
    }

    var budgetUsedPercent: Double {
        guard budget > 0 else { return 0 }
        return totalSpent / budget
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
        Array(expenses.sorted { $0.date > $1.date }.prefix(5))
    }

    var todayDay: TripDay? {
        days.first { $0.isToday }
    }

    var sortedDays: [TripDay] {
        days.sorted { $0.date < $1.date }
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
        case .preTrip: return "До поездки"
        case .active: return "В путешествии"
        case .postTrip: return "Поездка завершена"
        }
    }
}

// MARK: - Trip Day

@Model
final class TripDay {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var cityName: String
    var notes: String

    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Place.day)
    var places: [Place] = []

    @Relationship(deleteRule: .cascade, inverse: \TripEvent.day)
    var events: [TripEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.day)
    var routePoints: [RoutePoint] = []

    @Relationship(deleteRule: .cascade, inverse: \Ticket.day)
    var tickets: [Ticket] = []

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        cityName: String,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.cityName = cityName
        self.notes = notes
    }

    var visitedCount: Int {
        places.filter(\.isVisited).count
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isPast: Bool {
        let calendar = Calendar.current
        let dayEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date)!)
        return Date() >= dayEnd
    }

    var isFuture: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Trip Event

@Model
final class TripEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var category: EventCategory
    var startTime: Date
    var endTime: Date
    var notes: String

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
        case .flight, .train, .bus: return true
        default: return false
        }
    }

    var systemImage: String {
        switch self {
        case .flight: return "airplane"
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
final class Place {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameJapanese: String
    var category: PlaceCategory
    var address: String
    var latitude: Double
    var longitude: Double
    var isVisited: Bool
    var rating: Int?
    var notes: String
    var timeToSpend: String

    var day: TripDay?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        nameJapanese: String,
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
        self.nameJapanese = nameJapanese
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
        }
    }
}

// MARK: - Expense

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var title: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var notes: String

    var trip: Trip?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: ExpenseCategory,
        date: Date,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
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
