import SwiftUI
import SwiftData

struct MainTabView: View {
    @Query var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSideMenu = false
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    @State private var selectedTrip: Trip?

    enum Tab: String {
        case dashboard
        case itinerary
        case map
        case expenses
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
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

                    }
                    .tint(AppTheme.sakuraPink)
                    .id(palette)
                    .onAppear {
                        trip.autoCompletePastDays()
                        LiveActivityManager.shared.refreshActivities(trip: trip)
                    }

                    SideMenuView(isOpen: $showSideMenu, trip: trip, onBack: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSideMenu = false
                            selectedTrip = nil
                            selectedTab = .dashboard
                        }
                    })
                }
            } else {
                TripsListView { trip in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTrip = trip
                    }
                }
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
