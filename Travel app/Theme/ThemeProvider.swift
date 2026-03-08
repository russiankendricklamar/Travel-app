import SwiftUI

enum ColorPalette: String, CaseIterable, Identifiable {
    case sakura
    case midnight
    case imperial
    case matcha
    case fuji
    case hanami
    // MARK: - Corporate palettes (disabled)
    // case corporateCobalt
    // case corporateGraphite
    // case corporateOnyx
    // case corporateTitanium

    var id: String { rawValue }

    static var current: ColorPalette {
        ColorPalette(rawValue: UserDefaults.standard.string(forKey: "colorPalette") ?? "sakura") ?? .sakura
    }

    // MARK: - Corporate helpers (disabled)
    // var isCorporate: Bool {
    //     switch self {
    //     case .corporateCobalt, .corporateGraphite, .corporateOnyx, .corporateTitanium:
    //         return true
    //     default:
    //         return false
    //     }
    // }
    //
    // static var personalPalettes: [ColorPalette] {
    //     allCases.filter { !$0.isCorporate }
    // }
    //
    // static var corporatePalettes: [ColorPalette] {
    //     allCases.filter { $0.isCorporate }
    // }

    // MARK: - Accent Color

    var accentColor: Color {
        switch self {
        case .sakura:    return Color(hex: "EC4899")
        case .midnight:  return Color(hex: "EC4899")
        case .imperial:  return Color(hex: "E2D799")
        case .matcha:    return Color(hex: "FAFFBA")
        case .fuji:      return Color(hex: "FFED86")
        case .hanami:    return Color(hex: "FF5A96")
        // case .corporateCobalt:   return Color(hex: "3B47FF")
        // case .corporateGraphite: return Color(hex: "8B95A5")
        // case .corporateOnyx:     return Color(hex: "C9A84C")
        // case .corporateTitanium: return Color(hex: "0EA5E9")
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
        // case .corporateCobalt:
        //     return [
        //         Color(hex: "050810"),
        //         Color(hex: "070B14"),
        //         Color(hex: "090E1A"),
        //         Color(hex: "060A12"),
        //     ]
        // case .corporateGraphite:
        //     return [
        //         Color(hex: "08080C"),
        //         Color(hex: "0A0A10"),
        //         Color(hex: "0D0D14"),
        //         Color(hex: "09090E"),
        //     ]
        // case .corporateOnyx:
        //     return [
        //         Color(hex: "040404"),
        //         Color(hex: "060606"),
        //         Color(hex: "080808"),
        //         Color(hex: "050505"),
        //     ]
        // case .corporateTitanium:
        //     return [
        //         Color(hex: "060A10"),
        //         Color(hex: "080D14"),
        //         Color(hex: "0A1018"),
        //         Color(hex: "070B12"),
        //     ]
        }
    }

    // MARK: - Color Scheme

    var colorScheme: ColorScheme {
        switch self {
        case .sakura:    return .light
        case .midnight:  return .dark
        case .imperial:  return .dark
        case .matcha:    return .dark
        case .fuji:      return .light
        case .hanami:    return .light
        // case .corporateCobalt, .corporateGraphite, .corporateOnyx, .corporateTitanium:
        //     return .dark
        }
    }

    // MARK: - Label

    var label: String {
        switch self {
        case .sakura:    return String(localized: "Сакура")
        case .midnight:  return String(localized: "Полночь")
        case .imperial:  return String(localized: "Императорский")
        case .matcha:    return String(localized: "Матча")
        case .fuji:      return String(localized: "Фудзи")
        case .hanami:    return String(localized: "Ханами")
        // case .corporateCobalt:   return String(localized: "Кобальт")
        // case .corporateGraphite: return String(localized: "Графит")
        // case .corporateOnyx:     return String(localized: "Оникс")
        // case .corporateTitanium: return String(localized: "Титан")
        }
    }
}
