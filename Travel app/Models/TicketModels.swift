import Foundation
import SwiftUI
import SwiftData

// MARK: - Ticket

@Model
final class Ticket {
    @Attribute(.unique) var id: UUID
    var title: String
    var venue: String
    var categoryRaw: String
    var barcodeTypeRaw: String
    var barcodeContent: String
    var eventDate: Date
    var expirationDate: Date?
    var seatInfo: String
    var notes: String

    var trip: Trip?
    var day: TripDay?

    init(
        id: UUID = UUID(),
        title: String,
        venue: String,
        category: TicketCategory,
        barcodeType: BarcodeType = .qr,
        barcodeContent: String,
        eventDate: Date,
        expirationDate: Date? = nil,
        seatInfo: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.venue = venue
        self.categoryRaw = category.rawValue
        self.barcodeTypeRaw = barcodeType.rawValue
        self.barcodeContent = barcodeContent
        self.eventDate = eventDate
        self.expirationDate = expirationDate
        self.seatInfo = seatInfo
        self.notes = notes
    }

    var category: TicketCategory {
        get { TicketCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var barcodeType: BarcodeType {
        get { BarcodeType(rawValue: barcodeTypeRaw) ?? .qr }
        set { barcodeTypeRaw = newValue.rawValue }
    }

    var isExpired: Bool {
        if let exp = expirationDate { return Date() > exp }
        return Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: eventDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(eventDate)
    }

    var isUpcoming: Bool {
        Calendar.current.startOfDay(for: eventDate) >= Calendar.current.startOfDay(for: Date())
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: eventDate)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: eventDate)
    }
}

// MARK: - Ticket Category

enum TicketCategory: String, CaseIterable, Identifiable, Codable {
    case f1 = "Формула 1"
    case concert = "Концерт"
    case museum = "Музей"
    case transport = "Транспорт"
    case hotel = "Отель"
    case excursion = "Экскурсия"
    case sports = "Спорт"
    case other = "Другое"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .f1: return "flag.checkered"
        case .concert: return "music.mic"
        case .museum: return "building.columns"
        case .transport: return "tram.fill"
        case .hotel: return "key.fill"
        case .excursion: return "figure.walk"
        case .sports: return "sportscourt"
        case .other: return "ticket"
        }
    }

    var color: Color {
        switch self {
        case .f1: return AppTheme.toriiRed
        case .concert: return AppTheme.indigoPurple
        case .museum: return AppTheme.templeGold
        case .transport: return AppTheme.oceanBlue
        case .hotel: return AppTheme.bambooGreen
        case .excursion: return AppTheme.sakuraPink
        case .sports: return AppTheme.toriiRed
        case .other: return AppTheme.textSecondary
        }
    }
}

// MARK: - Barcode Type

enum BarcodeType: String, CaseIterable, Identifiable, Codable {
    case qr = "QR"
    case code128 = "Code 128"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .qr: return "qrcode"
        case .code128: return "barcode"
        }
    }
}
