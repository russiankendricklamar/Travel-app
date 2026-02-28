import SwiftUI
import SwiftData

struct MainTabView: View {
    @Query var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSideMenu = false
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    enum Tab: String {
        case dashboard
        case itinerary
        case map
        case expenses
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding || trips.isEmpty {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if let trip = trips.first {
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
                                Label("Расходы", systemImage: "yensign.circle")
                            }
                            .tag(Tab.expenses)

                    }
                    .tint(AppTheme.sakuraPink)
                    .id(palette)
                    .onAppear {
                        trip.autoCompletePastDays()
                    }

                    SideMenuView(isOpen: $showSideMenu, trip: trip)
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
