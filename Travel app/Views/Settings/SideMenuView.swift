import SwiftUI

struct SideMenuView: View {
    @Binding var isOpen: Bool
    let trip: Trip
    @State private var showSettings = false
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    var body: some View {
        ZStack {
            if isOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isOpen = false
                        }
                    }
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    profileHeader
                    Divider().padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 4) {
                            menuButton(icon: "gearshape.fill", title: "Настройки") {
                                showSettings = true
                            }
                        }
                        .padding()
                    }

                    Spacer()
                    versionFooter
                }
                .frame(width: 300)
                .background(.ultraThickMaterial)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: AppTheme.radiusXL,
                        topTrailingRadius: AppTheme.radiusXL
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 24, x: 8, y: 0)
                .offset(x: isOpen ? 0 : -320)
                .id(palette)

                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isOpen)
        .sheet(isPresented: $showSettings) {
            SettingsView(trip: trip)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            Text(trip.destination)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(tripDatesString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingL)
        .padding(.top, AppTheme.spacingM)
    }

    private var tripDatesString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) — \(end)"
    }

    // MARK: - Menu Button

    private func menuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        HStack {
            Spacer()
            Text("v1.0.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.bottom, AppTheme.spacingL)
    }
}
