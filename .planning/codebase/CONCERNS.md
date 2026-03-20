# Codebase Concerns

**Analysis Date:** 2026-03-20

## Tech Debt

**SwiftData Model Container Initialization:**
- Issue: Force-unwrapping `try!` in `Travel_appApp.swift:25` with no error recovery
- Files: `Travel app/Travel_appApp.swift`
- Impact: App crashes immediately on launch if model container fails to initialize. No migration strategy for schema changes.
- Fix approach: Replace `try!` with proper error handling and graceful degradation. Implement versioned migrations for schema updates.

**Supabase Secrets in Source Code:**
- Issue: Anon key hardcoded in `Secrets.swift:6` (public by design but still sensitive)
- Files: `Travel app/Config/Secrets.swift`
- Impact: Key is readable in binary/git history. Compromised if key is rotated, must rebuild app.
- Fix approach: Move to dynamic configuration via `Info.plist` or environment, rotate key immediately.

**Print Statements in Production Code:**
- Issue: 40+ `print()` debug statements throughout services (BookingScanService, SupabaseProxy, PlaceInfoService, etc.)
- Files: `Travel app/Services/BookingScanService.swift`, `Travel app/Services/SupabaseProxy.swift`, `Travel app/Services/PlaceInfoService.swift`, `Travel app/Services/EmailScannerService.swift`, `Travel app/Services/AIMapSearchService.swift`, `Travel app/Services/AITripGeneratorService.swift`, and 15+ more
- Impact: Performance overhead, privacy leak (sensitive data logged), confuses debugging, clutters output.
- Fix approach: Replace with proper logging framework (os.log or similar) with configurable levels. Remove all `print()` statements.

**Unimplemented Apple Sign In:**
- Issue: TODO comment in `Views/Auth/AuthView.swift:106` - Apple Sign In not implemented
- Files: `Travel app/Views/Auth/AuthView.swift`
- Impact: Missing critical iOS auth method. Users expect Apple Sign In as standard.
- Fix approach: Implement full Apple Sign In flow with Supabase integration.

**Large File Complexity:**
- Issue: Multiple files exceed 1000 lines (FlightDetailView 1142, SettingsView 1059, ProfileDetailView 1047, TripModels 948, SyncManager 889)
- Files: `Travel app/Views/Dashboard/FlightDetailView.swift`, `Travel app/Views/Settings/SettingsView.swift`, `Travel app/Views/Profile/ProfileDetailView.swift`, `Travel app/Models/TripModels.swift`, `Travel app/Services/SyncManager.swift`
- Impact: Difficult to maintain, hard to test, increased cognitive load, prone to bugs
- Fix approach: Split files into focused, smaller modules (max 400-600 lines each). Extract view components and service helpers.

**AI Cache Manager Missing Eviction on Memory Pressure:**
- Issue: Cache stores 200+ entries in-memory, only evicts on TTL (7 days)
- Files: `Travel app/Services/AICacheManager.swift`
- Impact: Unbounded memory growth if app runs for weeks. No response to memory warnings.
- Fix approach: Add `didReceiveMemoryWarning` listener, implement aggressive eviction, add active memory monitoring.

## Known Bugs

**SyncManager Potential Race Condition:**
- Symptoms: Sync state shows "syncing" but completes silently; manual refresh doesn't always work
- Files: `Travel app/Services/SyncManager.swift`, lines 70-117
- Trigger: Rapid calls to `syncIfNeeded()` before first sync completes; offline→online transition
- Root Cause: `lastSyncAttempt` updated before actual sync starts; no concurrent sync guard
- Workaround: Manual sync button visible to user; debounce window is 60s
- Fix: Add atomic `isSyncing` guard, queue pending syncs, proper error state cleanup

**LocationManager Missing @MainActor:**
- Symptoms: Race conditions when updating tracking state from background location callbacks
- Files: `Travel app/Services/LocationManager.swift`, lines 6-200
- Root Cause: `@Observable` with mutable state (isTracking, currentLocation) accessed from `CLLocationManagerDelegate` callbacks off main thread
- Impact: Potential data corruption, Live Activity update failures
- Fix: Mark class `@MainActor`, wrap all location updates with `@MainActor` context

**EmailScannerService OAuth Token Leakage:**
- Symptoms: Access token printed to console during OAuth flow
- Files: `Travel app/Services/EmailScannerService.swift`, lines 63-101
- Trigger: Every email scan via Gmail/Yandex
- Impact: Token visible in device logs, potential interception if logs are backed up
- Fix: Remove all token logging, use opaque identifiers only

**CurrencyService Infinite Timer:**
- Symptoms: Timer reference stored but not invalidated on deinit
- Files: `Travel app/Services/CurrencyService.swift`, line 145
- Root Cause: `refreshTimer` property recreated but old timer never invalidated
- Impact: Memory leak, 15-second timer fires indefinitely in background
- Fix: Add `deinit`, invalidate timer, ensure single timer instance

**SwiftData Concurrent Access in SyncManager:**
- Symptoms: "Cannot update model context while marked as deleted" during pulls
- Files: `Travel app/Services/SyncManager.swift`, lines 437-480
- Trigger: Sync starts while user is editing models; relationship lookups fail
- Root Cause: Pull operations fetch all models, then iterate without locking; user edits concurrently
- Fix: Use FetchDescriptor with proper isolation, batch updates, lock context during pulls

## Security Considerations

**OAuth Redirect URI Validation Missing:**
- Risk: Malicious apps could intercept OAuth callbacks if redirect URI not properly validated
- Files: `Travel app/Views/Auth/AuthView.swift`, `Travel app/Services/SupabaseAuthService.swift`
- Current mitigation: `SupabaseAuthService.oauthCallbackScheme` hardcoded in app
- Recommendations:
  1. Validate EXACT redirect URI in Edge Function before token exchange
  2. Use PKCE (Proof Key for Code Exchange) for additional security
  3. Store state parameter, validate on callback
  4. Log all OAuth attempts to Supabase logs

**Keychain Migration Incomplete:**
- Risk: Old API keys may still exist in Keychain alongside new system, confusion on which is active
- Files: `Travel app/Config/Secrets.swift`, lines 36-51
- Current mitigation: Two migrations (v2, v3) with UserDefaults flags
- Recommendations:
  1. Third migration to audit all Keychain entries, remove stale ones
  2. Add logging of what keys were deleted
  3. Validate no duplicate keys exist after migration

**Google API Key in Info.plist:**
- Risk: Google Places API key may be readable from binary
- Files: Referenced in `Secrets.swift` via `infoPlistValue()`
- Current mitigation: Server-side proxy via SupabaseProxy
- Recommendations:
  1. Verify Info.plist secrets are code-stripped in release builds
  2. Consider removing from Info.plist entirely, load from secure backend only
  3. Document that all API keys should be server-side

**User Data Export Missing:**
- Risk: No way to export user data (GDPR requirement)
- Files: None - feature missing
- Impact: Legal exposure, fails data portability requirement
- Recommendations:
  1. Implement "Export My Data" button in Settings
  2. Generate JSON dump of all user models via Supabase
  3. Include photos, journal, trips, expenses, all sync-able models

## Performance Bottlenecks

**VisitedCountriesMapView Large Mapping Dictionary:**
- Problem: Hardcoded 200+ country names in static dictionary; N*M lookup for each country
- Files: `Travel app/Views/Home/VisitedCountriesMapView.swift`, lines 7-120+
- Current capacity: ~200 countries, O(1) lookup but large binary
- Scaling path: Move to lazy-loaded JSON asset; consider trie structure for fuzzy matching
- Optimization: Cache lookup results, implement country autocomplete

**PlaceInfoService Sync AI Requests:**
- Problem: `fetchPlaceInfo()` makes sequential Wikipedia + Gemini calls
- Files: `Travel app/Services/PlaceInfoService.swift`, lines 97-125
- Current capacity: 5-10 places per trip comfortably; N places slow exponentially
- Scaling path: Parallel requests via `async let`, batch Wikipedia calls, implement request coalescing
- Optimization: Cache full place info, reuse enriched data across trip

**AirLabsService Double Fetch Attempt:**
- Problem: `fetchFlight()` tries live schedules THEN routes sequentially
- Files: `Travel app/Services/AirLabsService.swift`, lines 61-72
- Current capacity: Single flight lookup ok; 20+ flights stalls UI
- Scaling path: Parallel fetch attempts, implement timeout, fallback queue
- Optimization: Cache routes globally, pre-fetch known carriers

**DayDetailView Relationship Traversal:**
- Problem: Each view loads full trip, all days, all places (N+M complexity)
- Files: `Travel app/Views/Itinerary/DayDetailView.swift`, uses trip.days
- Current capacity: 10 days × 10 places acceptable; 30+ days causes lag
- Scaling path: Use @Query with specific predicate for active day only
- Optimization: Pagination, lazy loading, limit to 50 events per view

## Fragile Areas

**SyncModels DTO Optionality Mismatches:**
- Files: `Travel app/Services/SyncModels.swift`
- Why fragile: DTOs have different optionality than models (e.g., `PlaceDTO.rating: String?` but `Place.rating: Int`). Conversions assume values present.
- Safe modification: Add validation in decoder, use nil coalescing with defaults, document DTO contracts
- Test coverage: Gaps in sync error paths; missing tests for partial/malformed DTO responses

**TripFlight Multi-Encoding Scheme:**
- Files: `Travel app/Models/TripModels.swift`, lines 83-123
- Why fragile: Flights stored as both single (flightNumber, flightDate) AND array (flightsJSON). Update logic must keep both in sync.
- Safe modification: Deprecate single fields, migrate all code to array only, add migration script
- Test coverage: No tests for edge cases (empty array, null JSON, mixed formats)

**SwiftData Cascade Deletes:**
- Files: `Travel app/Models/TripModels.swift` - 10 relationships with `deleteRule: .cascade`
- Why fragile: Deleting trip cascades to 10+ child models. No validation that cascade target relations are set.
- Safe modification: Verify all cascade targets are present before delete, add undo capability, log cascades
- Test coverage: Missing cascade integration tests

**AuthManager Session Persistence:**
- Files: `Travel app/Services/AuthManager.swift`, `Travel app/Services/SupabaseAuthService.swift`
- Why fragile: Session restored asynchronously on app launch; views render before auth state known. Race condition possible.
- Safe modification: Block UI until session check completes, show splash screen, use @State to gate content
- Test coverage: Missing tests for slow network auth restoration

## Scaling Limits

**Supabase Row Level Security (RLS) Performance:**
- Current capacity: ~1000 queries/second per user acceptable; 10000+ queries hit RLS bottleneck
- Limit: RLS policies evaluated on EVERY select; complex policies (e.g., checking multiple trips) scale badly
- Scaling path:
  1. Move trip ownership check to indexed column
  2. Implement materialized views for common queries
  3. Use Supabase read replicas for heavy read traffic
  4. Cache user's trip list locally, refresh every 5 min

**Live Activity Concurrent Limit:**
- Current capacity: 1 active Live Activity per app
- Limit: iOS allows max 10 Live Activities system-wide; multiple trips tracking would fail
- Scaling path:
  1. For multi-trip: cycle between trips (show 1 at a time)
  2. Implement scheduled activity transitions
  3. Consider notification-based updates instead of Live Activity

**Photo Storage 100MB Limit (Free Tier):**
- Current capacity: ~100 photos at 1MB each, or 500 at 200KB
- Limit: Supabase free tier `trip-photos` bucket capped at 100GB; photos not compressed
- Scaling path:
  1. Implement on-device thumbnail generation (HEIC → JPEG 100KB)
  2. Upload thumbnails to sync, store full-res locally only
  3. Implement photo archival (delete from Supabase after 90 days)
  4. Use Supabase CDN with image transformation API

**JSON Serialization of Flights Array:**
- Current capacity: 20+ flights per trip ok; 100+ flights causes encoding/decoding lag
- Limit: Entire flights array re-encoded on any change; no delta updates
- Scaling path:
  1. Split flights into separate Supabase table with trip foreign key
  2. Sync individual flight inserts, not entire array
  3. Use streaming JSON parser for large arrays
  4. Paginate flight list UI

## Dependencies at Risk

**Supabase Swift SDK Stability:**
- Risk: SDK is v2.0+ (relatively new), breaking changes in minor versions possible
- Impact: Auth changes, sync breaks, client-side decoding fails
- Current version: ~v2.0 (from SPM requirement in memory)
- Migration plan:
  1. Pin to specific version (e.g., `.upToNextMajor(from: "2.0.0")`)
  2. Test each SDK upgrade in CI before merging
  3. Implement feature flags to gate breaking changes
  4. Subscribe to release notes

**MapKit Availability Gaps (iOS <18):**
- Risk: New MapKit features require iOS 18; app targets lower iOS versions
- Impact: Map item detail, new overlays not available on iPhone 13/14
- Current workaround: `#available(iOS 18.0, *)` guards in place
- Migration plan:
  1. Document minimum iOS version target clearly
  2. Implement fallback UIs for iOS <18
  3. Test on iOS 17 device regularly
  4. Consider bumping minimum to iOS 17 if features stabilize

**ActivityKit (Live Activities) Stability:**
- Risk: ActivityKit is new, updates may break Live Activity format
- Impact: Flight tracking widget crashes if Activity definition changes incompatibly
- Current status: Used in production for flight/tracking
- Migration plan:
  1. Implement ActivityKit error handling, show error toast if update fails
  2. Version the TrackingActivityAttributes struct
  3. Monitor Apple Activity Kit release notes
  4. Have fallback notification strategy if Live Activity fails

**Open-Source Data Dependencies:**
- Risk: Airport codes, country mappings maintained by community
- Impact: Outdated data causes incorrect flight/country detection
- Current dependencies:
  - Country name mapping in VisitedCountriesMapView (hardcoded 200+ entries)
  - Airport codes/names in FlightData static dictionaries
- Migration plan:
  1. Create automated job to sync country data from ISO 3166 API
  2. Implement airport database from IATA/ICAO regularly updated
  3. Cache with version tracking, alert users if cache is stale
  4. Allow user overrides (e.g., custom country names)

## Missing Critical Features

**Data Backup & Disaster Recovery:**
- Problem: No manual backup export; user data lives only on Supabase + on-device
- Blocks: Users cannot migrate to new phone easily; no offline backup
- Recommendation:
  1. Implement "Backup to iCloud" feature
  2. Encrypt and upload all models to iCloud Drive via CloudKit
  3. Restore from iCloud on fresh install
  4. Document restore process clearly

**Offline Mode Incomplete:**
- Problem: App mostly works offline, but sync is broken
- Blocks: Users cannot reliably edit trips without internet
- Current offline support: Weather caching, map snapshots, local CRUD only
- Recommendation:
  1. Queue local edits (Trip, Day, Place, Expense) when offline
  2. Implement conflict resolution when coming back online
  3. Show "changes queued for sync" indicator
  4. Test with airplane mode + battery saver

**User Settings Sync:**
- Problem: Preferences (currency, palette, language) not synced across devices
- Blocks: Multi-device users get inconsistent experience
- Recommendation:
  1. Create settings table in Supabase
  2. Sync palette, language, notification settings
  3. Implement per-trip settings (currency preference for specific trip)
  4. Handle conflicts (which device wins on simultaneous edit)

## Test Coverage Gaps

**Sync Conflict Resolution:**
- What's not tested: Remote edit while local edit pending; both create, delete, update scenarios
- Files: `Travel app/Services/SyncManager.swift`, `Travel app/Services/SyncEngine.swift`
- Risk: Corrupt data, lost updates, deleted items reappearing
- Priority: High
- Test needed: Unit tests for `pullTrips()` with stale local copies; integration tests with real Supabase

**OAuth Flow Error Cases:**
- What's not tested: Invalid redirects, canceled auth, network timeout during token exchange, invalid state
- Files: `Travel app/Services/SupabaseAuthService.swift`, `Travel app/Views/Auth/AuthView.swift`
- Risk: Users stuck in auth state, unable to retry
- Priority: High
- Test needed: Mock OAuth server responses, test recovery from each error code

**LocationManager Background Resume:**
- What's not tested: App killed in background with tracking active; GPS disabled then re-enabled
- Files: `Travel app/Services/LocationManager.swift`, lines 78-87
- Risk: Tracking state lost, double-tracking on resume
- Priority: Medium
- Test needed: Simulate app termination, verify persisted state restored

**BookingScannerSheet OCR Edge Cases:**
- What's not tested: Blurry images, inverted colors, multiple pages, handwritten booking numbers
- Files: `Travel app/Views/Dashboard/BookingScannerSheet.swift`, `Travel app/Services/BookingScanService.swift`
- Risk: Failed extractions, user frustration
- Priority: Medium
- Test needed: Unit tests with 50+ real booking screenshots, fuzzy flight matching

**SyncModels Type Conversions:**
- What's not tested: DTO with null/missing fields converts safely; date string parsing with locale variance
- Files: `Travel app/Services/SyncModels.swift`, sync pull operations
- Risk: Crashes on unexpected Supabase schema changes
- Priority: High
- Test needed: Parameterized tests with malformed DTOs, missing fields, type mismatches

**Profile Picture Upload Resilience:**
- What's not tested: Large files (>10MB), timeout midway, duplicate uploads, network switch
- Files: `Travel app/Services/PhotoSyncService.swift`
- Risk: Orphaned uploads, storage bloat, user avatar missing
- Priority: Medium
- Test needed: Simulate network interruption, verify retry queue, cleanup orphaned files

---

*Concerns audit: 2026-03-20*
