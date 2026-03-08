import SwiftUI

struct SideMenuView: View {
    @Binding var isOpen: Bool
    let trip: Trip
    var onBack: (() -> Void)?
    @State private var showSettings = false
    @State private var showPackingList = false
    @State private var showAuthSheet = false
    @State private var showRecommendations = false
    @State private var showTickets = false
    @State private var isPreCaching = false
    @State private var offlineProgress: Double = 0
    @State private var showEditCountries = false
    @State private var showProfileDetail = false
    @State private var showSecureVault = false
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue
    @Environment(\.modelContext) private var modelContext

    private let authManager = AuthManager.shared
    private let profileService = ProfileService.shared

    private var resolvedPalette: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }
    private var accent: Color { resolvedPalette.accentColor }

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
                    profileButton
                    Divider().padding(.horizontal)

                    tripHeader
                    Divider().padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 4) {
                            if onBack != nil {
                                menuButton(icon: "house.fill", title: "На главную") {
                                    onBack?()
                                }
                            }

                            menuButton(icon: "bag.fill", title: "Список вещей") {
                                showPackingList = true
                            }

                            menuButton(icon: "ticket.fill", title: "Билеты") {
                                showTickets = true
                            }

                            menuButton(icon: "lock.shield.fill", title: "Документы") {
                                showSecureVault = true
                            }

                            menuButton(icon: "sparkles", title: "ИИ Рекомендации") {
                                showRecommendations = true
                            }

                            menuButton(icon: "gearshape.fill", title: "Настройки") {
                                showSettings = true
                            }
                        }
                        .padding()
                    }

                    Spacer()
                    statusFooter
                }
                .frame(width: 300)
                .background {
                    ZStack {
                        LinearGradient(
                            colors: resolvedPalette.backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Rectangle().fill(.thinMaterial)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: AppTheme.radiusXL,
                        topTrailingRadius: AppTheme.radiusXL
                    )
                )
                .shadow(color: accent.opacity(0.15), radius: 24, x: 8, y: 0)
                .tint(accent)
                .offset(x: isOpen ? 0 : -320)
                .id(palette)

                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isOpen)
        .sheet(isPresented: $showSettings) {
            SettingsView(trip: trip)
        }
        .sheet(isPresented: $showPackingList) {
            PackingListView(trip: trip)
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView { _ in
                showAuthSheet = false
            }
        }
        .sheet(isPresented: $showRecommendations) {
            NavigationStack {
                RecommendationsView(trip: trip)
            }
        }
        .sheet(isPresented: $showTickets) {
            NavigationStack {
                TicketsListView(trip: trip)
            }
        }
        .sheet(isPresented: $showEditCountries) {
            EditCountriesSheet(trip: trip)
        }
        .sheet(isPresented: $showSecureVault) {
            SecureVaultView()
        }
        .sheet(isPresented: $showProfileDetail) {
            ProfileDetailView()
        }
    }

    // MARK: - User Profile Header

    // MARK: - Profile Button

    // Corporate mode disabled
    // private var isCorporate: Bool {
    //     AppMode(rawValue: appMode) == .corporate
    // }

    private var profileButton: some View {
        Button {
            showProfileDetail = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    let initial = profileService.profile?.name.first.map(String.init)?.uppercased()
                        ?? authManager.userName?.first.map(String.init)?.uppercased()
                        ?? "?"
                    Text(initial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    // Corporate badge (disabled)
                    // if isCorporate {
                    //     Image(systemName: "building.2.fill")
                    //         .font(.system(size: 8, weight: .bold))
                    //         .foregroundStyle(.white)
                    //         .frame(width: 16, height: 16)
                    //         .background(CorporateColors.electricBlue)
                    //         .clipShape(Circle())
                    //         .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    //         .offset(x: 14, y: 14)
                    // }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profileService.profile?.name ?? authManager.userName ?? "Профиль")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let profile = profileService.profile,
                       !profile.homeCity.isEmpty || !profile.homeCountry.isEmpty {
                        Text([profile.homeCity, profile.homeCountry].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    } else if let email = authManager.userEmail {
                        Text(email)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.top, AppTheme.spacingL + AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    private var userProfileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Text(String((profileService.profile?.name ?? authManager.userName ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profileService.profile?.name ?? authManager.userName ?? String(localized: "Пользователь"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let email = authManager.userEmail {
                        Text(email)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let profile = profileService.profile,
                       !profile.homeCity.isEmpty || !profile.homeCountry.isEmpty {
                        Text([profile.homeCity, profile.homeCountry].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            // Mini badges
            if let profile = profileService.profile, profile.hasData {
                HStack(spacing: 6) {
                    profileBadge(icon: profile.chronotype.icon, text: profile.chronotype.label)
                    profileBadge(icon: profile.travelPace.icon, text: profile.travelPace.label)
                    if !profile.visitedCountries.isEmpty {
                        profileBadge(icon: "globe", text: "\(profile.visitedCountries.count)")
                    }
                }
            }

            // Edit profile button
            Button {
                showProfileDetail = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 11))
                    Text("Редактировать профиль")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(accent.opacity(0.7))
            }
        }
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.top, AppTheme.spacingL + AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    private func profileBadge(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(accent.opacity(0.6))
            Text(text)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(accent.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Trip Header

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            Button {
                showEditCountries = true
            } label: {
                HStack(spacing: 4) {
                    Text(trip.countriesDisplay)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accent.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Text(tripDatesString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.vertical, AppTheme.spacingM)
        .padding(.top, authManager.isSignedIn ? 0 : AppTheme.spacingM)
    }

    private var tripDatesString: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) — \(end)"
    }

    // MARK: - Menu Button

    private func menuButton(icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
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
        .buttonStyle(.plain)
    }

    // MARK: - Status Footer

    private var statusFooter: some View {
        let syncManager = SyncManager.shared
        let syncColor: Color = {
            switch syncManager.state {
            case .idle: return syncManager.lastSyncDate != nil ? AppTheme.bambooGreen : .secondary
            case .syncing: return AppTheme.templeGold
            case .error: return AppTheme.toriiRed
            }
        }()
        let syncText: String = {
            switch syncManager.state {
            case .idle: return syncManager.lastSyncDate != nil ? String(localized: "Синхр.") : String(localized: "Не синхр.")
            case .syncing: return String(localized: "Синхр...")
            case .error: return String(localized: "Ошибка")
            }
        }()
        let isOnline = OfflineCacheManager.shared.isOnline

        return VStack(spacing: 8) {
            // Offline cache button + progress
            Button {
                preCacheTrip()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(accent)
                    Text(isPreCaching ? "Загрузка..." : "Сохранить офлайн")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    if isPreCaching {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(isPreCaching)
            .padding(.horizontal, AppTheme.spacingM)

            if isPreCaching && offlineProgress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(accent)
                            .frame(width: geo.size.width * offlineProgress)
                    }
                }
                .frame(height: 3)
                .clipShape(Capsule())
                .padding(.horizontal, AppTheme.spacingL)
            }

            // Status indicators row
            HStack(spacing: 12) {
                // Online/Offline
                HStack(spacing: 4) {
                    Circle()
                        .fill(isOnline ? AppTheme.bambooGreen : AppTheme.toriiRed)
                        .frame(width: 6, height: 6)
                    Text(isOnline ? String(localized: "Онлайн") : String(localized: "Офлайн"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                // Sync
                HStack(spacing: 4) {
                    Circle()
                        .fill(syncColor)
                        .frame(width: 6, height: 6)
                    Text(syncText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    if syncManager.state == .syncing {
                        ProgressView()
                            .scaleEffect(0.4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, AppTheme.spacingM)
        }
    }

    private func preCacheTrip() {
        isPreCaching = true
        Task {
            await OfflineCacheManager.shared.preCacheTrip(trip, context: modelContext) { progress in
                offlineProgress = progress
            }
            isPreCaching = false
        }
    }
}
