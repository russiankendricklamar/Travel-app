# Architecture

**Analysis Date:** 2026-03-20

## Pattern Overview

**Overall:** MVVM + Modular Services with SwiftData Persistence & Cloud Sync

**Key Characteristics:**
- SwiftUI views (V) with explicit @State + @Environment state management
- Data models use SwiftData @Model with Syncable protocol for cloud synchronization
- Service layer (singleton @Observable classes) handles business logic and async operations
- Cloud-first architecture: Supabase handles auth, sync, and proxied external APIs
- Glassmorphism design system unified via AppTheme + ColorPalette

## Layers

**Presentation (Views):**
- Purpose: SwiftUI hierarchies for user interaction; responsive to service/model state changes
- Location: `Travel app/Views/**/`
- Contains: Tab views (Dashboard, Itinerary, Map, Expenses, Journal), feature screens (Auth, Home, AITripWizard), reusable components
- Depends on: @State properties, @Environment modelContext, shared Services, Theme system
- Used by: App entry point (Travel_appApp.swift)

**Data Model:**
- Purpose: SwiftData @Model classes defining app entities (Trip, TripDay, Place, Expense, etc.) with Syncable protocol
- Location: `Travel app/Models/`
- Contains: Trip/TripDay/Place/TripEvent/Expense/Ticket/PackingItem/JournalEntry/TripPhoto/BucketListItem/OfflineMapCache models
- Depends on: SwiftData framework, Syncable protocol, Codable DTOs for serialization
- Used by: Views (via @Query), Services (CRUD operations), SyncManager (push/pull)

**Service Layer:**
- Purpose: Encapsulate domain logic, async operations, external API calls, state management
- Location: `Travel app/Services/`
- Contains: 43+ singleton @Observable classes (WeatherService, AuthManager, SyncManager, AIServices, LocationManager, etc.)
- Depends on: Models, external frameworks (Supabase, MapKit, Vision for OCR), Secrets for credentials
- Used by: Views (via dependency injection or property access), other Services

**Theme System:**
- Purpose: Centralized design tokens, color palettes, reusable UI modifiers (glassmorphism)
- Location: `Travel app/Theme/`
- Contains: AppTheme (static colors/spacing/radii), ColorPalette enum (6 cases), GlassComponents (ViewModifiers)
- Depends on: SwiftUI framework
- Used by: All Views, Models for category colors

**Auth & Sync:**
- Purpose: Handle user authentication (Supabase OAuth + email), push/pull data synchronization
- Location: `Travel app/Services/AuthManager.swift`, `SupabaseAuthService.swift`, `SyncManager.swift`, `SyncEngine.swift`, `SupabaseProxy.swift`
- Delegates to Supabase (cloud provider) for identity and database operations
- Used by: Travel_appApp (lifecycle), MainTabView (auth state gating), all data-mutating Views

## Data Flow

**Trip Viewing (Happy Path):**

1. User launches app → Travel_appApp.swift initializes Supabase, restores session, triggers auth check
2. MainTabView reads @Query trips, computes selectedTrip via UUID lookup
3. When trip selected → shows TabView (Dashboard, Itinerary, Map, Expenses, Journal tabs)
4. Each tab receives `trip: Trip` parameter, reads @Environment modelContext for CRUD
5. Models use @Relationship(deleteRule: .cascade) for hierarchical delete (e.g., Trip → TripDays → Places)

**Creating/Editing Data (Add Trip Flow):**

1. User taps "+" → CreateTripSheet opens
2. Form validation via AITripWizardView (4-step wizard) or manual CreateTripSheet
3. On save: `modelContext.insert(trip)` → `try modelContext.save()`
4. MainTabView @Query auto-refreshes, selectedTrip computed property finds new trip by UUID
5. SyncManager.syncIfNeeded() debounces (60s), pushes Trip to Supabase via SyncEngine

**Expense Entry with Receipt:**

1. User taps receipt scanner icon → ReceiptScannerSheet (OCR + AI)
2. Vision framework extracts text → BookingScanService (AI parsing via Gemini)
3. Results show in sheet → user selects and taps "ADD"
4. Expense object created → `modelContext.insert(expense)` → `modelContext.save()`
5. SyncManager pushes to Supabase

**Location Tracking (GPS):**

1. LocationManager starts tracking GPS → updates route points in memory
2. When app enters background → LocationManager stores resume flag
3. DayDetailView shows real-time route on map (MapKit with RoutingService overlay)
4. On day completion → updates place.isVisited flags

**Weather Refresh Cycle:**

1. On app launch/scene activation → WeatherService.startAutoRefresh() (10min interval)
2. Fetches via SupabaseProxy (proxied OpenMeteo API)
3. On network error → restores cached weather from UserDefaults
4. DashboardView and WeatherDetailView reactively update from @Observable

**Offline & Sync:**

1. OfflineCacheManager monitors NWPathMonitor (network reachability)
2. When offline → OfflineBanner appears, SyncManager.canSync = false
3. MapView shows cached MKMapSnapshots (per-day offline gallery)
4. When online → SyncManager auto-syncs (60s debounce), PUSH local changes first, PULL remote
5. Conflict resolution: remote `updatedAt` wins

## Key Abstractions

**Syncable Protocol:**
- Purpose: Uniform interface for sync-eligible models
- Examples: `Trip`, `TripDay`, `Place`, `TripEvent`, `Expense`, `Ticket`, `PackingItem`, `JournalEntry`, `BucketListItem`
- Pattern: Implements `updatedAt` + `isDeleted` fields; SyncManager uses these for push/pull logic

**@Observable Services:**
- Purpose: Thread-safe, reactive state containers for async operations
- Examples: `WeatherService`, `GeminiService`, `SyncManager`, `AuthManager`, `LocationManager`
- Pattern: `@MainActor @Observable final class` with `static let shared` singleton; Views react to property changes

**ColorPalette Enum:**
- Purpose: Switch between 6 design palettes (sakura, midnight, imperial, matcha, fuji, hanami)
- Examples: `ColorPalette.sakura.accentColor`, `ColorPalette.current.colorScheme`
- Pattern: Stored in `@AppStorage("colorPalette")` for persistence; MainTabView rebuilds on change (`.id(palette)`)

**DTO (Data Transfer Objects):**
- Purpose: Serialize/deserialize SwiftData models to/from Supabase JSON
- Examples: `TripDTO`, `TripDayDTO`, `PlaceDTO`, `ExpenseDTO` (snake_case for DB, swift CodingKeys)
- Pattern: Used by SyncEngine for push/pull; optional fields handle nullable columns

**AI Services:**
- Purpose: Integrate multiple AI providers (Gemini default, fallback to Claude/Groq)
- Examples: `GeminiService`, `RecommendationService`, `PlaceInfoService`, `AITripGeneratorService`
- Pattern: Use SupabaseProxy to proxied Gemini API; AIPromptHelper personalizes prompts via ProfileService context

## Entry Points

**Travel_appApp (App):**
- Location: `Travel app/Travel_appApp.swift`
- Triggers: App launch, scene phase changes
- Responsibilities: Initialize Supabase, restore auth session, set up ModelContainer, schedule background sync

**MainTabView (Navigation):**
- Location: `Travel app/Views/MainTabView.swift`
- Triggers: After auth/onboarding checks pass
- Responsibilities: Route based on auth state (AuthView → ProfileSetupView → OnboardingView → HomeView or trip TabView); manage selectedTripID UUID state

**HomeView (Trip Hub):**
- Location: `Travel app/Views/Home/HomeView.swift`
- Triggers: When no trip selected (user sees trip list)
- Responsibilities: Display trips by phase (active/upcoming/past), quick actions (AI wizard, bucket list, packing list), travel stats

**DashboardView (Trip Overview):**
- Location: `Travel app/Views/Dashboard/DashboardView.swift`
- Triggers: When trip selected + dashboard tab active
- Responsibilities: Display compact hero, budget/weather/flights/country info per trip phase (preTrip/active/postTrip)

**ItineraryView (Day CRUD):**
- Location: `Travel app/Views/Itinerary/ItineraryView.swift`
- Triggers: When trip selected + itinerary tab active
- Responsibilities: Show trip days list, drag-reorder, navigate to DayDetailView

**DayDetailView (Day Deep Dive):**
- Location: `Travel app/Views/Itinerary/DayDetailView.swift`
- Triggers: From ItineraryView (NavigationStack with day UUID)
- Responsibilities: Show/edit day header, weather, events, places, journal entries, tickets, GPS tracking

**TripMapView (Map + Search):**
- Location: `Travel app/Views/Map/TripMapView.swift`
- Triggers: When trip selected + map tab active
- Responsibilities: Show MapKit with route overlay (events/places), floating search pill, bottom sheet for details/search/route

## Error Handling

**Strategy:** Try-catch with user-friendly messages; offline fallback to cached data

**Patterns:**

- **Network errors:** SyncManager catches errors, sets state = .error(String), shows alert in SettingsView
- **Validation errors:** Forms validate before submit (email regex, date ranges, required fields)
- **API errors:** Services log detailed error, return nil or fallback (e.g., WeatherService restores cache on HTTP error)
- **SwiftData errors:** Save failures logged; retry triggered by scene activation or manual sync button
- **Auth errors:** AuthView shows error message; SupabaseAuthService re-throws for controller handling

## Cross-Cutting Concerns

**Logging:** Print statements (some with prefixes like `[GeminiService]`) in development; no production logging framework

**Validation:**
- Models: Trip requires name/dates; TripDay requires date/cityName
- Input: Email regex in EmailAuthSheet; currency amount in AddExpenseSheet
- Forms: AI wizard validates step-by-step

**Authentication:**
- SupabaseAuthService handles OAuth (Apple, Google, Yandex) + email sign-up/in
- AuthManager gates views; MainTabView checks isSignedIn + isLocked (biometric)
- Session restored from Supabase on app launch; persisted in Keychain via supabase-swift

**State Synchronization:**
- SyncManager debounces push/pull (60s minimum interval)
- SyncEngine orders operations: trips → days → places → events → expenses (parents first)
- Conflict resolution: remote updatedAt timestamp wins on both push and pull
- Offline support: OfflineCacheManager tracks isOnline; sync skipped when offline

---

*Architecture analysis: 2026-03-20*
