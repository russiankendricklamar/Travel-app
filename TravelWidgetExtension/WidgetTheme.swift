import SwiftUI

// MARK: - Color(hex:) for Widget Extension

extension Color {
    init(widgetHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Widget Palette

struct WidgetPalette {
    let backgroundColors: [Color]
    let accentColor: Color
    let isDark: Bool

    static func from(name: String) -> WidgetPalette {
        switch name {
        case "sakura":
            return WidgetPalette(
                backgroundColors: [Color(widgetHex: "FFF5F8"), Color(widgetHex: "FDF2F8"), Color(widgetHex: "F8E8F0")],
                accentColor: Color(widgetHex: "EC4899"),
                isDark: false
            )
        case "midnight":
            return WidgetPalette(
                backgroundColors: [Color(widgetHex: "000000"), Color(widgetHex: "050505"), Color(widgetHex: "0A0A0A")],
                accentColor: Color(widgetHex: "EC4899"),
                isDark: true
            )
        case "imperial":
            return WidgetPalette(
                backgroundColors: [Color(widgetHex: "5C1818"), Color(widgetHex: "721E1E"), Color(widgetHex: "682020")],
                accentColor: Color(widgetHex: "E2D799"),
                isDark: true
            )
        case "matcha":
            return WidgetPalette(
                backgroundColors: [Color(widgetHex: "6DAF6C"), Color(widgetHex: "83C082"), Color(widgetHex: "78B877")],
                accentColor: Color(widgetHex: "FAFFBA"),
                isDark: true
            )
        case "fuji":
            return WidgetPalette(
                backgroundColors: [Color(widgetHex: "8088F0"), Color(widgetHex: "949CFF"), Color(widgetHex: "8A92F5")],
                accentColor: Color(widgetHex: "FFED86"),
                isDark: false
            )
        case "hanami":
            return WidgetPalette(
                backgroundColors: [Color(widgetHex: "FFF6CF"), Color(widgetHex: "FFF2C0"), Color(widgetHex: "FFEFB5")],
                accentColor: Color(widgetHex: "FF5A96"),
                isDark: false
            )
        default:
            return from(name: "sakura")
        }
    }
}

// MARK: - Russian Plural for Days

func daysWord(_ count: Int) -> String {
    let abs = abs(count)
    let mod10 = abs % 10
    let mod100 = abs % 100
    if mod10 == 1 && mod100 != 11 {
        return "день"
    } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
        return "дня"
    } else {
        return "дней"
    }
}
