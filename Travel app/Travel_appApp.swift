import SwiftUI
import SwiftData

@main
struct Travel_appApp: App {
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private let authManager = AuthManager.shared

    init() {
        Secrets.migrateFromAppStorage()
    }

    private var resolvedScheme: ColorScheme {
        (ColorPalette(rawValue: palette) ?? .sakura).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(resolvedScheme)
        }
        .modelContainer(for: Trip.self)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background && newPhase == .active {
                authManager.lockIfNeeded()
            }
        }
    }
}
