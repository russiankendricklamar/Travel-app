# Codebase Structure

**Analysis Date:** 2026-03-20

## Directory Layout

```
Travel app/
├── Travel app/                          # Main app target
│   ├── Models/                          # SwiftData @Model entities + DTOs
│   ├── Services/                        # @Observable singletons (business logic, APIs)
│   ├── Views/                           # SwiftUI screens & components (feature-based)
│   ├── Theme/                           # Design tokens, colors, custom ViewModifiers
│   ├── Resources/                       # Secrets (Keychain config), Localizable.xcstrings
│   ├── Travel_appApp.swift              # App entry point
│   └── [other config files]
├── TravelWidgetExtension/               # iOS Live Activity + Lock Screen widget
├── Travel appTests/                     # Unit + integration tests
├── supabase/                            # Supabase Edge Functions (migrations, cloud code)
├── docs/                                # Design docs, pitch deck
└── scripts/                             # Utility scripts
```

## Directory Purposes

**Models/:**
- Purpose: Data layer — SwiftData @Model classes and supporting types
- Contains: 17 files total
  - Core: `TripModels.swift` (Trip, TripDay, TripEvent, Place, Expense, EventCategory, PlaceCategory, BudgetSource)
  - Supporting: `TicketModels.swift`, `PackingItem.swift`, `JournalEntry.swift`, `TripPhoto.swift`, `BucketListItem.swift`, `OfflineMapCache.swift`
  - User/Profile: `UserProfile.swift`, `CorporateProfile.swift`, `SecureDocuments.swift`
  - DTOs: `SyncModels.swift` (TripDTO, TripDayDTO, PlaceDTO, etc. for Supabase serialization)
  - Other: `Recommendation.swift`, `WeatherModels.swift`, `ScannedBooking.swift`, `SampleData.swift` (preview data)
- Key files: `TripModels.swift` (~950 lines, defines Trip/TripDay/Place/TripEvent/Expense with @Relationship cascades)

**Services/ (43+ files):**
- Purpose: Business logic, API integrations, state management
- Contains:
  - **Core Infrastructure:**
    - `AuthManager.swift` — auth state (@Observable), delegates to SupabaseAuthService
    - `SupabaseManager.swift` — Supabase client initialization, currentUserID property
    - `SupabaseAuthService.swift` — OAuth (Apple, Google, Yandex) + email auth via supabase-swift SDK
    - `SyncManager.swift` — debounced push/pull orchestrator (60s minimum interval)
    - `SyncEngine.swift` — generic push/pull logic with DTO conversion
    - `SupabaseProxy.swift` — unified HTTP client for 6 proxied services (weather, flights, currency, etc.)
  - **Location & Mapping:**
    - `LocationManager.swift` — GPS tracking, route points, geofencing
    - `RoutingService.swift` — route calculation between events
    - `GeofenceManager.swift` — auto-mark places visited when user enters geofence
    - `JapanRailwayGeoService.swift`, `JapanTransitService.swift` — transit-specific logic
  - **Weather & Environment:**
    - `WeatherService.swift` — fetch + cache weather via SupabaseProxy (OpenMeteo)
    - `CurrencyService.swift` — exchange rates, auto-refresh every 10 min
    - `CountryInfoService.swift` — country flags, capitals via SupabaseProxy
  - **AI & Content:**
    - `GeminiService.swift` — Gemini 2.5-flash API via SupabaseProxy (summarize, generate)
    - `PlaceInfoService.swift` — AI-powered place descriptions (Wikipedia + Gemini)
    - `RecommendationService.swift` — trip recommendations per day/category
    - `FlightAIService.swift` — flight info enrichment
    - `PackingListAIService.swift` — AI packing suggestions
    - `AIMapSearchService.swift` — POI search descriptions
    - `AITripGeneratorService.swift` — 4-step AI trip wizard (destination suggestions, itinerary generation)
    - `AIPromptHelper.swift` — profile-aware prompt personalization (interests, diet, pace, etc.)
    - `AICacheManager.swift` — LRU cache for AI responses (7-day TTL, max 200 entries)
  - **External APIs:**
    - `AirLabsService.swift` — flight data enrichment (IATA codes, aircraft type) via SupabaseProxy
    - `TravelpayoutsService.swift` — flight prices + hotel search via SupabaseProxy
    - `WikipediaService.swift` — article fetch via SupabaseProxy
    - `AppleMapsInfoService.swift` — local search via MapKit (fallback when Google unavailable)
  - **Document & Data Capture:**
    - `BookingScanService.swift` — OCR (Vision framework) + AI extraction of booking details
    - `EmailScannerService.swift` — Gmail/Yandex OAuth + email parsing for bookings
    - `ReceiptScanService.swift` — OCR expense receipts
    - `BarcodeService.swift` — barcode scanning for tickets
  - **User & Settings:**
    - `ProfileService.swift` — user profile (name, interests, diet, pace, visited countries, bucket list)
    - `SecureVaultService.swift` — encrypted document/loyalty card storage (Keychain)
    - `Secrets.swift` — API key management (Keychain + InfoPlist)
  - **UI & Real-Time:**
    - `NotificationManager.swift` — schedule local notifications for trips/events
    - `LiveActivityManager.swift` — Dynamic Island + lock screen activities
    - `WidgetDataProvider.swift` — shared data to TravelWidgetExtension
    - `OfflineCacheManager.swift` — network reachability monitoring, offline UX
    - `ARNavigationManager.swift` — AR navigation state
    - `JournalService.swift` — journal entry logic
  - **Security:**
    - `KeychainHelper.swift` — unified Keychain read/write
    - `CryptoService.swift` — encryption/decryption for sensitive data

**Views/ (organized by feature):**
- Purpose: SwiftUI screens and reusable components
- Contains: 100+ files in feature-based subdirectories
  - **Dashboard/:** Main trip overview (10 files)
    - `DashboardView.swift` — root container, switches based on trip.phase
    - `DashboardActiveSection.swift` — day counter + timezone (during trip)
    - `DashboardCountdownSection.swift` — countdown to flight (pre-trip)
    - `DashboardBudgetSection.swift` — budget progress
    - `DashboardWeatherSection.swift` — weather summary
    - `DashboardCountryInfoSection.swift` — flag + capital info
    - `DashboardFlightTrackingSection.swift` — active flight info
    - `DashboardTodayScheduleSection.swift` — today's events + places
    - Weather subviews: `WeatherDetailView.swift`, `WeatherSubviews.swift`, `WeatherAlertBanner.swift`, etc.
  - **Itinerary/:** Day list & detail (8 files)
    - `ItineraryView.swift` — list of trip days with drag-reorder
    - `DayDetailView.swift` — single day view (events, places, journal, weather, GPS)
    - Add/edit sheets: `AddDaySheet.swift`, `AddEventSheet.swift`, `AddPlaceSheet.swift`
    - Weather section: `DayWeatherSection.swift`
  - **Map/:** MapKit integration (12 files)
    - `TripMapView.swift` — main map container with search/route/detail modes
    - `MapViewModel.swift` — map state (@Observable, sheet detent, content type)
    - Bottom sheet content: `MapSearchContent.swift`, `MapPlaceDetailContent.swift`, `MapRouteContent.swift`
    - Overlays: `MapPinViews.swift`, `MapTransportOverlays.swift`, `MapFloatingSearchPill.swift`
    - Offline: `MapOfflineGallery.swift`, `RadarOverlayView.swift` (weather radar)
  - **Expenses/:** Budget tracking (5 files)
    - `ExpensesView.swift` — main expenses view with category breakdown
    - `AddExpenseSheet.swift` — expense entry form
    - `BudgetSourcesSheet.swift` — multi-currency budget setup
    - `ReceiptScannerSheet.swift` — OCR receipt scanning
    - `AllExpensesByDaySheet.swift` — detailed expense history
  - **Journal/:** Travel journal (6 files)
    - `JournalView.swift` — memory book organized by day
    - `JournalMemoryBookView.swift` — photo grid + entries
    - `AddJournalEntrySheet.swift` — entry form
    - `JournalEntryCard.swift`, `JournalDaySection.swift`
  - **Home/:** Trip hub (6 files)
    - `HomeView.swift` — trip list + quick actions
    - `HeroTripCard.swift` — featured trip card
    - `TravelStatsView.swift` — stats by period (all/year/month)
    - `StatsRouteMapView.swift`, `VisitedCountriesMapView.swift` — visualizations
    - `PostTripCacheSheet.swift` — cache trip data after completion
  - **AITripWizard/:** 4-step trip generator (7 files)
    - `AITripWizardView.swift` — paged TabView container
    - Step views: `WizardStepDestination.swift`, `WizardStepDates.swift`, `WizardStepBudget.swift`, `WizardStepStyle.swift`
    - `AITripLoadingView.swift` — pulse animation during generation
    - `AITripPreviewView.swift` — preview + save to SwiftData
  - **Auth/:** Authentication (3 files)
    - `AuthView.swift` — OAuth buttons + email form
    - `EmailAuthSheet.swift` — email sign-up/in form
    - `BiometricLockView.swift` — Face/Touch ID unlock
  - **Profile/:** User profile (5 files)
    - `ProfileSetupView.swift` — initial onboarding
    - `ProfileCardView.swift` — user info display
    - `AddVisitedCitySheet.swift` — city history
    - `ProfileDetailView.swift`
  - **Settings/:** App configuration (3 files)
    - `SettingsView.swift` — theme, language, notifications, data reset
    - `SideMenuView.swift` — slide-out menu (trip switcher, links, settings)
    - `SyncStatusView.swift` — sync state indicator
  - **Tickets/:** Ticket management (5 files)
    - `TicketsListView.swift` — flight/train tickets
    - `AddTicketSheet.swift` — ticket entry
    - `TicketCardView.swift` — ticket display (barcode + info)
    - `TicketDetailView.swift`, `BarcodeScannerView.swift`
  - **PackingList/:** Pre-trip checklist (3 files)
    - `PackingListView.swift` — category-grouped packing items
    - `AddPackingItemSheet.swift` — item entry
    - `PackingItemRow.swift` — checkbox + delete
  - **BucketList/:** Global bucket list (3 files)
    - `BucketListView.swift` — all items across trips
    - `AddBucketItemSheet.swift` — item entry (with MKLocalSearchCompleter)
    - `BucketItemCard.swift` — item display
  - **SecureVault/:** Encrypted documents (5 files)
    - `SecureVaultView.swift` — document + loyalty card storage
    - `AddDocumentSheet.swift`, `DocumentCard.swift`, `AddLoyaltySheet.swift`, `LoyaltyCard.swift`
  - **AR/:** Augmented Reality (4 files)
    - `ARNavigationView.swift` — AR view with RealityKit
    - `ARViewContainer.swift` — UIViewControllerRepresentable wrapper
    - `ARCoordinator.swift`, `ARHUDView.swift` — AR state management
  - **Discover/:** POI discovery (2 files)
    - `DiscoverNearbyView.swift` — nearby places search
    - `POIResultCard.swift` — result display
  - **Recommendations/:** Place info (3 files)
    - `RecommendationsView.swift` — category-filtered place suggestions
    - `RecommendationCard.swift`, `DayPickerSheet.swift`
  - **Shared/:** Reusable components (8 files)
    - `OfflineBanner.swift` — red banner when offline
    - `PlaceAIInfoSheet.swift` — AI info modal
    - `PhotoGridView.swift` — trip photo grid
    - `StatCard.swift`, `EventCard.swift`, `EventRouteCard.swift`, `EventLocationSearchField.swift`
    - `SheetHeader.swift` — common sheet header with close button
  - **Components/:** Legacy component folder (3 files, mostly empty/deprecated)
  - **Trips/:** Trip management (4 files)
    - `TripsListView.swift` — previous trip list (mostly replaced by HomeView)
    - `TripCardView.swift` — trip card display
    - `EditCountriesSheet.swift` — multi-country selector
  - **Onboarding/:** First launch (1 file)
    - `OnboardingView.swift` — welcome screens
  - **MainTabView.swift** — root navigation container (5 tabs + state gating)

**Theme/:**
- Purpose: Design system centralization
- Contains: 6 files
  - `AppTheme.swift` — color constants (palette-aware sakuraPink, semantic colors, category colors), spacing, radii, fontSize
  - `ThemeProvider.swift` — ColorPalette enum (6 cases: sakura/midnight/imperial/matcha/fuji/hanami), currentPalette property
  - `GlassComponents.swift` — reusable ViewModifiers (GlassTextFieldStyle, GlassFormField, GlassSectionHeader, sakuraGradientBackground)
  - `AppMode.swift` — personal vs corporate mode (mostly unused now)
  - `CorporateCardStyle.swift`, `CorporateWaveBackground.swift`, `ModeSwitcherView.swift`, `ModeTransitionOverlay.swift` — corporate mode features (neutered)

**Resources/:**
- Purpose: App assets, strings, secrets configuration
- Contains:
  - `Localizable.xcstrings` — Russian + English strings (used via String(localized: "..."))
  - `Secrets.swift` — API key management, migrates from UserDefaults to Keychain

## Key File Locations

**Entry Points:**
- `Travel app/Travel_appApp.swift`: @main app, initializes Supabase, ModelContainer, AuthManager
- `Travel app/Views/MainTabView.swift`: Root navigation router (auth gates, trip selection, 5-tab TabView)
- `Travel app/Views/Home/HomeView.swift`: Trip hub (list + quick actions) when no trip selected

**Configuration:**
- `Travel app/Resources/Secrets.swift`: API key getters/setters (Keychain + InfoPlist fallback)
- `Travel app/Theme/AppTheme.swift`: All design tokens in one place
- `Travel app/Theme/ThemeProvider.swift`: ColorPalette enum + current palette state

**Core Data Models:**
- `Travel app/Models/TripModels.swift`: Trip, TripDay, TripEvent, Place, Expense (@Model + computed properties)
- `Travel app/Models/SyncModels.swift`: DTOs + Syncable protocol

**Core Services:**
- `Travel app/Services/SyncManager.swift`: Sync orchestration (push/pull, debounce, offline aware)
- `Travel app/Services/AuthManager.swift`: Auth state facade (@Observable)
- `Travel app/Services/SupabaseManager.swift`: Supabase client + currentUserID
- `Travel app/Services/LocationManager.swift`: GPS tracking + route points

**Specialized Services:**
- `Travel app/Services/GeminiService.swift`: AI text generation (place descriptions, recommendations)
- `Travel app/Services/WeatherService.swift`: Weather fetch + cache
- `Travel app/Services/BookingScanService.swift`: OCR + AI extraction
- `Travel app/Services/AITripGeneratorService.swift`: 4-step AI wizard

**Main Views:**
- `Travel app/Views/Dashboard/DashboardView.swift`: Trip overview (phase-based layout)
- `Travel app/Views/Itinerary/ItineraryView.swift`: Day list + editor
- `Travel app/Views/Itinerary/DayDetailView.swift`: Day detail (places, events, journal)
- `Travel app/Views/Map/TripMapView.swift`: MapKit integration + search
- `Travel app/Views/Expenses/ExpensesView.swift`: Budget tracking

**Testing:**
- `Travel appTests/`: TripModelTests.swift, CurrencyServiceTests.swift, KeychainHelperTests.swift (minimal coverage)

## Naming Conventions

**Files:**
- PascalCase: SwiftUI Views (`DashboardView.swift`, `AddExpenseSheet.swift`)
- PascalCase: Models and Services (`Trip.swift` is part of TripModels.swift, `WeatherService.swift`)
- camelCase: Utility functions (rarely used)
- Suffixes: `...View`, `...Sheet`, `...Service`, `...Manager` for clarity

**Directories:**
- Feature-based: `Views/Dashboard/`, `Views/Itinerary/`, `Views/Map/` (not type-based like `Views/Screens/` or `Views/Components/`)
- PascalCase: `Models/`, `Services/`, `Views/`, `Theme/`, `Resources/`

**Code Conventions:**
- Models: PascalCase properties (name, cityName, startDate), `@Model final class Trip`
- Views: `struct DashboardView: View`, `@State private var`, `@Environment(\.modelContext) var modelContext`
- Services: `@MainActor @Observable final class WeatherService`, `static let shared` singleton
- Enums: PascalCase with raw values (EventCategory, PlaceCategory, ExpenseCategory)
- Computed Properties: Prefer simple names (trip.isActive, day.isPast, place.coordinate)

## Where to Add New Code

**New Feature (e.g., Flight Tracking):**
- Primary code: `Travel app/Services/NewFeatureService.swift` (@Observable singleton)
- Views: `Travel app/Views/FlightTracking/FlightTrackingView.swift` (new feature folder)
- Models (if needed): Add to `Travel app/Models/TripModels.swift` or new file
- Tests: `Travel appTests/FlightTrackingServiceTests.swift`

**New Component/Module:**
- Implementation: `Travel app/Views/[FeatureName]/ComponentName.swift`
- Add to: Feature-specific folder if reusable within feature, or `Shared/` if cross-feature
- If complex: Extract to separate files (`ComponentName.swift` + `ComponentNameContent.swift`)

**New Utility Function:**
- Shared helpers: `Travel app/Services/HelperService.swift` (if stateful) or extension on model
- View modifiers: Add to `Travel app/Theme/GlassComponents.swift` or new file if many

**Adding to Sync:**
- Model: Implement Syncable protocol (updatedAt, isDeleted), add @Relationship to parent
- DTO: Add struct in `Travel app/Models/SyncModels.swift` with CodingKeys (snake_case)
- SyncEngine: Add push/pull methods in `Travel app/Services/SyncEngine.swift`
- SyncManager: Call push/pull in correct order (parents before children)

## Special Directories

**TravelWidgetExtension/:**
- Purpose: Lock screen + Dynamic Island widgets
- Generated: No (manually maintained)
- Committed: Yes
- Contains: `TravelLiveActivity.swift`, `CountdownWidget.swift`, `WidgetTheme.swift`

**supabase/:**
- Purpose: Cloud code (Edge Functions, migrations, RLS policies)
- Generated: No (managed via Supabase CLI)
- Committed: Yes
- Contains: 7 migrations, 2 Edge Functions (gemini-proxy, email-token-exchange, email-scanner, etc.)

**docs/:**
- Purpose: Design documentation, pitch deck
- Generated: No
- Committed: Yes (tracked in git)
- Contains: `ULTIMA_Pitch_Deck.pptx`, design docs, HTML playgrounds

**scripts/:**
- Purpose: Utility scripts (not part of Xcode build)
- Generated: No
- Committed: No (ignored in .gitignore typically)

**Travel appTests/:**
- Purpose: Unit + integration tests
- Generated: No (manually written, minimal coverage)
- Committed: Yes
- Contains: ~3 test files (TripModelTests, CurrencyServiceTests, KeychainHelperTests)

---

*Structure analysis: 2026-03-20*
