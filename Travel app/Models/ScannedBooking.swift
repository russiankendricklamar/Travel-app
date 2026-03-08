import Foundation

// MARK: - Booking Type

enum BookingType: String, Codable, CaseIterable {
    case flight
    case hotel
    case train
    case carRental = "car_rental"
    case bus
    case transfer

    var label: String {
        switch self {
        case .flight: return "Авиарейс"
        case .hotel: return "Отель"
        case .train: return "Поезд"
        case .carRental: return "Авто"
        case .bus: return "Автобус"
        case .transfer: return "Трансфер"
        }
    }

    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "bed.double.fill"
        case .train: return "tram.fill"
        case .carRental: return "car.fill"
        case .bus: return "bus.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Scanned Booking

struct ScannedBooking: Identifiable {
    let id = UUID()
    let type: BookingType
    var title: String
    var subtitle: String?
    var date: Date?
    var endDate: Date?
    var confirmationCode: String?
    var price: Double?
    var currency: String?
    // Flight-specific
    var departureIata: String?
    var arrivalIata: String?
    var flightNumber: String?
    // Hotel-specific
    var hotelName: String?
    var address: String?
    // Train-specific
    var trainNumber: String?
    var seatInfo: String?

    /// Convert to ScannedFlight for backward compat with existing flight flow
    func toScannedFlight() -> ScannedFlight? {
        guard type == .flight else { return nil }
        return ScannedFlight(
            number: flightNumber ?? title,
            date: date,
            departureIata: departureIata,
            arrivalIata: arrivalIata
        )
    }
}

// MARK: - Email Preview

struct EmailPreview: Identifiable {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let bodyText: String
    var isSelected: Bool = true
}
