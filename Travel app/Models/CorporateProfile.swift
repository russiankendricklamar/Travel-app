import Foundation

// MARK: - Flight Class

enum FlightClass: String, Codable, CaseIterable, Identifiable {
    case economy
    case comfort
    case business
    case first

    var id: String { rawValue }

    var label: String {
        switch self {
        case .economy:  return "Эконом"
        case .comfort:  return "Комфорт"
        case .business: return "Бизнес"
        case .first:    return "Первый"
        }
    }
}

// MARK: - Corporate Limits

struct CorporateLimits: Codable {
    var hotelPerNight: Double = 0
    var flightClass: FlightClass = .economy
    var transportDaily: Double = 0
    var foodDaily: Double = 0
}

// MARK: - Corporate Profile

struct CorporateProfile: Codable {
    var company: String = ""
    var department: String = ""
    var division: String = ""
    var position: String = ""
    var limits: CorporateLimits = CorporateLimits()
    var preferredVendors: [String] = []
    var approvalManager: String = ""
}
