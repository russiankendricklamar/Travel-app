import SwiftUI
import SwiftData

@main
struct Travel_appApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: Trip.self)
    }
}
