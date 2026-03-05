import SwiftUI

enum ColorPalette: String, CaseIterable, Identifiable {
    case sakura
    case midnight
    case imperial
    case matcha
    case fuji
    case hanami

    var id: String { rawValue }

    static var current: ColorPalette {
        ColorPalette(rawValue: UserDefaults.standard.string(forKey: "colorPalette") ?? "sakura") ?? .sakura
    }

    // MARK: - Accent Color

    var accentColor: Color {
        switch self {
        case .sakura:   return Color(hex: "EC4899")
        case .midnight: return Color(hex: "EC4899")
        case .imperial: return Color(hex: "E2D799")
        case .matcha:   return Color(hex: "FAFFBA")
        case .fuji:     return Color(hex: "FFED86")
        case .hanami:   return Color(hex: "FF5A96")
        }
    }

    // MARK: - Background Gradient Colors

    var backgroundColors: [Color] {
        switch self {
        case .sakura:
            return [
                Color(hex: "FFF5F8"),
                Color(hex: "FDF2F8"),
                Color(hex: "F8E8F0"),
                Color(hex: "FFF0F5"),
            ]
        case .midnight:
            return [
                Color(hex: "000000"),
                Color(hex: "050505"),
                Color(hex: "0A0A0A"),
            ]
        case .imperial:
            return [
                Color(hex: "5C1818"),
                Color(hex: "721E1E"),
                Color(hex: "682020"),
                Color(hex: "5A1515"),
            ]
        case .matcha:
            return [
                Color(hex: "6DAF6C"),
                Color(hex: "83C082"),
                Color(hex: "78B877"),
                Color(hex: "6BA86A"),
            ]
        case .fuji:
            return [
                Color(hex: "8088F0"),
                Color(hex: "949CFF"),
                Color(hex: "8A92F5"),
                Color(hex: "7E86EE"),
            ]
        case .hanami:
            return [
                Color(hex: "FFF6CF"),
                Color(hex: "FFF2C0"),
                Color(hex: "FFEFB5"),
                Color(hex: "FFF4C8"),
            ]
        }
    }

    // MARK: - Color Scheme

    var colorScheme: ColorScheme {
        switch self {
        case .sakura:   return .light
        case .midnight: return .dark
        case .imperial: return .dark
        case .matcha:   return .dark
        case .fuji:     return .light
        case .hanami:   return .light
        }
    }

    // MARK: - Label

    var label: String {
        switch self {
        case .sakura:   return String(localized: "Сакура")
        case .midnight: return String(localized: "Полночь")
        case .imperial: return String(localized: "Императорский")
        case .matcha:   return String(localized: "Матча")
        case .fuji:     return String(localized: "Фудзи")
        case .hanami:   return String(localized: "Ханами")
        }
    }
}
