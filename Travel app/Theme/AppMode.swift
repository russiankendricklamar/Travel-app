import SwiftUI

enum AppMode: String, CaseIterable {
    case personal
    case corporate

    static var current: AppMode {
        AppMode(rawValue: UserDefaults.standard.string(forKey: "appMode") ?? "personal") ?? .personal
    }

    var label: String {
        switch self {
        case .personal:  return "Личный"
        case .corporate: return "Корпоративный"
        }
    }

    var icon: String {
        switch self {
        case .personal:  return "person.fill"
        case .corporate: return "building.2.fill"
        }
    }

    var description: String {
        switch self {
        case .personal:  return "Путешествия и отпуск"
        case .corporate: return "Командировки и деловые поездки"
        }
    }
}

// MARK: - Corporate Color Constants

enum CorporateColors {
    static let deepNavy      = Color(hex: "050810")
    static let darkNavy      = Color(hex: "070B14")
    static let midNavy       = Color(hex: "090E1A")
    static let charcoalNavy  = Color(hex: "060A12")
    static let electricBlue  = Color(hex: "3B47FF")
    static let indigo        = Color(hex: "5B6CFF")
    static let silver        = Color(hex: "C0C8D8")
    static let shimmer       = Color(hex: "7B8AFF")
}
