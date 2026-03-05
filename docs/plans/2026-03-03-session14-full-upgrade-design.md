# Session 14 — Full Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete all pending items: Keychain migration, formatRub consolidation, AviationStack flight tracking, photo attachments, app icon, test infrastructure, and housekeeping.

**Architecture:** SwiftUI + SwiftData iOS app. Services layer for API calls. KeychainHelper for secrets. @Model for data. Glassmorphism UI theme.

**Tech Stack:** SwiftUI, SwiftData, PhotosUI, Security (Keychain), XCTest, URLSession

---

### Task 1: Migrate API Keys from @AppStorage to Keychain

**Files:**
- Modify: `Travel app/Config/Secrets.swift`
- Modify: `Travel app/Views/Settings/SettingsView.swift:59-60, 746-818`

**Step 1: Extend Secrets.swift with Claude and OpenAI key management**

Add to `Secrets.swift` after the Groq methods:

```swift
static var claudeApiKey: String {
    KeychainHelper.readString(key: "claudeApiKey") ?? ""
}

static func setClaudeApiKey(_ key: String) {
    KeychainHelper.save(key: "claudeApiKey", string: key)
}

static var openaiApiKey: String {
    KeychainHelper.readString(key: "openaiApiKey") ?? ""
}

static func setOpenaiApiKey(_ key: String) {
    KeychainHelper.save(key: "openaiApiKey", string: key)
}
```

**Step 2: Update SettingsView to use Keychain instead of @AppStorage**

Replace lines 59-60:
```swift
// OLD:
@AppStorage("claudeApiKey") private var claudeApiKey = ""
@AppStorage("openaiApiKey") private var openaiApiKey = ""

// NEW:
@State private var claudeApiKey = Secrets.claudeApiKey
@State private var openaiApiKey = Secrets.openaiApiKey
```

Update `aiKeyField()` (line 807) to save to Keychain on change. Add `.onChange` modifiers after the ai provider section:

```swift
.onChange(of: claudeApiKey) { _, newValue in
    Secrets.setClaudeApiKey(newValue)
}
.onChange(of: openaiApiKey) { _, newValue in
    Secrets.setOpenaiApiKey(newValue)
}
```

**Step 3: Add one-time migration from @AppStorage to Keychain**

Add to `Secrets.swift`:

```swift
static func migrateFromAppStorage() {
    let defaults = UserDefaults.standard
    if let claude = defaults.string(forKey: "claudeApiKey"), !claude.isEmpty {
        setClaudeApiKey(claude)
        defaults.removeObject(forKey: "claudeApiKey")
    }
    if let openai = defaults.string(forKey: "openaiApiKey"), !openai.isEmpty {
        setOpenaiApiKey(openai)
        defaults.removeObject(forKey: "openaiApiKey")
    }
}
```

Call `Secrets.migrateFromAppStorage()` in `Travel_appApp.init()`.

**Step 4: Remove hardcoded fallback Groq key from Secrets.swift**

Replace line 4:
```swift
// OLD:
private static let fallbackGroqKey = "<REDACTED>"

// NEW:
private static let fallbackGroqKey = ""
```

**Step 5: Also check PlaceInfoService and RecommendationService for direct @AppStorage reads**

Verify these services read keys from `Secrets` (they already do via GroqService.shared.hasApiKey). Check Claude/OpenAI paths similarly — they should read from `Secrets.claudeApiKey` / `Secrets.openaiApiKey` rather than @AppStorage.

**Step 6: Build and verify**

Run: `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 16 Pro Max"`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add Travel\ app/Config/Secrets.swift Travel\ app/Views/Settings/SettingsView.swift Travel\ app/Travel_appApp.swift
git commit -m "fix: migrate API keys from @AppStorage to Keychain"
```

---

### Task 2: Consolidate formatRub() Duplicates

**Files:**
- Modify: `Travel app/Services/CurrencyService.swift:95-103`
- Modify: `Travel app/Views/Dashboard/DashboardBudgetSection.swift:7-13`
- Modify: `Travel app/Views/Dashboard/DashboardActiveSection.swift:259-265`
- Modify: `Travel app/Views/Dashboard/DashboardView.swift:288-294`

**Step 1: Add static formatRub convenience method to CurrencyService**

Add to `CurrencyService.swift` after the `format()` method (after line 103):

```swift
/// Shorthand: format amount as RUB with ₽ symbol and space grouping
static func formatRub(_ amount: Double) -> String {
    shared.format(amount, currency: "RUB")
}
```

**Step 2: Remove duplicate from DashboardBudgetSection.swift**

Delete lines 7-13 (the private formatRub method). Replace all `formatRub(` calls with `CurrencyService.formatRub(` in the file (lines 29, 69, 83, 139).

**Step 3: Remove duplicate from DashboardActiveSection.swift**

Delete lines 259-265 (the private formatRub method). Replace `formatRub(` on line 95 and line 231 with `CurrencyService.formatRub(`.

**Step 4: Remove duplicate from DashboardView.swift**

Delete lines 288-294 (the private formatRub method). Replace `formatRub(` on line 242 with `CurrencyService.formatRub(`.

**Step 5: Build and verify**

Run: `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 16 Pro Max"`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Travel\ app/Services/CurrencyService.swift Travel\ app/Views/Dashboard/DashboardBudgetSection.swift Travel\ app/Views/Dashboard/DashboardActiveSection.swift Travel\ app/Views/Dashboard/DashboardView.swift
git commit -m "refactor: consolidate formatRub() into CurrencyService"
```

---

### Task 3: AviationStack Flight Tracking Service

**Files:**
- Create: `Travel app/Services/AviationStackService.swift`
- Modify: `Travel app/Config/Secrets.swift` (add aviationstack key)
- Modify: `Travel app/Views/Settings/SettingsView.swift` (add key field)

**Step 1: Add AviationStack key to Secrets.swift**

```swift
static var aviationStackApiKey: String {
    KeychainHelper.readString(key: "aviationStackApiKey") ?? ""
}

static func setAviationStackApiKey(_ key: String) {
    KeychainHelper.save(key: "aviationStackApiKey", string: key)
}
```

**Step 2: Create AviationStackService.swift**

```swift
import Foundation

@Observable
final class AviationStackService {
    static let shared = AviationStackService()

    var isLoading = false
    var lastError: String?
    var cachedFlight: FlightData?
    private var lastFetchedNumber: String?
    private var lastFetchDate: Date?
    private let cacheInterval: TimeInterval = 300 // 5 min

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    var hasApiKey: Bool {
        !Secrets.aviationStackApiKey.isEmpty
    }

    func fetchFlight(number: String) async -> FlightData? {
        let cleaned = number.replacingOccurrences(of: " ", with: "").uppercased()

        // Cache check
        if let cached = cachedFlight,
           lastFetchedNumber == cleaned,
           let lastDate = lastFetchDate,
           Date().timeIntervalSince(lastDate) < cacheInterval {
            return cached
        }

        guard hasApiKey else {
            lastError = "API-ключ AviationStack не настроен"
            return nil
        }

        isLoading = true
        lastError = nil

        defer { isLoading = false }

        do {
            let key = Secrets.aviationStackApiKey
            let urlString = "http://api.aviationstack.com/v1/flights?access_key=\(key)&flight_iata=\(cleaned)"
            guard let url = URL(string: urlString) else {
                lastError = "Неверный номер рейса"
                return nil
            }

            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                lastError = "Ошибка сервера"
                return nil
            }

            let decoded = try JSONDecoder().decode(AviationStackResponse.self, from: data)

            guard let first = decoded.data.first else {
                lastError = "Рейс не найден"
                return nil
            }

            let flight = FlightData(from: first)
            cachedFlight = flight
            lastFetchedNumber = cleaned
            lastFetchDate = Date()
            return flight
        } catch {
            lastError = "Не удалось загрузить данные о рейсе"
            return nil
        }
    }
}

// MARK: - Public Model

struct FlightData {
    let flightIata: String
    let airlineName: String
    let status: String // scheduled, active, landed, cancelled, etc.

    let departureAirport: String
    let departureIata: String
    let departureTime: Date?
    let departureEstimated: Date?
    let departureGate: String?
    let departureTerminal: String?
    let departureDelay: Int? // minutes

    let arrivalAirport: String
    let arrivalIata: String
    let arrivalTime: Date?
    let arrivalEstimated: Date?
    let arrivalGate: String?
    let arrivalTerminal: String?
    let arrivalDelay: Int? // minutes

    var isDelayed: Bool {
        (departureDelay ?? 0) > 0 || (arrivalDelay ?? 0) > 0
    }

    var statusLocalized: String {
        switch status {
        case "scheduled": return "По расписанию"
        case "active": return "В воздухе"
        case "landed": return "Прилетел"
        case "cancelled": return "Отменён"
        case "diverted": return "Перенаправлен"
        default: return status.capitalized
        }
    }
}

// MARK: - API Response Models

private struct AviationStackResponse: Codable {
    let data: [FlightEntry]
}

private struct FlightEntry: Codable {
    let flight_date: String?
    let flight_status: String?
    let departure: AirportInfo?
    let arrival: AirportInfo?
    let airline: AirlineInfo?
    let flight: FlightInfo?
}

private struct AirportInfo: Codable {
    let airport: String?
    let iata: String?
    let scheduled: String?
    let estimated: String?
    let gate: String?
    let terminal: String?
    let delay: Int?
}

private struct AirlineInfo: Codable {
    let name: String?
    let iata: String?
}

private struct FlightInfo: Codable {
    let iata: String?
}

// MARK: - Mapping

extension FlightData {
    init(from entry: FlightEntry) {
        self.flightIata = entry.flight?.iata ?? ""
        self.airlineName = entry.airline?.name ?? ""
        self.status = entry.flight_status ?? "scheduled"

        self.departureAirport = entry.departure?.airport ?? ""
        self.departureIata = entry.departure?.iata ?? ""
        self.departureTime = Self.parseDate(entry.departure?.scheduled)
        self.departureEstimated = Self.parseDate(entry.departure?.estimated)
        self.departureGate = entry.departure?.gate
        self.departureTerminal = entry.departure?.terminal
        self.departureDelay = entry.departure?.delay

        self.arrivalAirport = entry.arrival?.airport ?? ""
        self.arrivalIata = entry.arrival?.iata ?? ""
        self.arrivalTime = Self.parseDate(entry.arrival?.scheduled)
        self.arrivalEstimated = Self.parseDate(entry.arrival?.estimated)
        self.arrivalGate = entry.arrival?.gate
        self.arrivalTerminal = entry.arrival?.terminal
        self.arrivalDelay = entry.arrival?.delay
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
```

**Step 3: Add AviationStack API key field in SettingsView**

In the `aiProviderSection`, after the OpenAI key field block (~line 762), add an AviationStack section. Or better: add a new section "АВИА-ТРЕКИНГ" between AI Provider and Language sections.

Add `@State private var aviationStackKey = Secrets.aviationStackApiKey` to state vars.

Add section in body between aiProviderSection and languageSection:

```swift
flightTrackingSection
```

Add the view:

```swift
private var flightTrackingSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        sectionLabel("АВИА-ТРЕКИНГ", icon: "airplane")

        VStack(alignment: .leading, spacing: 8) {
            SecureField("API-ключ AviationStack", text: $aviationStackKey)
                .font(.system(size: 13, design: .monospaced))
                .textFieldStyle(GlassTextFieldStyle())
                .onChange(of: aviationStackKey) { _, newValue in
                    Secrets.setAviationStackApiKey(newValue)
                }

            Text("Бесплатно: 100 запросов/мес. aviationstack.com")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }
    .padding(AppTheme.spacingM)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
    .overlay(
        RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
    )
}
```

**Step 4: Build and verify**

**Step 5: Commit**

```bash
git add Travel\ app/Services/AviationStackService.swift Travel\ app/Config/Secrets.swift Travel\ app/Views/Settings/SettingsView.swift
git commit -m "feat: add AviationStack flight tracking service"
```

---

### Task 4: Update Flight Tracking UI with Real Data

**Files:**
- Modify: `Travel app/Views/Dashboard/DashboardFlightTrackingSection.swift`

**Step 1: Rewrite DashboardFlightTrackingSection to use AviationStackService**

Replace the entire file. Key changes:
- Add `@State private var flightData: FlightData?` and `private let service = AviationStackService.shared`
- On appear: if `service.hasApiKey && trip.flightNumber != nil`, fetch real data
- If no API key or fetch fails: fall back to existing hardcoded behavior
- Display real departure/arrival IATA codes, times, gate, terminal, delay badge
- Keep existing glassmorphism styling
- Show loading spinner during fetch

The view should gracefully degrade — if no API key is configured, it still shows the existing UI based on trip.flightDate.

**Step 2: Build and verify**

**Step 3: Commit**

```bash
git add Travel\ app/Views/Dashboard/DashboardFlightTrackingSection.swift
git commit -m "feat: integrate AviationStack data into flight tracking card"
```

---

### Task 5: Photo Model and Relationships

**Files:**
- Create: `Travel app/Models/TripPhoto.swift`
- Modify: `Travel app/Models/TripModels.swift` (add photos to Place, TripDay)
- Modify: `Travel app/Models/TripModels.swift:518-543` (add photos to Expense)
- Modify: `Travel app/Travel_appApp.swift:20` (update modelContainer)

**Step 1: Create TripPhoto model**

```swift
import Foundation
import SwiftUI
import SwiftData

@Model
final class TripPhoto {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var caption: String
    var createdAt: Date

    var place: Place?
    var expense: Expense?
    var day: TripDay?

    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data? = nil,
        caption: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.caption = caption
        self.createdAt = createdAt
    }
}
```

Note: `@Attribute(.externalStorage)` tells SwiftData to store large blobs outside the SQLite row for performance.

**Step 2: Add relationships to Place, TripDay, Expense**

In `TripModels.swift`:

Add to Place (after `var day: TripDay?` ~line 457):
```swift
@Relationship(deleteRule: .cascade, inverse: \TripPhoto.place)
var photos: [TripPhoto] = []
```

Add to TripDay (before `init` ~line 218):
```swift
@Relationship(deleteRule: .cascade, inverse: \TripPhoto.day)
var photos: [TripPhoto] = []
```

Add to Expense (after `var trip: Trip?` ~line 527):
```swift
@Relationship(deleteRule: .cascade, inverse: \TripPhoto.expense)
var photos: [TripPhoto] = []
```

**Step 3: Update ModelContainer (optional — SwiftData auto-discovers related models)**

SwiftData should auto-discover TripPhoto through the relationships. But verify by building.

**Step 4: Build and verify**

**Step 5: Commit**

```bash
git add Travel\ app/Models/TripPhoto.swift Travel\ app/Models/TripModels.swift
git commit -m "feat: add TripPhoto model with Place/Day/Expense relationships"
```

---

### Task 6: Photo Picker and Grid Component

**Files:**
- Create: `Travel app/Views/Shared/PhotoGridView.swift`
- Create: `Travel app/Views/Shared/PhotoDetailView.swift`

**Step 1: Create PhotoGridView — reusable photo grid with add/delete**

```swift
import SwiftUI
import PhotosUI
import SwiftData

struct PhotoGridView: View {
    @Bindable var photos: PhotoCollection
    @Environment(\.modelContext) private var modelContext

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedPhoto: TripPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("ФОТО")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                Text("\(photos.items.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                // Existing photos
                ForEach(photos.items) { photo in
                    photoThumbnail(photo)
                }

                // Add button
                addPhotoButton
            }
        }
    }

    private func photoThumbnail(_ photo: TripPhoto) -> some View {
        Group {
            if let uiImage = UIImage(data: photo.thumbnailData ?? photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onTapGesture {
            selectedPhoto = photo
        }
        .contextMenu {
            Button(role: .destructive) {
                deletePhoto(photo)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }

    private var addPhotoButton: some View {
        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("Добавить")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 1)
            )
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                for item in newItems {
                    await loadPhoto(from: item)
                }
                selectedItems = []
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        // Compress to max 800px
        let maxDimension: CGFloat = 800
        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let compressed = renderer.jpegData(withCompressionQuality: 0.7) { ctx in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        // Thumbnail: 200px
        let thumbScale = min(200 / uiImage.size.width, 200 / uiImage.size.height, 1.0)
        let thumbSize = CGSize(width: uiImage.size.width * thumbScale, height: uiImage.size.height * thumbScale)
        let thumbRenderer = UIGraphicsImageRenderer(size: thumbSize)
        let thumbnail = thumbRenderer.jpegData(withCompressionQuality: 0.5) { ctx in
            uiImage.draw(in: CGRect(origin: .zero, size: thumbSize))
        }

        let photo = TripPhoto(imageData: compressed, thumbnailData: thumbnail)
        photos.append(photo)
        try? modelContext.save()
    }

    private func deletePhoto(_ photo: TripPhoto) {
        photos.remove(photo)
        modelContext.delete(photo)
        try? modelContext.save()
    }
}

// MARK: - PhotoCollection Protocol

protocol PhotoCollection {
    var items: [TripPhoto] { get }
    mutating func append(_ photo: TripPhoto)
    mutating func remove(_ photo: TripPhoto)
}
```

Note: PhotoCollection protocol is needed because Place, TripDay, and Expense all have `photos` arrays but are different types. We'll use wrapper structs or pass arrays with closures. Alternative: just pass a binding. Let's simplify — use direct arrays with closures in the actual views instead of a protocol.

**REVISED approach**: Simpler — pass binding to photos array + add/remove closures.

```swift
struct PhotoGridView: View {
    let photos: [TripPhoto]
    let onAdd: (TripPhoto) -> Void
    let onDelete: (TripPhoto) -> Void
    // ... rest of implementation uses these closures
}
```

**Step 2: Create PhotoDetailView for fullscreen viewing**

Simple fullscreen image viewer with dismiss gesture.

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add Travel\ app/Views/Shared/PhotoGridView.swift Travel\ app/Views/Shared/PhotoDetailView.swift
git commit -m "feat: add PhotoGridView and PhotoDetailView components"
```

---

### Task 7: Integrate Photos into AddPlaceSheet, AddExpenseSheet, TripDayDetailView

**Files:**
- Modify: `Travel app/Views/Itinerary/AddPlaceSheet.swift`
- Modify: `Travel app/Views/Expenses/AddExpenseSheet.swift`

**Step 1: Add PhotoGridView to AddPlaceSheet**

After the notes field (~line 105), add:
```swift
if let place = editing {
    PhotoGridView(
        photos: place.photos,
        onAdd: { photo in
            place.photos.append(photo)
        },
        onDelete: { photo in
            place.photos.removeAll { $0.id == photo.id }
            modelContext.delete(photo)
        }
    )
}
```

Note: Only show for editing mode (photos need a saved Place to attach to). For new places, photos can be added after initial save.

**Step 2: Add PhotoGridView to AddExpenseSheet**

Similar approach — show for editing mode.

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add Travel\ app/Views/Itinerary/AddPlaceSheet.swift Travel\ app/Views/Expenses/AddExpenseSheet.swift
git commit -m "feat: integrate photo attachments in place and expense editors"
```

---

### Task 8: App Icon Setup

**Files:**
- Modify: `Travel app/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Verify current 1024x1024 icon exists**

The current setup uses a single universal 1024x1024. Modern Xcode (15+) auto-generates all sizes from this. The `Contents.json` just needs the universal entry, which it already has.

Check if there are compilation warnings about missing icons. If not, this is already sufficient for iOS.

**Step 2: If icon needs updating** — this requires a design asset. Note for user: provide a new 1024x1024 PNG if desired.

**Step 3: Commit only if changes made**

---

### Task 9: Test Infrastructure

**Files:**
- Create directory: `Travel appTests/`
- Create: `Travel appTests/CurrencyServiceTests.swift`
- Create: `Travel appTests/TripModelTests.swift`
- Create: `Travel appTests/SecretsTests.swift`

**Step 1: Create test target via xcodebuild**

Since we can't easily edit .xcodeproj/project.pbxproj programmatically, we'll use `swift test` or create a Swift Package-based test approach. However, for an Xcode project, the best approach is:

Option A: Create test files and add them to a test target via Xcode (manual step for user).
Option B: Use `swift package init --type library` alongside — not ideal for this project.

**Practical approach**: Create the test files with proper `@testable import` and XCTest structure. The user adds the test target in Xcode (File > New > Target > Unit Testing Bundle). This is a 30-second Xcode operation.

**Step 2: Create CurrencyServiceTests.swift**

```swift
import XCTest
@testable import Travel_app

final class CurrencyServiceTests: XCTestCase {
    let svc = CurrencyService.shared

    func testFormatRub() {
        let result = CurrencyService.formatRub(5000)
        XCTAssertEqual(result, "₽5 000")
    }

    func testFormatRubLargeAmount() {
        let result = CurrencyService.formatRub(1_250_000)
        XCTAssertEqual(result, "₽1 250 000")
    }

    func testFormatRubZero() {
        let result = CurrencyService.formatRub(0)
        XCTAssertEqual(result, "₽0")
    }

    func testConvertSameCurrency() {
        let result = svc.convert(100, from: "RUB", to: "RUB")
        XCTAssertEqual(result, 100)
    }

    func testFormatUSD() {
        let result = svc.format(10.50, currency: "USD")
        XCTAssertTrue(result.contains("$"))
        XCTAssertTrue(result.contains("10"))
    }

    func testSupportedCurrencies() {
        XCTAssertEqual(CurrencyService.supportedCurrencies.count, 4)
        XCTAssertTrue(CurrencyService.supportedCurrencies.contains("RUB"))
        XCTAssertTrue(CurrencyService.supportedCurrencies.contains("USD"))
    }
}
```

**Step 3: Create TripModelTests.swift**

```swift
import XCTest
import SwiftData
@testable import Travel_app

final class TripModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Trip.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testTripTotalDays() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        XCTAssertEqual(trip.totalDays, 7)
    }

    func testTripIsUpcoming() {
        let trip = makeTrip(startOffset: 5, endOffset: 10)
        XCTAssertTrue(trip.isUpcoming)
        XCTAssertFalse(trip.isActive)
        XCTAssertFalse(trip.isPast)
    }

    func testTripIsPast() {
        let trip = makeTrip(startOffset: -10, endOffset: -3)
        XCTAssertTrue(trip.isPast)
        XCTAssertFalse(trip.isActive)
        XCTAssertFalse(trip.isUpcoming)
    }

    func testTripTotalSpent() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Food", amount: 500, category: .food, date: Date()),
            Expense(title: "Hotel", amount: 3000, category: .accommodation, date: Date())
        ]
        XCTAssertEqual(trip.totalSpent, 3500)
    }

    func testTripRemainingBudget() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Food", amount: 2000, category: .food, date: Date())
        ]
        XCTAssertEqual(trip.remainingBudget, 98000) // 100000 - 2000
    }

    func testTripBudgetUsedPercent() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        trip.expenses = [
            Expense(title: "Big expense", amount: 50000, category: .other, date: Date())
        ]
        XCTAssertEqual(trip.budgetUsedPercent, 0.5, accuracy: 0.01)
    }

    func testTripDayRelationship() {
        let trip = makeTrip(startOffset: 0, endOffset: 7)
        context.insert(trip)

        let day = TripDay(date: Date(), title: "Day 1", cityName: "Moscow")
        trip.days.append(day)
        try? context.save()

        XCTAssertEqual(trip.days.count, 1)
        XCTAssertEqual(trip.days.first?.cityName, "Moscow")
    }

    // MARK: - Helpers

    private func makeTrip(startOffset: Int, endOffset: Int) -> Trip {
        let cal = Calendar.current
        return Trip(
            name: "Test Trip",
            destination: "Test",
            startDate: cal.date(byAdding: .day, value: startOffset, to: Date())!,
            endDate: cal.date(byAdding: .day, value: endOffset, to: Date())!,
            budget: 100000,
            currency: "RUB",
            coverSystemImage: "airplane"
        )
    }
}
```

**Step 4: Commit test files**

```bash
git add Travel\ appTests/
git commit -m "test: add unit tests for CurrencyService and Trip model"
```

**Step 5: User action — Add test target in Xcode**

The user needs to: File > New > Target > Unit Testing Bundle > name "Travel appTests" > add the test files.

---

### Task 10: Housekeeping

**Files:**
- Modify: `Travel app/Config/Secrets.swift` (already done in Task 1 — remove fallback key)
- Note: UIBackgroundModes needs manual Xcode config

**Step 1: Verify Groq fallback key is removed (Task 1)**

Already handled: `fallbackGroqKey = ""`

**Step 2: UIBackgroundModes — document for user**

The user needs to manually enable in Xcode:
- Target > Signing & Capabilities > + Capability > Background Modes
- Check "Location updates"

This cannot be done programmatically without editing the .pbxproj and entitlements.

**Step 3: Update MEMORY.md with Session 14 summary**

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: session 14 housekeeping and memory update"
```
