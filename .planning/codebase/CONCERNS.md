# Codebase Concerns

**Analysis Date:** 2026-02-28

## Tech Debt

**No Data Persistence:**
- Issue: All data (trips, expenses, journal entries, itinerary) exists only in memory. Data is completely lost when app is closed.
- Files: `Travel app/ViewModels/TripStore.swift`, `Travel app/Travel_appApp.swift`
- Impact: App cannot be used for actual trip planning. Data loss is catastrophic for the use case.
- Fix approach: Implement CoreData or Codable + FileManager for persistence. Store trip data to device and restore on app launch.

**Sample Data Only:**
- Issue: App initializes with hardcoded sample data from `SampleData.build()`. No way to create new trips or edit the hardcoded trip.
- Files: `Travel app/Models/SampleData.swift`, `Travel app/ViewModels/TripStore.swift` (lines 64-70)
- Impact: App is a read-only demo. Users cannot plan their own trips.
- Fix approach: Remove sample data dependency. Implement trip creation flow with user input for trip details (name, dates, budget, destination).

**Unused ContentView:**
- Issue: `ContentView.swift` exists but is never used. App starts with `MainTabView` from `Travel_appApp.swift`.
- Files: `Travel app/ContentView.swift`
- Impact: Code clutter, confusing entry point.
- Fix approach: Delete unused file.

## Known Bugs

**Timer Memory Leak in DashboardView:**
- Symptoms: Day counter animation creates repeating Timer that may not be properly cleaned up.
- Files: `Travel app/Views/Dashboard/DashboardView.swift` (lines 61-73, `animateCounter()`)
- Trigger: Every time DashboardView appears (onAppear)
- Current behavior: Uses `Timer.scheduledTimer(withTimeInterval:repeats:block:)` without storing reference for cancellation
- Workaround: None - timer will fire indefinitely even after view dismissal
- Fix approach: Store Timer as @State variable and invalidate in onDisappear. Use async/await with Task and sleep instead.

**Force Unwrap in Trip Date Calculations:**
- Symptoms: App crashes if date components fail
- Files: `Travel app/Models/SampleData.swift` (lines 15-20), multiple Calendar.date calls with force unwrap `!`
- Trigger: Could happen if Calendar logic fails (edge case but possible across timezones)
- Fix approach: Use optional binding or guard statements instead of force unwrapping.

**Hardcoded City Names in Map View:**
- Symptoms: Zoom functionality uses hardcoded city names that don't match sample data exactly or may become inconsistent
- Files: `Travel app/Views/Map/TripMapView.swift` (lines 55-70, zoom buttons for "Токио", "Киото", "Осака")
- Trigger: If sample data cities change, buttons silently fail to zoom to anything
- Fix approach: Derive zoom locations from actual day data dynamically instead of hardcoding.

**No Input Validation for Expense Amounts:**
- Symptoms: App accepts expense with amount 0, though UI validation checks for > 0
- Files: `Travel app/Views/Expenses/AddExpenseSheet.swift` (lines 123-124), `Travel app/ViewModels/TripStore.swift` (line 87)
- Trigger: If validation is bypassed programmatically
- Fix approach: Add model-level validation in Expense creation and store.addExpense().

## Security Considerations

**No Authentication/Authorization:**
- Risk: App is local-only with no multi-user or cloud sync, so limited exposure. However, if data is synced in future, no auth exists.
- Files: `Travel app/ViewModels/TripStore.swift`, `Travel app/Travel_appApp.swift`
- Current mitigation: App is local-only, so no network exposure.
- Recommendations: Design with user authentication in mind for future cloud features. Don't store sensitive trip data (addresses, coordinates) unencrypted if syncing to cloud.

**Hardcoded Locale in Date Formatters:**
- Risk: Multiple hardcoded Russian locale identifiers assume all users are Russian-speaking.
- Files: `Travel app/Views/Dashboard/DashboardView.swift` (line 128), `Travel app/Views/Itinerary/ItineraryView.swift` (line 8), `Travel app/Views/Itinerary/DayDetailView.swift` (line 9), `Travel app/Views/Journal/JournalView.swift` (line 13)
- Current mitigation: None - strings are in Russian throughout UI.
- Recommendations: Use Locale.current instead of hardcoded "ru_RU". Store trip names and place names in both English and Japanese for global compatibility.

**No Rate Limiting on Data Modifications:**
- Risk: Users can spam add/delete operations without throttling.
- Files: `Travel app/ViewModels/TripStore.swift`, all add/delete methods
- Current mitigation: None
- Recommendations: Add debouncing/throttling if data syncs to backend in future. Log all mutations for audit trail.

## Performance Bottlenecks

**Dashboard Counter Animation Unbounded:**
- Problem: Timer increments counter with `max(1, target / 20)` step, but this can create hundreds of Timer fires for large day numbers.
- Files: `Travel app/Views/Dashboard/DashboardView.swift` (lines 61-73)
- Cause: Linear step calculation with fixed interval doesn't scale to large numbers efficiently
- Improvement path: Use CADisplayLink or SwiftUI's animation instead of Timer. Or implement exponential backoff in step calculation.

**All Places Flattened in Every Computed Property:**
- Problem: `TripStore.allPlaces` uses `days.flatMap(\.places)` every time it's accessed. Called multiple times per view render.
- Files: `Travel app/ViewModels/TripStore.swift` (lines 30-32, 34-35, 38-40)
- Cause: No caching of computed properties. flatMap is O(n) for places count.
- Improvement path: Cache allPlaces and invalidate when days change. Or use lazy evaluation.

**Map Rendering All Places at Once:**
- Problem: TripMapView renders Annotation for every place without lazy loading or clustering.
- Files: `Travel app/Views/Map/TripMapView.swift` (lines 23-32)
- Cause: No pagination or map clustering for dense areas (Tokio has many places)
- Improvement path: Use MapKit clustering API or paginate map markers. Pre-filter to current day or visible region.

**DashboardView Layout Complexity:**
- Problem: Massive view with 391 lines, complex layout with nested ForEach and GeometryReader for every expense category bar.
- Files: `Travel app/Views/Dashboard/DashboardView.swift`
- Cause: All UI in single view instead of extracted subviews
- Improvement path: Extract sections into separate views (HeroSection, BudgetSection, ExpenseRow, etc). Each under 150 lines.

**No Search or Filtering in Lists:**
- Problem: JournalView and ExpensesView render all entries without search capability. Large lists will scroll slowly.
- Files: `Travel app/Views/Journal/JournalView.swift`, `Travel app/Views/Expenses/ExpensesView.swift`
- Cause: No filtering or search state
- Improvement path: Add @State var searchText and filter sortedEntries by title/category before rendering.

## Fragile Areas

**Place/Day/Expense Mutation Logic:**
- Files: `Travel app/ViewModels/TripStore.swift` (lines 74-116)
- Why fragile: Multiple nested index lookups with guard statements that fail silently if IDs don't match. Complex array mutation logic with var reassignment.
- Safe modification: Always return early with clear error logging. Consider using @Binding or refactor to immutable update patterns.
- Test coverage: No tests visible. Logic relies on UI never passing invalid IDs.

**Date Calculations in Models:**
- Files: `Travel app/Models/TripModels.swift` (lines 16-35)
- Why fragile: Trip.currentDay and Trip.progress rely on Calendar.dateComponents which can fail silently or produce off-by-one errors across timezones/DST.
- Safe modification: Add unit tests for edge cases (start of trip, end of trip, timezone changes, DST transitions). Document timezone assumptions.
- Test coverage: None visible. Calculations are only checked manually in dashboard.

**Category and Mood Enums Localization:**
- Files: `Travel app/Models/TripModels.swift` (PlaceCategory enum, ExpenseCategory enum, Mood enum - all use Russian rawValue)
- Why fragile: Localization is in enum rawValues, not in a localizable.strings file. If app ever needs English/Japanese, these must be refactored.
- Safe modification: Move all user-facing strings to Localizable.strings. Keep enum rawValues as identifiers (en_temple, en_shrine).
- Test coverage: No tests. String changes could break saved data.

**Sample Data Hardcoded Coordinates:**
- Files: `Travel app/Models/SampleData.swift` (many CLLocationCoordinate2D initializations)
- Why fragile: Coordinates are hardcoded. If a place closes or location changes, data becomes stale. No way to update without code change.
- Safe modification: Move to JSON configuration file or API. Consider using CoreLocation to validate coordinates at startup.
- Test coverage: None. No validation that coordinates are within Japan boundaries.

**NumberFormatter in Multiple Views:**
- Files: `Travel app/Views/Dashboard/DashboardView.swift` (lines 12-18), `Travel app/Views/Expenses/ExpensesView.swift` (lines 11-21)
- Why fragile: Yen formatting duplicated in multiple views. If formatting changes, all must be updated.
- Safe modification: Extract to a shared utility function in AppTheme or a separate Formatters module.
- Test coverage: No tests. Formatting edge cases (negative amounts, very large amounts) untested.

## Scaling Limits

**In-Memory Data Structure:**
- Current capacity: Can hold hundreds of days/places/expenses without issue
- Limit: If trip has 10,000+ places (not realistic) or app runs for weeks without restart, memory could accumulate
- Scaling path: Implement pagination in views. Archive old data. Use CoreData with lazy relationships.

**Map Annotations Without Clustering:**
- Current capacity: ~30-50 visible annotations before UI lag
- Limit: 200+ places on map becomes unusable
- Scaling path: Implement MapKit clustering. Or paginate to show only current day/nearby days.

**Flat Array Searches:**
- Current capacity: 50+ expenses/entries searches O(n) per filter
- Limit: 1000+ entries becomes slow to filter/sort
- Scaling path: Add indices. Use @Query with Core Data instead of manual arrays.

## Dependencies at Risk

**SwiftUI 5+ Requirement:**
- Risk: App uses @Observable macro which requires iOS 17+. Limited to recent devices.
- Impact: Cannot deploy to iOS 16 or older devices.
- Migration plan: If backward compatibility needed, refactor TripStore to use @ObservedObject + @Published instead of @Observable.

**CoreLocation for MapKit:**
- Risk: Coordinates are used but no location permission requested. Map view works without user location, but fragile if location features are added.
- Impact: If adding "current location" feature, will crash without permission request.
- Migration plan: Add NSLocationWhenInUseUsageDescription to Info.plist and request CLLocationManager permission before accessing location.

**MapKit Standard Maps Style Hardcoded:**
- Risk: Apple may change POI availability (.museum, .nationalPark, .park, .restaurant). Custom map styles may break iOS updates.
- Impact: Map filtering could fail silently on future iOS versions.
- Migration plan: Add fallback to .standard style without POI filters. Test on iOS betas.

## Missing Critical Features

**No Trip Export/Backup:**
- Problem: No way to export trip data (PDF, JSON, CSV). All data in app only.
- Blocks: Sharing trip itineraries, backup, planning on web.
- Priority: Medium - blocks sharing use case.

**No Offline Map Caching:**
- Problem: Map requires internet to load tiles. No offline mode.
- Blocks: Using app in areas with poor connectivity (common in remote Japan areas).
- Priority: High - breaks core itinerary planning while traveling.

**No Place Editing or Deletion:**
- Problem: Places in itinerary cannot be edited after creation. Can only toggle visited/rate.
- Blocks: Fixing typos, changing times, removing unvisited places.
- Priority: Medium - UX friction for planning iterations.

**No Budget Category Limits:**
- Problem: Budget shows total spent vs total budget, but no per-category spending limits.
- Blocks: Controlling spending in specific areas (e.g., max 20k on shopping, max 10k on activities).
- Priority: Low - nice-to-have for budget management.

**No Trip Comparison or History:**
- Problem: App only supports one trip at a time. No past trips viewable.
- Blocks: Referencing previous trips, year-to-year comparisons, trip statistics.
- Priority: Low - nice-to-have for repeat travelers.

## Test Coverage Gaps

**No Unit Tests:**
- What's not tested: Trip.progress calculation, Trip.currentDay logic, date parsing edge cases, expense filtering and sorting.
- Files: `Travel app/Models/TripModels.swift`, `Travel app/ViewModels/TripStore.swift`
- Risk: Bugs in date math, silent calculation failures, off-by-one errors.
- Priority: High - core business logic untested.

**No View Tests:**
- What's not tested: DashboardView counter animation, DayDetailView place toggle, ExpensesView delete functionality.
- Files: `Travel app/Views/` (all files)
- Risk: UI state mutations fail silently, animations break, navigation fails.
- Priority: Medium - requires snapshot or XCUITest framework.

**No Integration Tests:**
- What's not tested: TripStore.deleteExpense with cascading index updates, store.togglePlaceVisited affecting computed properties.
- Files: `Travel app/ViewModels/TripStore.swift`
- Risk: Complex mutations create inconsistent app state.
- Priority: High - data integrity at risk.

**No Precision Testing for Animations:**
- What's not tested: Counter increments correctly to target, timer fires expected number of times, animation completes without memory leaks.
- Files: `Travel app/Views/Dashboard/DashboardView.swift` (animateCounter function)
- Risk: Silent animation failures, performance degradation.
- Priority: Medium - less visible but affects UX.

---

*Concerns audit: 2026-02-28*
