# Testing Patterns

**Analysis Date:** 2026-03-20

## Test Framework

**Runner:**
- XCTest (native Xcode testing framework)
- Version: Implicit (part of Xcode)
- Config: No explicit config file (uses Xcode defaults)

**Assertion Library:**
- XCTest assertions: `XCTAssertTrue()`, `XCTAssertEqual()`, `XCTAssertNil()`, `XCTAssertNotNil()`
- Accuracy parameter for floating-point: `XCTAssertEqual(result, expected, accuracy: 0.01)`

**Run Commands:**
```bash
xcodebuild test                    # Run all tests
xcodebuild test -scheme Travel_app # Run scheme tests
Cmd+U in Xcode                     # Run tests in IDE
```

## Test File Organization

**Location:**
- Co-located in separate test target: `Travel appTests/`
- Target name matches main app with "Tests" suffix
- Separate from production code (not embedded in main target)

**Naming:**
- Test files: `[TargetName]Tests.swift` (e.g., `KeychainHelperTests.swift`, `CurrencyServiceTests.swift`, `TripModelTests.swift`)
- Test classes: `final class [ComponentName]Tests: XCTestCase`
- Test methods: `func test[Behavior]()` (e.g., `testSaveAndReadString`, `testConvertSameCurrency`, `testTripTotalDays`)

**Structure:**
```
Travel appTests/
├── TripModelTests.swift          # Model logic tests (Trip, TripDay, TripEvent, Place)
├── KeychainHelperTests.swift     # Keychain CRUD tests
├── CurrencyServiceTests.swift    # Currency conversion & formatting tests
```

## Test Structure

**Suite Organization:**

Pattern: Single test class per component with logical test grouping via method naming

```swift
final class KeychainHelperTests: XCTestCase {
    private let testKey = "test_keychain_helper_key"

    override func tearDown() {
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    // Test methods follow pattern: testBehavior()
    func testSaveAndReadString() { ... }
    func testReadNonexistentKey() { ... }
    func testDeleteKey() { ... }
}
```

**Patterns:**
- **Setup:** Properties initialized in class body (e.g., `testKey`); shared across test methods
- **Teardown:** `tearDown()` method for cleanup (delete test keys, reset state)
- **Isolation:** Each test method is independent; cleanup runs after every test
- **Naming:** Descriptive method names without "test_" prefix underscore convention

## Test Examples

**Unit Test - Keychain Helper:**
```swift
func testSaveAndReadString() {
    let saved = KeychainHelper.save(key: testKey, string: "hello")
    XCTAssertTrue(saved)
    let result = KeychainHelper.readString(key: testKey)
    XCTAssertEqual(result, "hello")
}
```

**Unit Test - Currency Conversion:**
```swift
func testConvertSameCurrency() {
    let result = svc.convert(100, from: "RUB", to: "RUB")
    XCTAssertEqual(result, 100, accuracy: 0.01)
}

func testConvertRubToOther() {
    let result = svc.convert(1000, from: "RUB", to: "USD")
    XCTAssertTrue(result > 0, "Conversion should produce positive result")
    XCTAssertTrue(result < 1000, "1000 RUB should be less than 1000 USD")
}
```

**Model Logic Test - Trip:**
```swift
func testTripTotalDays() {
    let trip = makeTrip(startOffset: 0, endOffset: 7)
    XCTAssertEqual(trip.totalDays, 7)
}

func testTripPhasePreTrip() {
    let trip = makeTrip(startOffset: 5, endOffset: 10)
    XCTAssertEqual(trip.phase, .preTrip)
}
```

## Mocking

**Framework:**
- No third-party mocking framework detected (OCMock, Mockito, etc.)
- Manual mocking via test doubles and stub data

**Patterns:**

**Manual Test Fixtures:**
```swift
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
```

**Dependency Stubbing:**
- Services use singletons (CurrencyService.shared, AuthManager.shared)
- Difficult to mock in tests; tests tend to use real service instances
- CurrencyService tests use live instance: `let svc = CurrencyService.shared`
- Fallback rates built into service for offline testing

**What to Mock:**
- API responses (not implemented; services tested with real SupabaseProxy)
- External dependencies (not applicable; direct integration)

**What NOT to Mock:**
- Business logic (tested directly on models)
- Time-dependent operations (use fixed test data with date offsets)
- Local database (SwiftData used directly in preview setup)

## Fixtures and Factories

**Test Data:**

Location: `Models/SampleData.swift` (shared across tests and previews)

```swift
enum SampleData {
    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let trip = Trip(
            name: "Путешествие по Японии",
            country: "Япония",
            startDate: startDate,
            endDate: endDate,
            budget: 500000,
            currency: "RUB",
            coverSystemImage: "airplane"
        )
        // ... setup related data
        context.insert(trip)
        try? context.save()
    }

    private static func makeTime(
        _ calendar: Calendar,
        base: Date,
        hour: Int,
        minute: Int = 0
    ) -> Date { ... }
}
```

**Preview Models (TripModels.swift):**
```swift
#if DEBUG
extension ModelContainer {
    @MainActor
    static var preview: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, configurations: config)
        SampleData.seed(into: container.mainContext)
        return container
    }
}

extension Trip {
    @MainActor
    static var preview: Trip {
        let container = ModelContainer.preview
        let descriptor = FetchDescriptor<Trip>()
        return try! container.mainContext.fetch(descriptor).first!
    }
}
#endif
```

**Factory Pattern:**
- Test helper methods: `makeTrip(startOffset:endOffset:)`, `makeTime(...)`
- Preset defaults for common scenarios (past, present, future trips)
- Override parameters for specific test cases

## Coverage

**Requirements:** No minimum coverage enforced (no .lcov config or CI checks detected)

**View Coverage:**
- Primarily via manual testing and live previews
- SwiftUI views tested indirectly via model/service unit tests
- No XCUITest/snapshot tests detected

**Service Coverage:**
- Core services have unit tests: CurrencyService, KeychainHelper
- API integration services (AirLabsService, PlaceInfoService) not unit tested (rely on live integration)
- Critical business logic (Trip calculations) covered: totalDays, progress, countdownToFlight, expensesByCategory

**Model Coverage:**
- TripModels.swift comprehensive: 14 test methods covering Trip, TripDay, TripEvent, Place
- Tests cover state transitions (isUpcoming, isActive, isPast) and calculations (totalDays, progress, expenses)

**View Coverage:**
- Gaps: No snapshot tests for UI component layout/styling
- Gaps: No integration tests for sync flow (SyncManager untested)
- Gaps: No E2E tests for user workflows

## Test Run Location

**Where Tests Execute:**
- Development simulator/device via Xcode
- CI pipeline: Not detected (no GitHub Actions, Jenkins, or .gitlab-ci.yml)

**Test Assertions Pattern:**
- Single-assertion focus vs. multi-assertion bundling
- Tests typically verify one behavior per method
- Some tests verify related conditions together: `testTripIsUpcoming()` checks three state properties

## Data Isolation

**Database Isolation:**
```swift
override func tearDown() {
    KeychainHelper.delete(key: testKey)
    super.tearDown()
}
```

- Keychain tests clean up after each test to prevent state leakage
- SwiftData tests use in-memory container: `ModelConfiguration(isStoredInMemoryOnly: true)`
- No cross-test data sharing; each test starts with clean state

**Network Isolation:**
- No mock HTTP interceptors
- Services that call live API (CurrencyService, AirLabsService) use real SupabaseProxy
- Tests assume network availability (offline scenarios not tested)

## Test Types

**Unit Tests (Current - 3 files):**
- **Scope:** Individual models and services
- **Approach:** Direct instantiation and assertion
- **Examples:**
  - `KeychainHelperTests`: CRUD operations on keychain
  - `CurrencyServiceTests`: Currency conversion math, formatting
  - `TripModelTests`: Trip state calculations (totalDays, phase, budget math)

**Integration Tests (Not Implemented):**
- Would test API client + server interaction
- Would verify sync workflow (SyncManager → Supabase)
- Would test photo upload with storage bucket
- Gap: No integration tests for cloud features

**E2E Tests (Not Implemented):**
- Would use XCUITest for user flows
- Example flow: Create trip → Add expense → Sync to cloud → Fetch on other device
- Gap: No E2E test framework set up

## Common Patterns

**Async Testing:**
- Current tests are synchronous only
- Services have async methods (fetchRates, signInWithGoogle) but not tested
- Pattern if implemented: `func testAsync() async { await service.method() }`

**Error Testing:**
```swift
// Not currently used; error cases not tested
// Would verify fallback behavior:
// If API fails, does service use fallbackRates? ← untested
```

**State Transition Testing:**
```swift
func testTripPhasePreTrip() {
    let trip = makeTrip(startOffset: 5, endOffset: 10)
    XCTAssertEqual(trip.phase, .preTrip)
}
```

## Test Maintenance Notes

**Fragile Tests:**
- `TripModelTests` uses real calendar dates — vulnerable to DST transitions and timezone changes
- Fix: Use explicit calendar with fixed timezone in test helpers
- `CurrencyServiceTests` relies on hardcoded count: `XCTAssertEqual(CurrencyService.supportedCurrencies.count, 5)` — brittle if currencies added

**Unmaintained Gaps:**
- No async/await test patterns established
- Error handling untested in services (fallback behavior not verified)
- Cloud sync (Supabase) untested
- Photo sync untested
- Authentication flows untested

## Recommended Test Targets

**High Priority (Not Covered, High Impact):**
1. `SyncManager` — critical cloud sync orchestrator
2. `AuthManager` + `SupabaseAuthService` — auth state critical
3. `PhotoSyncService` — data loss risk if upload fails
4. `LocationManager.resumeTrackingIfNeeded()` — geofence functionality

**Medium Priority (Partially Covered):**
1. Async service tests (CurrencyService.fetchRates, AirLabsService.fetchFlightData)
2. Error fallback behavior (offline mode, API failures)
3. Multi-trip state management (MainTabView computed properties)

**Low Priority (Nice to Have):**
1. SwiftUI component snapshot tests
2. E2E user flows (via XCUITest)
3. Performance tests for large dataset handling

---

*Testing analysis: 2026-03-20*
