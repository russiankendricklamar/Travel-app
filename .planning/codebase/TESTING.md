# Testing Patterns

**Analysis Date:** 2026-02-28

## Test Framework

**Status:** No testing framework currently configured

**Coverage:** 0% - No test files exist

**Why Testing is Absent:**
This is an early-stage SwiftUI application (initial commit on 2026-02-28) focused on rapid feature development. The codebase is suitable for test introduction before scaling further.

## Recommended Test Setup

**Framework Recommendations:**

**Unit Testing:**
- Use XCTest (built-in, no external dependency)
- Configuration file: `Travel appTests/Travel_appTests.swift` (naming convention)

**UI/Integration Testing:**
- Use XCTest with SwiftUI preview testing
- Alternative: Consider adding `Testing` framework (Swift 6+) for better async/await support

**Preview Testing:**
- Leverage existing `#Preview` blocks for visual regression
- Example: `DashboardView`, `MainTabView`, all views have preview definitions

## Current Test Coverage Gaps

**Critical Areas Without Tests:**

**State Management (`TripStore`):**
- File: `/Users/egorgalkin/Travel app/Travel app/ViewModels/TripStore.swift`
- Missing tests:
  - `togglePlaceVisited()` - Place visited state toggle
  - `addExpense()` - Expense creation and appending
  - `deleteExpense()` - Deletion by IndexSet with date-sorted filtering
  - `ratePlace()` - Rating assignment to places
  - Computed properties: `totalSpent`, `budgetUsedPercent`, `expensesByCategory`

**Model Validation:**
- File: `/Users/egorgalkin/Travel app/Travel app/Models/TripModels.swift`
- Missing tests:
  - `Trip.totalDays` calculation
  - `Trip.currentDay` calculation (requires date comparison)
  - `Trip.progress` computation
  - `TripDay.visitedCount` filtering

**Form Validation:**
- File: `/Users/egorgalkin/Travel app/Travel app/Views/Expenses/AddExpenseSheet.swift`
- Missing tests for `isValid` computed property:
  - Empty title validation
  - Invalid amount format
  - Boundary conditions (zero, negative amounts)

**Data Formatting:**
- File: `/Users/egorgalkin/Travel app/Travel app/Views/Dashboard/DashboardView.swift`
- Missing tests:
  - `formatYen()` function with various amounts
  - Date formatting with Russian locale
  - Number grouping with spaces

**Sample Data:**
- File: `/Users/egorgalkin/Travel app/Travel app/Models/SampleData.swift`
- Missing tests:
  - Sample data builds correctly
  - All places have valid coordinates
  - All dates are within trip boundaries

## Recommended Test Structure

**Directory Layout:**
```
Travel app/
├── Travel app/                     # Source code
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   └── Theme/
└── Travel appTests/                # Test target
    ├── Models/
    │   ├── TripModelsTests.swift
    │   └── SampleDataTests.swift
    ├── ViewModels/
    │   └── TripStoreTests.swift
    ├── Views/
    │   └── AddExpenseSheetTests.swift
    └── Utilities/
        └── FormValidationTests.swift
```

## Suggested Test Examples

**Unit Test Pattern for State Management:**

```swift
import XCTest
@testable import Travel_app

final class TripStoreTests: XCTestCase {
    var sut: TripStore!

    override func setUp() {
        super.setUp()
        sut = TripStore()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Expense Tests

    func testAddExpense() {
        // Arrange
        let initialCount = sut.expenses.count
        let expense = Expense(
            id: UUID(),
            title: "Test",
            amount: 1000,
            category: .food,
            date: Date(),
            notes: ""
        )

        // Act
        sut.addExpense(expense)

        // Assert
        XCTAssertEqual(sut.expenses.count, initialCount + 1)
        XCTAssertTrue(sut.expenses.contains { $0.id == expense.id })
    }

    func testTotalSpentUpdatesOnExpenseAdd() {
        // Arrange
        let initialTotal = sut.totalSpent
        let expense = Expense(
            id: UUID(),
            title: "Ramen",
            amount: 1290,
            category: .food,
            date: Date(),
            notes: ""
        )

        // Act
        sut.addExpense(expense)

        // Assert
        XCTAssertEqual(sut.totalSpent, initialTotal + 1290)
    }

    func testTogglePlaceVisited() {
        // Arrange
        let firstDay = sut.days.first!
        let place = firstDay.places.first!
        let initialVisitedCount = firstDay.visitedCount

        // Act
        sut.togglePlaceVisited(dayId: firstDay.id, placeId: place.id)

        // Assert
        let updatedDay = sut.days.first { $0.id == firstDay.id }!
        let updatedPlace = updatedDay.places.first { $0.id == place.id }!
        XCTAssertTrue(updatedPlace.isVisited)
    }

    // MARK: - Computed Property Tests

    func testBudgetUsedPercent() {
        // Test boundary conditions
        XCTAssertEqual(sut.budgetUsedPercent, sut.totalSpent / sut.trip.budget)

        // When over budget
        let overBudgetExpense = Expense(
            id: UUID(),
            title: "Big expense",
            amount: sut.trip.budget * 2,
            category: .accommodation,
            date: Date(),
            notes: ""
        )
        sut.addExpense(overBudgetExpense)
        XCTAssertGreaterThan(sut.budgetUsedPercent, 1.0)
    }

    func testExpensesByCategory() {
        // Should be sorted by total descending
        let categories = sut.expensesByCategory
        for i in 0..<(categories.count - 1) {
            XCTAssertGreaterThanOrEqual(categories[i].total, categories[i + 1].total)
        }
    }
}
```

**Unit Test Pattern for Model Calculations:**

```swift
import XCTest
@testable import Travel_app

final class TripModelsTests: XCTestCase {

    func testTripProgress() {
        // Arrange
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let endDate = calendar.date(byAdding: .day, value: 5, to: Date())!

        let trip = Trip(
            id: UUID(),
            name: "Test Trip",
            destination: "Japan",
            startDate: startDate,
            endDate: endDate,
            budget: 100000,
            currency: "JPY",
            coverSystemImage: "airplane"
        )

        // Act
        let progress = trip.progress

        // Assert
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThan(progress, 1.0)
    }

    func testTripCurrentDay() {
        // Arrange
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -3, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 7, to: today)!

        let trip = Trip(
            id: UUID(),
            name: "Test",
            destination: "Japan",
            startDate: startDate,
            endDate: endDate,
            budget: 100000,
            currency: "JPY",
            coverSystemImage: "airplane"
        )

        // Act
        let currentDay = trip.currentDay

        // Assert
        XCTAssertEqual(currentDay, 4) // 3 days passed + 1
    }

    func testVisitedCountFilter() {
        // Arrange
        let place1 = Place(id: UUID(), name: "P1", nameJapanese: "P1", category: .temple,
                          address: "Addr", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                          isVisited: true, rating: 5, notes: "", timeToSpend: "1h")
        let place2 = Place(id: UUID(), name: "P2", nameJapanese: "P2", category: .food,
                          address: "Addr", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                          isVisited: false, rating: nil, notes: "", timeToSpend: "1h")

        let day = TripDay(id: UUID(), date: Date(), title: "Day", cityName: "City",
                         places: [place1, place2], notes: "")

        // Act
        let visitedCount = day.visitedCount

        // Assert
        XCTAssertEqual(visitedCount, 1)
    }
}
```

**Unit Test Pattern for Validation:**

```swift
import XCTest
@testable import Travel_app

final class FormValidationTests: XCTestCase {

    func testExpenseFormValidation() {
        // Valid form
        let validTitle = "Ramen"
        let validAmount = "1290"
        let isValid = !validTitle.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(validAmount) != nil
            && Double(validAmount)! > 0

        XCTAssertTrue(isValid)
    }

    func testEmptyTitleInvalidation() {
        let emptyTitle = ""
        let amount = "1290"
        let isValid = !emptyTitle.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(amount) != nil

        XCTAssertFalse(isValid)
    }

    func testZeroAmountInvalidation() {
        let title = "Expense"
        let amount = "0"
        let doubleAmount = Double(amount) ?? -1
        let isValid = doubleAmount > 0

        XCTAssertFalse(isValid)
    }

    func testNegativeAmountInvalidation() {
        let title = "Expense"
        let amount = "-100"
        let doubleAmount = Double(amount) ?? 0
        let isValid = doubleAmount > 0

        XCTAssertFalse(isValid)
    }
}
```

## Preview Testing (Current Testing Method)

**Existing Preview Blocks:**

All views include `#Preview` blocks for visual testing:

```swift
#Preview {
    MainTabView(store: TripStore())
        .preferredColorScheme(.dark)
}
```

Files with previews:
- `MainTabView.swift` - Main navigation structure
- `DashboardView.swift` - Dashboard visualization
- `AddExpenseSheet.swift` - Form input
- `ItineraryView.swift` - Day itinerary list
- `JournalView.swift` - Journal entries
- `StatCard.swift` - Reusable components
- `TripMapView.swift` - Map visualization

**How to Use Previews:**
1. Open file in Xcode
2. Press Cmd+Alt+P to show preview
3. Run preview to test UI interactively
4. Previews use `TripStore()` with sample data from `SampleData.swift`

## Testing Best Practices for This Codebase

**What to Test First (Priority Order):**

1. **High Priority - Core Business Logic**
   - `TripStore` state mutations
   - Date/progress calculations in `Trip` model
   - Budget computations

2. **Medium Priority - Data Validation**
   - Form validation in add sheets
   - Number and date formatting
   - Category filtering

3. **Lower Priority - UI (Use Previews)**
   - Component rendering
   - Layout and spacing (verify visually)
   - Color application

**Testing Patterns to Follow:**

```swift
// Arrange-Act-Assert (AAA) pattern
func testSomething() {
    // Arrange: Set up initial state
    let store = TripStore()
    let initialCount = store.expenses.count

    // Act: Perform the action
    store.addExpense(testExpense)

    // Assert: Verify results
    XCTAssertEqual(store.expenses.count, initialCount + 1)
}
```

**Mocking Strategy:**

For testing views with `TripStore`:
```swift
// Use TripStore() directly with SampleData
let store = TripStore()  // Creates fully populated store

// Create minimal test stores for unit testing
@Observable class MockTripStore: TripStore {
    override init() {
        super.init()
        // Override with minimal test data
    }
}
```

**Edge Cases to Test:**

1. Empty collections (no expenses, no days)
2. Boundary values (0 budget, negative remaining)
3. Invalid date ranges
4. Duplicate UUIDs
5. String encoding (Russian text in titles)
6. Amount precision (floating point rounding)

## Performance Testing Notes

**No performance tests currently needed**, but watch for:
- Large list rendering (100+ expenses)
- Map annotation rendering (50+ places)
- Lazy loading optimization in `ItineraryView` (uses `LazyVStack`)

## Run Commands (Once Tests Added)

```bash
# Run all tests
xcodebuild test -scheme "Travel app"

# Run specific test class
xcodebuild test -scheme "Travel app" -testClass TripStoreTests

# Run with coverage
xcodebuild test -scheme "Travel app" -enableCodeCoverage YES

# View coverage report
open $(xcodebuild test -scheme "Travel app" -enableCodeCoverage YES 2>&1 | grep -o '/var.*\.profdata')
```

---

*Testing analysis: 2026-02-28*
