import SwiftUI
import SwiftData
import UserNotifications

@main
struct Travel_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private let authManager = AuthManager.shared

    init() {
        Secrets.migrateFromAppStorage()
        OfflineCacheManager.shared.startMonitoring()
    }

    private var resolvedScheme: ColorScheme {
        (ColorPalette(rawValue: palette) ?? .sakura).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(resolvedScheme)
        }
        .modelContainer(for: [Trip.self, JournalEntry.self, BucketListItem.self, PackingItem.self, OfflineMapCache.self])
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background && newPhase == .active {
                authManager.lockIfNeeded()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerGeofenceCategory()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == "MARK_VISITED" {
            // Place marking is handled by GeofenceManager's auto-mark feature
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
