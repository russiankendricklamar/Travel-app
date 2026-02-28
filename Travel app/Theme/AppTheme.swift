import SwiftUI

enum AppTheme {
    // MARK: - Background Colors (Sakura Light)
    static let background = Color(hex: "FEFCFD")
    static let surface = Color(hex: "FDF2F8")
    static let card = Color(hex: "FFFFFF")
    static let cardHover = Color(hex: "FFF5F9")

    // MARK: - Accent Colors (Japan Sakura)
    static let sakuraPink = Color(hex: "EC4899")
    static let sakuraLight = Color(hex: "FBCFE8")
    static let toriiRed = Color(hex: "E11D48")
    static let templeGold = Color(hex: "D97706")
    static let bambooGreen = Color(hex: "16A34A")
    static let oceanBlue = Color(hex: "2563EB")

    // MARK: - Soft Accent Variants
    static let softPink = Color(hex: "FDF2F8")
    static let softRed = Color(hex: "FFF1F2")
    static let softGold = Color(hex: "FFFBEB")
    static let softGreen = Color(hex: "F0FDF4")
    static let softBlue = Color(hex: "EFF6FF")

    // MARK: - Text Colors (Dark on Light)
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "64748B")
    static let textMuted = Color(hex: "94A3B8")

    // MARK: - Semantic Colors
    static let primary = sakuraPink
    static let success = bambooGreen
    static let warning = templeGold
    static let info = oceanBlue

    // MARK: - Border
    static let border = Color(hex: "F3D5E4")
    static let borderAccent = sakuraPink

    // MARK: - Category Colors
    static func categoryColor(for category: String) -> Color {
        switch category {
        case "Храм", "Святилище": return templeGold
        case "Еда": return toriiRed
        case "Шопинг": return sakuraPink
        case "Природа": return bambooGreen
        case "Культура": return oceanBlue
        case "Транспорт": return info
        case "Жильё": return textSecondary
        case "Развлечения": return sakuraPink
        default: return textMuted
        }
    }

    // MARK: - Expense Category Colors
    static func expenseColor(for category: ExpenseCategory) -> Color {
        switch category {
        case .food: return toriiRed
        case .transport: return oceanBlue
        case .accommodation: return textSecondary
        case .activities: return sakuraPink
        case .shopping: return templeGold
        case .other: return textMuted
        }
    }

    // MARK: - Mood Colors
    static func moodColor(for mood: Mood) -> Color {
        switch mood {
        case .amazing: return templeGold
        case .happy: return bambooGreen
        case .neutral: return oceanBlue
        case .tired: return textMuted
        case .frustrated: return toriiRed
        }
    }

    // MARK: - Brutalist: No Rounded Corners
    static let radiusSmall: CGFloat = 0
    static let radiusMedium: CGFloat = 0
    static let radiusLarge: CGFloat = 0
    static let radiusXL: CGFloat = 0

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Brutalist Border Width
    static let borderWidth: CGFloat = 2
    static let borderWidthThick: CGFloat = 3
    static let borderWidthBold: CGFloat = 4
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
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

// MARK: - Brutalist View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.border, lineWidth: AppTheme.borderWidth)
            )
    }
}

struct SurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.border, lineWidth: AppTheme.borderWidth)
            )
    }
}

struct AccentCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.sakuraPink, lineWidth: AppTheme.borderWidthThick)
            )
    }
}

/// Bold card with a thick colored left accent bar
struct AccentBarCardStyle: ViewModifier {
    let accentColor: Color

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 5)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.card)
        .overlay(
            Rectangle()
                .stroke(AppTheme.border, lineWidth: AppTheme.borderWidth)
        )
    }
}

/// Glitch-offset card — a shadow rectangle behind for depth
struct GlitchCardStyle: ViewModifier {
    let glitchColor: Color
    let offset: CGFloat

    init(glitchColor: Color = AppTheme.sakuraPink, offset: CGFloat = 5) {
        self.glitchColor = glitchColor
        self.offset = offset
    }

    func body(content: Content) -> some View {
        ZStack {
            Rectangle()
                .fill(glitchColor.opacity(0.3))
                .offset(x: offset, y: offset)
            content
                .background(AppTheme.card)
                .overlay(
                    Rectangle()
                        .stroke(glitchColor, lineWidth: AppTheme.borderWidthThick)
                )
        }
    }
}

/// Section header with full-width colored background
struct BoldSectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .black))
            .tracking(4)
            .foregroundStyle(color == AppTheme.card ? AppTheme.textPrimary : .white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, 10)
            .background(color)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func surfaceStyle() -> some View {
        modifier(SurfaceStyle())
    }

    func accentCardStyle() -> some View {
        modifier(AccentCardStyle())
    }

    func accentBarCard(_ color: Color) -> some View {
        modifier(AccentBarCardStyle(accentColor: color))
    }

    func glitchCard(_ color: Color = AppTheme.sakuraPink, offset: CGFloat = 5) -> some View {
        modifier(GlitchCardStyle(glitchColor: color, offset: offset))
    }
}
