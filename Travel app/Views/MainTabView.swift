import SwiftUI

struct MainTabView: View {
    let store: TripStore
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String {
        case dashboard
        case itinerary
        case map
        case expenses
        case journal
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(store: store)
                .tabItem {
                    Label("Главная", systemImage: "airplane")
                }
                .tag(Tab.dashboard)

            ItineraryView(store: store)
                .tabItem {
                    Label("Маршрут", systemImage: "calendar")
                }
                .tag(Tab.itinerary)

            TripMapView(store: store)
                .tabItem {
                    Label("Карта", systemImage: "map")
                }
                .tag(Tab.map)

            ExpensesView(store: store)
                .tabItem {
                    Label("Расходы", systemImage: "yensign.circle")
                }
                .tag(Tab.expenses)

            JournalView(store: store)
                .tabItem {
                    Label("Дневник", systemImage: "book")
                }
                .tag(Tab.journal)
        }
        .tint(AppTheme.sakuraPink)
    }
}

#Preview {
    MainTabView(store: TripStore())
}
