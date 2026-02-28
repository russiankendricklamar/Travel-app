import SwiftUI
import SwiftData

struct MainTabView: View {
    @Query var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .dashboard
    @State private var seeded = false

    enum Tab: String {
        case dashboard
        case itinerary
        case map
        case expenses
        case journal
    }

    var body: some View {
        Group {
            if let trip = trips.first {
                TabView(selection: $selectedTab) {
                    DashboardView(trip: trip)
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

                    JournalView(trip: trip)
                        .tabItem {
                            Label("Дневник", systemImage: "book")
                        }
                        .tag(Tab.journal)
                }
                .tint(AppTheme.sakuraPink)
                .onAppear {
                    trip.autoCompletePastDays()
                }
            } else {
                VStack(spacing: AppTheme.spacingM) {
                    ProgressView()
                        .tint(AppTheme.sakuraPink)
                    Text("ЗАГРУЗКА...")
                        .font(.system(size: 11, weight: .black))
                        .tracking(4)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
                .onAppear {
                    if !seeded {
                        seeded = true
                        SampleData.seed(into: modelContext)
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
