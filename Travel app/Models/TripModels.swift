import Foundation
import CoreLocation
import SwiftUI

// MARK: - Trip

struct Trip: Identifiable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var budget: Double
    var currency: String
    var coverSystemImage: String
    var flightDate: Date?

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

// MARK: - Trip Phase

enum TripPhase {
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

struct TripDay: Identifiable {
    let id: UUID
    var date: Date
    var title: String
    var cityName: String
    var places: [Place]
    var events: [TripEvent]
    var notes: String

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

struct TripEvent: Identifiable {
    let id: UUID
    var title: String
    var subtitle: String
    var category: EventCategory
    var startTime: Date
    var endTime: Date
    var notes: String

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
}

enum EventCategory: String, CaseIterable, Identifiable {
    case flight = "Перелёт"
    case train = "Поезд"
    case bus = "Автобус"
    case f1 = "Формула 1"
    case tour = "Экскурсия"
    case reservation = "Бронь"
    case checkin = "Заселение"
    case other = "Событие"

    var id: String { rawValue }

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

struct Place: Identifiable {
    let id: UUID
    var name: String
    var nameJapanese: String
    var category: PlaceCategory
    var address: String
    var coordinate: CLLocationCoordinate2D
    var isVisited: Bool
    var rating: Int?
    var notes: String
    var timeToSpend: String
}

enum PlaceCategory: String, CaseIterable, Identifiable {
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

struct Expense: Identifiable {
    let id: UUID
    var title: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var notes: String
}

enum ExpenseCategory: String, CaseIterable, Identifiable {
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

// MARK: - Journal Entry

struct JournalEntry: Identifiable {
    let id: UUID
    var date: Date
    var title: String
    var content: String
    var mood: Mood
}

enum Mood: String, CaseIterable, Identifiable {
    case amazing = "Восторг"
    case happy = "Радость"
    case neutral = "Спокойствие"
    case tired = "Усталость"
    case frustrated = "Раздражение"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .amazing: return "star.fill"
        case .happy: return "face.smiling"
        case .neutral: return "face.dashed"
        case .tired: return "moon.zzz"
        case .frustrated: return "cloud.rain"
        }
    }
}
