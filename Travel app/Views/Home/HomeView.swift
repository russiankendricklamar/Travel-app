import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Trip.startDate) var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateSheet = false
    @State private var showBucketList = false
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showAllTrips = false
    @State private var showProfile = false
    @State private var showProfileSetup = false
    @State private var showAIWizard = false
    // Corporate mode disabled
    // @State private var showModeSwitcher = false
    // @State private var showModeTransition = false
    // @State private var pendingMode: AppMode?
    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    var onSelectTrip: ((Trip) -> Void)?

    private let authManager = AuthManager.shared
    private let profileService = ProfileService.shared

    // Corporate mode disabled
    // private var isCorporate: Bool {
    //     AppMode(rawValue: appMode) == .corporate
    // }

    private var filteredTrips: [Trip] {
        trips
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    greetingSection

                    ProfileCardView(
                        onTap: { showProfile = true },
                        onSetup: { showProfileSetup = true },
                        onLongPress: { }
                    )

                    if let hero = heroTrip {
                        HeroTripCard(trip: hero) {
                            onSelectTrip?(hero)
                        }
                    }

                    quickActions

                    if !filteredTrips.isEmpty {
                        miniStats
                    }

                    if !upcomingTrips.isEmpty {
                        tripSection(
                            title: "ПРЕДСТОЯЩИЕ",
                            trips: upcomingTrips,
                            color: AppTheme.oceanBlue
                        )
                    }

                    if !pastTrips.isEmpty {
                        tripSection(
                            title: "ПРОШЕДШИЕ",
                            trips: pastTrips,
                            color: AppTheme.textSecondary
                        )
                    }

                    if filteredTrips.isEmpty {
                        emptyState
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAllTrips = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("ГЛАВНАЯ")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateTripSheet()
            }
            .sheet(isPresented: $showBucketList) {
                BucketListView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(trip: nil)
            }
            .sheet(isPresented: $showStats) {
                TravelStatsView(trips: filteredTrips)
            }
            .sheet(isPresented: $showAllTrips) {
                TripsListView(onSelectTrip: { trip in
                    showAllTrips = false
                    onSelectTrip?(trip)
                })
            }
            .sheet(isPresented: $showProfile) {
                ProfileDetailView()
            }
            .fullScreenCover(isPresented: $showAIWizard) {
                AITripWizardView()
            }
            .fullScreenCover(isPresented: $showProfileSetup) {
                ProfileSetupView(
                    initialName: authManager.userName,
                    onComplete: { showProfileSetup = false },
                    onSkip: { showProfileSetup = false }
                )
            }
            // Corporate mode switcher disabled
            // .overlay {
            //     if showModeSwitcher {
            //         ModeSwitcherView(isPresented: $showModeSwitcher) { mode in
            //             pendingMode = mode
            //             showModeTransition = true
            //         }
            //     }
            // }
            // .overlay {
            //     if showModeTransition, let mode = pendingMode {
            //         ModeTransitionOverlay(targetMode: mode) {
            //             applyMode(mode)
            //             showModeTransition = false
            //             pendingMode = nil
            //         }
            //     }
            // }
        }
    }

    // Corporate mode disabled
    // private func applyMode(_ mode: AppMode) {
    //     if mode == .corporate {
    //         let currentMode = AppMode(rawValue: appMode) ?? .personal
    //         if currentMode == .personal {
    //             UserDefaults.standard.set(palette, forKey: "savedPersonalPalette")
    //         }
    //         appMode = AppMode.corporate.rawValue
    //         palette = ColorPalette.corporateCobalt.rawValue
    //     } else {
    //         let saved = UserDefaults.standard.string(forKey: "savedPersonalPalette") ?? ColorPalette.sakura.rawValue
    //         appMode = AppMode.personal.rawValue
    //         palette = saved
    //     }
    //     UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    // }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            Text(dateText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.spacingS)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Доброе утро"
        case 12..<18: timeGreeting = "Добрый день"
        case 18..<23: timeGreeting = "Добрый вечер"
        default: timeGreeting = "Доброй ночи"
        }
        if let name = authManager.userName, !name.isEmpty {
            return "\(timeGreeting), \(name)"
        }
        return timeGreeting
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: Date()).capitalized
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: AppTheme.spacingS) {
            quickActionButton(
                icon: "plus.circle.fill",
                label: "Новая поездка",
                color: AppTheme.sakuraPink
            ) {
                showCreateSheet = true
            }

            quickActionButton(
                icon: "sparkles",
                label: "AI поездка",
                color: AppTheme.sakuraPink
            ) {
                showAIWizard = true
            }

            quickActionButton(
                icon: "bookmark.fill",
                label: "Желания",
                color: AppTheme.templeGold
            ) {
                showBucketList = true
            }
        }
    }

    private func quickActionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(color.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mini Stats

    private var miniStats: some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack(spacing: 0) {
                statItem(
                    value: "\(pastTrips(all: trips).count)",
                    label: "ПОЕЗДОК",
                    icon: "airplane"
                )
                Divider().frame(height: 40)
                statItem(
                    value: "\(pastCountries.count)",
                    label: "СТРАН",
                    icon: "globe"
                )
                Divider().frame(height: 40)
                statItem(
                    value: "\(pastCities.count)",
                    label: "ГОРОДОВ",
                    icon: "building.2"
                )
            }
            .padding(.vertical, AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
            )

            Button {
                showStats = true
            } label: {
                HStack(spacing: 6) {
                    Text("ПОДРОБНАЯ СТАТИСТИКА")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.sakuraPink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sakuraPink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trip Sections

    private func tripSection(title: String, trips: [Trip], color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: title, color: color)

            ForEach(trips) { trip in
                Button {
                    onSelectTrip?(trip)
                } label: {
                    TripCardView(trip: trip)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteTrip(trip)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer(minLength: 40)

            Image(systemName: "airplane.circle")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))

            Text("НЕТ ПОЕЗДОК")
                .font(.system(size: 14, weight: .bold))
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("Создайте первую поездку")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            Button {
                showCreateSheet = true
            } label: {
                Text("СОЗДАТЬ")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, AppTheme.spacingXL)

            Spacer(minLength: 40)
        }
    }

    // MARK: - Computed

    private var heroTrip: Trip? {
        filteredTrips.first(where: \.isActive)
            ?? filteredTrips.filter(\.isUpcoming).sorted(by: { $0.startDate < $1.startDate }).first
            ?? filteredTrips.filter(\.isPast).sorted(by: { $0.endDate > $1.endDate }).first
    }

    private var upcomingTrips: [Trip] {
        let hero = heroTrip
        return filteredTrips.filter { $0.isUpcoming && $0.id != hero?.id }
    }

    private var pastTrips: [Trip] {
        let hero = heroTrip
        return filteredTrips.filter { $0.isPast && $0.id != hero?.id }
    }

    private func pastTrips(all: [Trip]) -> [Trip] {
        all.filter(\.isPast)
    }

    private var pastCountries: Set<String> {
        var countries = Set(filteredTrips.filter(\.isPast).flatMap(\.countries))
        let profileCountries = ProfileService.shared.profile?.visitedCountries ?? []
        countries.formUnion(profileCountries)
        return countries
    }

    private var pastCities: Set<String> {
        Set(filteredTrips.filter(\.isPast).flatMap(\.days).map(\.cityName))
    }

    private func deleteTrip(_ trip: Trip) {
        modelContext.delete(trip)
        try? modelContext.save()
    }
}
