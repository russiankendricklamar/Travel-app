import Foundation

// MARK: - Syncable Protocol

protocol Syncable: AnyObject {
    var updatedAt: Date { get set }
    var isDeleted: Bool { get set }
}

extension Syncable {
    func markUpdated() {
        updatedAt = Date()
    }

    func markDeleted() {
        isDeleted = true
        updatedAt = Date()
    }
}

// MARK: - Codable DTOs for Supabase (snake_case)

struct TripDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let destination: String
    let startDate: String?
    let endDate: String?
    let budget: Double
    let currency: String
    let coverSystemImage: String?
    let flightDate: String?
    let flightNumber: String?
    let flightsJson: String?
    let countryFlags: String?
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, destination
        case startDate = "start_date"
        case endDate = "end_date"
        case budget, currency
        case coverSystemImage = "cover_system_image"
        case flightDate = "flight_date"
        case flightNumber = "flight_number"
        case flightsJson = "flights_json"
        case countryFlags = "country_flags"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct TripDayDTO: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let date: String
    let title: String
    let cityName: String
    let notes: String
    let sortOrder: Int
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case date, title
        case cityName = "city_name"
        case notes
        case sortOrder = "sort_order"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct PlaceDTO: Codable {
    let id: UUID
    let userId: UUID
    let dayId: UUID
    let name: String
    let nameLocal: String
    let category: String
    let address: String
    let latitude: Double
    let longitude: Double
    let isVisited: Bool
    let rating: Int?
    let notes: String
    let timeToSpend: String
    let sortOrder: Int
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayId = "day_id"
        case name
        case nameLocal = "name_local"
        case category, address, latitude, longitude
        case isVisited = "is_visited"
        case rating, notes
        case timeToSpend = "time_to_spend"
        case sortOrder = "sort_order"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct TripEventDTO: Codable {
    let id: UUID
    let userId: UUID
    let dayId: UUID
    let title: String
    let subtitle: String
    let category: String
    let startTime: String?
    let endTime: String?
    let notes: String
    let sortOrder: Int
    let latitude: Double?
    let longitude: Double?
    let startLatitude: Double?
    let startLongitude: Double?
    let endLatitude: Double?
    let endLongitude: Double?
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayId = "day_id"
        case title, subtitle, category
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case sortOrder = "sort_order"
        case latitude, longitude
        case startLatitude = "start_latitude"
        case startLongitude = "start_longitude"
        case endLatitude = "end_latitude"
        case endLongitude = "end_longitude"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct ExpenseDTO: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let title: String
    let amount: Double
    let category: String
    let date: String?
    let notes: String
    let originalAmount: Double?
    let originalCurrency: String?
    let exchangeRate: Double?
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case title, amount, category, date, notes
        case originalAmount = "original_amount"
        case originalCurrency = "original_currency"
        case exchangeRate = "exchange_rate"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct TicketDTO: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let dayId: UUID?
    let title: String
    let venue: String
    let categoryRaw: String
    let barcodeTypeRaw: String
    let barcodeContent: String
    let eventDate: String?
    let expirationDate: String?
    let seatInfo: String
    let notes: String
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case dayId = "day_id"
        case title, venue
        case categoryRaw = "category_raw"
        case barcodeTypeRaw = "barcode_type_raw"
        case barcodeContent = "barcode_content"
        case eventDate = "event_date"
        case expirationDate = "expiration_date"
        case seatInfo = "seat_info"
        case notes
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct PackingItemDTO: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let name: String
    let category: String
    let isPacked: Bool
    let quantity: Int
    let isAiSuggested: Bool
    let sortOrder: Int
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case name, category
        case isPacked = "is_packed"
        case quantity
        case isAiSuggested = "is_ai_suggested"
        case sortOrder = "sort_order"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct JournalEntryDTO: Codable {
    let id: UUID
    let userId: UUID
    let dayId: UUID
    let placeId: UUID?
    let text: String
    let mood: String
    let timestamp: String
    let isStandalone: Bool
    let latitude: Double?
    let longitude: Double?
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayId = "day_id"
        case placeId = "place_id"
        case text, mood, timestamp
        case isStandalone = "is_standalone"
        case latitude, longitude
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct RoutePointDTO: Codable {
    let id: UUID
    let userId: UUID
    let dayId: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayId = "day_id"
        case latitude, longitude, timestamp
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct TripPhotoDTO: Codable {
    let id: UUID
    let userId: UUID
    let storagePath: String?
    let thumbnailPath: String?
    let caption: String
    let placeId: UUID?
    let expenseId: UUID?
    let dayId: UUID?
    let journalEntryId: UUID?
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case storagePath = "storage_path"
        case thumbnailPath = "thumbnail_path"
        case caption
        case placeId = "place_id"
        case expenseId = "expense_id"
        case dayId = "day_id"
        case journalEntryId = "journal_entry_id"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct BucketListItemDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let destination: String
    let category: String
    let notes: String
    let latitude: Double?
    let longitude: Double?
    let dateAdded: String
    let isConverted: Bool
    let photoStoragePath: String?
    let updatedAt: String
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, destination, category, notes
        case latitude, longitude
        case dateAdded = "date_added"
        case isConverted = "is_converted"
        case photoStoragePath = "photo_storage_path"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

// MARK: - ISO8601 Date Helpers

enum SyncDateFormatter {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func string(from date: Date) -> String {
        iso8601.string(from: date)
    }

    static func date(from string: String) -> Date? {
        iso8601.date(from: string)
    }

    static func dateString(from date: Date) -> String {
        dateOnly.string(from: date)
    }

    static func dateFromDateString(_ string: String) -> Date? {
        dateOnly.date(from: string)
    }
}
