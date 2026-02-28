import SwiftUI
import SwiftData

@main
struct Travel_appApp: App {
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    private var resolvedScheme: ColorScheme {
        (ColorPalette(rawValue: palette) ?? .sakura).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(resolvedScheme)
        }
        .modelContainer(for: Trip.self)
    }
}
