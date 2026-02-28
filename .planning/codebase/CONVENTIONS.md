# Coding Conventions

**Analysis Date:** 2026-02-28

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `DashboardView.swift`, `TripStore.swift`, `TripModels.swift`
- Feature-based grouping: Views organized by feature (`Dashboard/`, `Expenses/`, `Itinerary/`, `Journal/`, `Map/`)
- Component files grouped in `Components/` directory: `StatCard.swift`, `DarkTextFieldStyle`

**Functions:**
- camelCase for all functions and methods: `formatYen()`, `togglePlaceVisited()`, `saveExpense()`
- Private helper functions with underscore prefix avoided; use `private` keyword: `private func animateIn()`
- Verb-first naming for action functions: `togglePlaceVisited()`, `addExpense()`, `deleteExpense()`, `ratePlace()`

**Variables & Properties:**
- camelCase for all variable names: `selectedTab`, `heroScale`, `budgetWidth`, `counterValue`
- Private state variables prefixed with `private`: `@State private var appeared`, `@State private var showingAddSheet`
- Computed properties use descriptive names: `totalSpent`, `remainingBudget`, `budgetUsedPercent`, `placesVisitedCount`
- Environment values use `@Environment(\.dismiss) private var dismiss`

**Types & Structs:**
- PascalCase for all struct and enum names: `Trip`, `TripDay`, `Place`, `Expense`, `JournalEntry`, `TripStore`
- Enum cases use camelCase: `.amazing`, `.happy`, `.neutral`, `.tired`, `.frustrated`
- Raw values for enums are in Russian (localized): `"Храм"`, `"Еда"`, `"Жильё"`
- Optional Int for ratings: `rating: Int?`

**Constants:**
- PascalCase for theme constants: `AppTheme.toriiRed`, `AppTheme.bambooGreen`
- Semantic constants defined in `AppTheme`: `primary`, `success`, `warning`, `info`

## Code Style

**Formatting:**
- No explicit formatter configured (inferred from code patterns)
- Consistent spacing: 4-space indentation observed
- Line wrapping: Long lines kept under 100 characters where possible
- View hierarchy indented for clarity

**Linting:**
- No explicit linting tool configured
- Follows Swift coding style guidelines implicitly

**View Organization:**
- Each SwiftUI view uses `MARK: -` comments to organize sections
- Example from `DashboardView.swift`: `// MARK: - Hero`, `// MARK: - Red Banner`, `// MARK: - Stats`, `// MARK: - Budget`
- Private computed properties grouped after main `body`
- Helper functions at bottom of file

**View Structure Pattern:**
```swift
struct ViewName: View {
    // MARK: - Dependencies (first)
    let store: TripStore

    // MARK: - State
    @State private var state = value

    // MARK: - Computed Properties
    private var computed: Type {
        // implementation
    }

    // MARK: - Body
    var body: some View {
        // UI hierarchy
    }

    // MARK: - Section Name
    private var sectionName: some View {
        // implementation
    }

    private func helperFunction() {
        // implementation
    }
}
```

## Import Organization

**Order:**
1. Foundation (implicit)
2. SwiftUI (always first explicit import)
3. Framework imports (MapKit, CoreLocation)
4. Observation framework for state management

**Examples from codebase:**
```swift
import SwiftUI          // Always first
import MapKit           // Domain-specific frameworks
import CoreLocation
import Observation      // State management
```

**No path aliases used** - relative imports from same module.

## Error Handling

**Input Validation:**
- Form validation before saving: `private var isValid: Bool` computed property in `AddExpenseSheet`
- Guard statements for optional unwrapping: `guard let dayIndex = days.firstIndex(where: { $0.id == dayId })`
- Nil-coalescing with defaults: `Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0`

**Patterns:**
```swift
// In AddExpenseSheet.swift - computed validation
private var isValid: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty
        && Double(amountText) != nil
        && Double(amountText)! > 0
}

// Guard with early return
guard let amount = Double(amountText), amount > 0 else { return }

// Optional unwrap in model
guard totalDays > 0 else { return 0 }
return Double(currentDay) / Double(totalDays)
```

**No thrown errors** - app uses optional returns and validation instead.

## Logging

**Framework:** console prints not used - logging removed from production code

**Patterns:**
- No logging statements observed in codebase
- Silent failures with guard statements returning early

## Comments

**When to Comment:**
- Section separators using `// MARK: -` pattern
- Comments mark logical view sections and computed properties
- Minimal inline comments; code is self-documenting

**MARK Format:**
```swift
// MARK: - Section Name
```
Used consistently throughout for:
- Model types: `// MARK: - Trip`, `// MARK: - Expense`
- View sections: `// MARK: - Hero`, `// MARK: - Budget`
- Reusable components: `// MARK: - Progress Ring`

**Documentation:**
- No JSDoc/TSDoc (Swift doesn't use this pattern)
- No detailed function documentation comments observed

## Function Design

**Size:**
- Small focused functions: most helpers 5-25 lines
- View layout helpers broken into small computed properties
- Example: `bannerStat()` is 12 lines, `formField()` is 7 lines, `animateCounter()` is 18 lines

**Parameters:**
- Closures used for ViewBuilder in form fields: `@ViewBuilder content: () -> Content`
- Optional closures for callbacks: `var onRate: ((Int) -> Void)?`
- No parameter validation beyond guard checks

**Return Values:**
- Some View types returned from computed properties
- Boolean flags for validation (`isValid`, `isActive`)
- Arrays and computed aggregates: `expensesByCategory`, `allPlaces`, `placesVisitedCount`

## Module Design

**Exports:**
- All main structures public (no explicit `public` keyword; defaults to internal in app target)
- Views and ViewModels follow standard SwiftUI patterns

**Barrel Files:**
- No barrel/index files used
- Each file imports what it needs independently
- Views import `AppTheme` and `TripStore` explicitly

**Code Organization by Layer:**
- `Models/` - Data structures and enums (`TripModels.swift`, `SampleData.swift`)
- `ViewModels/` - State management (`TripStore.swift` with @Observable)
- `Views/` - SwiftUI components organized by feature
- `Theme/` - Design system (`AppTheme.swift` with extensions)
- `Components/` - Reusable UI components (`StatCard.swift`)

## State Management

**Pattern:** `@Observable` macro from Observation framework (iOS 17+)

```swift
@Observable
final class TripStore {
    // Public properties automatically tracked
    var trip: Trip
    var days: [TripDay]
    var expenses: [Expense]
    var journalEntries: [JournalEntry]

    // Computed properties for derived data
    var totalSpent: Double { ... }

    // Methods modify state directly
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }
}
```

**Local State:** `@State` for view-local ephemeral state only

**Environment:** `@Environment(\.dismiss)` for system environment values

## Data Mutation Patterns

**Immutable Model Updates:**
When updating nested models, SwiftUI patterns are observed:

```swift
func togglePlaceVisited(dayId: UUID, placeId: UUID) {
    guard let dayIndex = days.firstIndex(where: { $0.id == dayId }),
          let placeIndex = days[dayIndex].places.firstIndex(where: { $0.id == placeId }) else {
        return
    }
    days[dayIndex].places[placeIndex] = {
        var place = days[dayIndex].places[placeIndex]
        place.isVisited.toggle()
        return place
    }()
}
```

Pattern: Create temporary mutable copy, modify, reassign.

## Formatting Numbers & Dates

**Number Formatting:**
```swift
private func formatYen(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    let formatted = formatter.string(from: NSNumber(value: Int(amount))) ?? "0"
    return "\u{00A5}\(formatted)"
}
```

**Date Formatting:**
```swift
private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ru_RU")
    f.dateFormat = "EEE, d MMM"
    return f
}()
```

Lazy-initialized formatters to avoid recreation.

## Design System

**Theme System:** Centralized in `AppTheme` enum with computed properties

**Color Palette:**
- Background: Pure black (`#000000`) for brutalist aesthetic
- Accents: Japan-themed colors (`toriiRed`, `sakuraPink`, `templeGold`, `bambooGreen`, `oceanBlue`)
- Text: High contrast whites and grays

**Spacing System:**
- Defined constants: `spacingXS` (4pt) through `spacingXL` (32pt)
- Applied consistently: `AppTheme.spacingM` for standard padding

**Brutalist Styling:**
- Zero border radius: `radiusSmall: CGFloat = 0`
- Rectangular boxes: No rounded corners
- Hard borders: `borderWidth: CGFloat = 2`

**View Modifiers:**
- `.cardStyle()` - Card background with border
- `.surfaceStyle()` - Surface background with border
- `.accentCardStyle()` - Accent border variant

---

*Convention analysis: 2026-02-28*
