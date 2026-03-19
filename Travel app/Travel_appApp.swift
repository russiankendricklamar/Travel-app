import SwiftUI
import SwiftData
import UserNotifications
import Supabase

@main
struct Travel_appApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @Environment(\.scenePhase) private var scenePhase

    private let authManager = AuthManager.shared
    private let supabase = SupabaseManager.shared
    private let sharedModelContainer: ModelContainer

    init() {
        Secrets.migrateFromAppStorage()
        OfflineCacheManager.shared.startMonitoring()
        // Force-init Supabase client eagerly
        _ = supabase.client

        // Create shared model container and pass to SyncManager
        let container = try! ModelContainer(for: Trip.self, TripPhoto.self, JournalEntry.self, BucketListItem.self, PackingItem.self, OfflineMapCache.self)
        self.sharedModelContainer = container
        SyncManager.shared.modelContainer = container
        // Corporate mode disabled
        // if AppMode.current == .corporate {
        //     let current = ColorPalette.current
        //     if !current.isCorporate {
        //         UserDefaults.standard.set(ColorPalette.corporateCobalt.rawValue, forKey: "colorPalette")
        //     }
        // }
    }

    private var resolvedScheme: ColorScheme {
        (ColorPalette(rawValue: palette) ?? .sakura).colorScheme
    }

    private var resolvedLocale: Locale {
        switch appLanguage {
        case "ru": return Locale(identifier: "ru")
        case "en": return Locale(identifier: "en")
        default: return .current
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.locale, resolvedLocale)
                .preferredColorScheme(resolvedScheme)
                .onOpenURL { url in
                    guard url.scheme == SupabaseAuthService.oauthCallbackScheme else { return }
                    Task {
                        try? await SupabaseAuthService.shared.handleOAuthCallback(url: url)
                        authManager.refreshAuthState()
                    }
                }
                .task {
                    _ = try? await SupabaseAuthService.shared.restoreSession()
                    authManager.refreshAuthState()
                    if authManager.isSignedIn {
                        await SyncManager.shared.syncIfNeeded()
                    }
                    CurrencyService.shared.startAutoRefresh()

                    // Resume GPS tracking if it was active before app was killed
                    let context = sharedModelContainer.mainContext
                    LocationManager.shared.resumeTrackingIfNeeded(context: context)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background && newPhase == .active {
                authManager.lockIfNeeded()
            }
            if newPhase == .active {
                Task {
                    await SyncManager.shared.syncIfNeeded()
                }
                CurrencyService.shared.handleScenePhase(active: true)
            }
            if newPhase == .background {
                CurrencyService.shared.handleScenePhase(active: false)
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
