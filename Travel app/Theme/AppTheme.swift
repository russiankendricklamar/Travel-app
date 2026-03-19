import SwiftUI

enum AppTheme {
    // MARK: - Accent Colors — palette-aware
    static var sakuraPink: Color { ColorPalette.current.accentColor }
    static var sakuraLight: Color { sakuraPink.opacity(0.3) }
    static let toriiRed = Color(hex: "E11D48")
    static let templeGold = Color(hex: "D97706")
    static let bambooGreen = Color(hex: "16A34A")
    static var oceanBlue: Color { sakuraPink }
    static let indigoPurple = Color(hex: "6366F1")

    // MARK: - Soft Accent Variants
    static let softPink = Color(hex: "FDF2F8")
    static let softRed = Color(hex: "FFF1F2")
    static let softGold = Color(hex: "FFFBEB")
    static let softGreen = Color(hex: "F0FDF4")
    static var softBlue: Color { sakuraPink.opacity(0.08) }

    // MARK: - Legacy Colors (kept for backward compat, prefer .primary/.secondary)
    static let background = Color(hex: "FEFCFD")
    static let surface = Color(hex: "FDF2F8")
    static let card = Color(hex: "FFFFFF")
    static let cardHover = Color(hex: "FFF5F9")
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "64748B")
    static let textMuted = Color(hex: "94A3B8")

    // MARK: - Semantic Colors
    static var primary: Color { sakuraPink }
    static let success = bambooGreen
    static let warning = templeGold
    static var info: Color { sakuraPink }

    // MARK: - Border
    static let border = Color(hex: "F3D5E4")
    static var borderAccent: Color { sakuraPink }

    // MARK: - Glassmorphism Radii
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 20
    static let radiusXL: CGFloat = 24

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Glass Border Widths
    static let borderWidth: CGFloat = 0.5
    static let borderWidthThick: CGFloat = 1.0
    static let borderWidthBold: CGFloat = 1.5

    // MARK: - New Category Colors (non-blue palette)
    static let pinkGallery = Color(hex: "EC4899")
    static let amberPalace = Color(hex: "B45309")
    static let greenDark = Color(hex: "15803D")
    static let limeGarden = Color(hex: "65A30D")
    static let slateMountain = Color(hex: "475569")
    static let redSport = Color(hex: "DC2626")
    static let orangeStadium = Color(hex: "EA580C")
    static let roseMuseum = Color(hex: "BE185D")
    static let oliveViewpoint = Color(hex: "4D7C0F")

    // MARK: - Category Colors
    static func categoryColor(for category: String) -> Color {
        switch category {
        case "Храм", "Святилище": return templeGold
        case "Еда": return toriiRed
        case "Шопинг": return sakuraPink
        case "Природа": return bambooGreen
        case "Культура": return templeGold
        case "Транспорт": return slateMountain
        case "Жильё": return amberPalace
        case "Развлечения": return sakuraPink
        case "Музей": return roseMuseum
        case "Галерея": return pinkGallery
        case "Дворец": return amberPalace
        case "Парк": return greenDark
        case "Сад": return limeGarden
        case "Озеро": return bambooGreen
        case "Горы": return slateMountain
        case "Аэропорт": return slateMountain
        case "Вокзал": return slateMountain
        case "Метро": return slateMountain
        case "Спорт": return redSport
        case "Стадион": return orangeStadium
        case "Смотровая": return oliveViewpoint
        default: return textMuted
        }
    }

    // MARK: - Expense Category Colors
    static func expenseColor(for category: ExpenseCategory) -> Color {
        switch category {
        case .food: return toriiRed
        case .transport: return slateMountain
        case .accommodation: return amberPalace
        case .activities: return sakuraPink
        case .shopping: return templeGold
        case .other: return textMuted
        }
    }

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

// MARK: - Glassmorphism View Modifiers

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(Color.white.opacity(scheme == .dark ? 0.12 : 0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

struct SurfaceStyle: ViewModifier {
    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.2), lineWidth: 0.5)
            )
    }
}

struct AccentCardStyle: ViewModifier {
    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink.opacity(0.6), AppTheme.sakuraPink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppTheme.sakuraPink.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

struct AccentBarCardStyle: ViewModifier {
    let accentColor: Color
    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(scheme == .dark ? 0.1 : 0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct GlitchCardStyle: ViewModifier {
    let glitchColor: Color
    let offset: CGFloat

    init(glitchColor: Color = AppTheme.sakuraPink, offset: CGFloat = 5) {
        self.glitchColor = glitchColor
        self.offset = offset
    }

    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .strokeBorder(
                        LinearGradient(
                            colors: [glitchColor.opacity(0.5), glitchColor.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: glitchColor.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct BoldSectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 16)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
    }
}

// MARK: - Gradient Background

struct GradientBackground: ViewModifier {
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    private var resolved: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    LinearGradient(
                        colors: resolved.backgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Corporate mode disabled
                    // if resolved.isCorporate {
                    //     CorporateWaveBackground()
                    // }
                }
                .ignoresSafeArea()
            }
    }
}

// MARK: - View Extensions

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

    func sakuraGradientBackground() -> some View {
        modifier(GradientBackground())
    }
}
