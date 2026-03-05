import SwiftUI
import SwiftData

struct MainTabView: View {
    @Query var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false
    @State private var showSideMenu = false
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    @State private var selectedTripID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    private let authManager = AuthManager.shared

    enum Tab: String {
        case dashboard
        case itinerary
        case map
        case expenses
        case journal
    }

    private var selectedTrip: Trip? {
        guard let id = selectedTripID else { return nil }
        return trips.first { $0.id == id }
    }

    var body: some View {
        Group {
            if !authManager.isSignedIn && !hasSkippedAuth {
                AuthView { result in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        switch result {
                        case .signedIn:
                            break
                        case .skipped:
                            hasSkippedAuth = true
                        }
                    }
                }
            } else if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if authManager.isLocked {
                BiometricLockView()
            } else if let trip = selectedTrip {
                ZStack {
                    TabView(selection: $selectedTab) {
                        DashboardView(trip: trip, showSideMenu: $showSideMenu)
                            .tabItem {
                                Label("Главная", systemImage: "airplane")
                            }
                            .tag(Tab.dashboard)

                        ItineraryView(trip: trip)
                            .tabItem {
                                Label("Маршрут", systemImage: "calendar")
                            }
                            .tag(Tab.itinerary)

                        TripMapView(trip: trip)
                            .tabItem {
                                Label("Карта", systemImage: "map")
                            }
                            .tag(Tab.map)

                        ExpensesView(trip: trip)
                            .tabItem {
                                Label("Расходы", systemImage: "rublesign.circle")
                            }
                            .tag(Tab.expenses)

                        JournalView(trip: trip)
                            .tabItem {
                                Label("Дневник", systemImage: "book.fill")
                            }
                            .tag(Tab.journal)

                    }
                    .tint(ColorPalette.current.accentColor)
                    .id(palette)
                    .onAppear {
                        trip.autoCompletePastDays()
                        LiveActivityManager.shared.refreshActivities(trip: trip)
                        WidgetDataProvider.updateWidgetData(trips: trips)
                        trip.migrateSortOrdersIfNeeded()
                        GeofenceManager.shared.activate(for: trip, context: modelContext)
                    }

                    SideMenuView(isOpen: $showSideMenu, trip: trip, onBack: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSideMenu = false
                            selectedTripID = nil
                            selectedTab = .dashboard
                        }
                    })
                }
            } else {
                TripsListView { trip in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTripID = trip.id
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetDataProvider.updateWidgetData(trips: trips)
                Task { await SyncManager.shared.syncIfNeeded() }
            }
        }
    }
}

#if DEBUG
#Preview {
    MainTabView()
        .modelContainer(.preview)
}
#endif
