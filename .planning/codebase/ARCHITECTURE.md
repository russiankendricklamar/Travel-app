# Architecture

**Analysis Date:** 2026-02-28

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with SwiftUI's modern Observation framework

**Key Characteristics:**
- Single source of truth via `@Observable` TripStore
- Declarative SwiftUI UI composition
- Unidirectional data flow (Store → Views)
- Stateless components with environment-based store access
- Brutalist design system with zero rounded corners and bold typography

## Layers

**Model Layer:**
- Purpose: Domain models representing trip data structures
- Location: `Travel app/Models/`
- Contains: Data structures (Trip, TripDay, Place, Expense, JournalEntry, enums)
- Depends on: Foundation, CoreLocation
- Used by: ViewModels and Views
- Key files: `TripModels.swift` (domain entities), `SampleData.swift` (test/demo data)

**ViewModel Layer:**
- Purpose: State management and business logic
- Location: `Travel app/ViewModels/TripStore.swift`
- Contains: Single observable store managing all trip state
- Depends on: Models, Foundation, Observation
- Used by: All Views
- Pattern: `@Observable` final class with computed properties and action methods

**View Layer:**
- Purpose: UI presentation in SwiftUI
- Location: `Travel app/Views/`
- Contains: View compositions organized by feature
- Depends on: Models, ViewModels, Theme
- Sub-layers:
  - **Container Views:** MainTabView (5-tab navigation root)
  - **Feature Views:** DashboardView, ItineraryView, TripMapView, ExpensesView, JournalView
  - **Detail Views:** DayDetailView, AddJournalEntrySheet, AddExpenseSheet
  - **Reusable Components:** StatCard, ProgressRing, CategoryBadge, StarRatingView

**Theme Layer:**
- Purpose: Design system and visual constants
- Location: `Travel app/Theme/AppTheme.swift`
- Contains: Color palette, spacing values, typography scales, ViewModifiers
- Depends on: SwiftUI
- Used by: All Views
- Pattern: Static enum with type-safe color/spacing functions

## Data Flow

**Trip Data Initialization:**

1. App launches → `Travel_appApp` creates `TripStore()`
2. `TripStore.init()` calls `SampleData.build()`
3. SampleData creates Trip, TripDays, Expenses, JournalEntries
4. Store state initialized with sample data
5. Store injected into MainTabView

**User Actions (Example: Toggle Place Visited):**

1. User taps place checkbox in DayDetailView
2. View calls `store.togglePlaceVisited(dayId:, placeId:)`
3. TripStore mutates `days` array (immutable pattern per action)
4. `@Observable` notifies all dependent views
5. Views re-render with new state

**Budget Tracking:**

1. Store computes `totalSpent` from expenses array (reducer)
2. Computed property automatically tracks changes
3. DashboardView observes and displays:
   - Budget usage percentage
   - Spent amount
   - Remaining budget
   - Expense breakdown by category
   - Color-coded progress indicators

**Journal & Expense Management:**

1. Add actions: `addExpense()`, `addJournalEntry()`
2. Delete actions: `deleteExpense(at:)`, `deleteJournalEntry(at:)`
3. Rating action: `ratePlace(dayId:, placeId:, rating:)`

**State Management:**

- Single source of truth: `TripStore` (@Observable)
- Immutable updates: Each action returns new struct instances
- Computed properties: Derived state (totalSpent, remainingBudget, budgetUsedPercent, expensesByCategory, allPlaces, placesVisitedCount, todayDay)
- No callbacks, no delegates, no manual binding complexity

## Key Abstractions

**Identifiable Models:**

All domain models conform to `Identifiable`:
- `Trip`, `TripDay`, `Place`, `Expense`, `JournalEntry`
- Use UUID for unique identity
- Enables SwiftUI ForEach without explicit id parameter

**Category Enums:**

- `PlaceCategory`: 8 types (temple, shrine, food, shopping, nature, culture, accommodation, transport)
- `ExpenseCategory`: 6 types (food, transport, accommodation, activities, shopping, other)
- `Mood`: 5 types (amazing, happy, neutral, tired, frustrated)
- Each enum: CaseIterable, Identifiable, maps to system image and localized string

**Date Calculations:**

Trip provides computed properties:
- `totalDays`: days between start and end dates
- `currentDay`: current progress (0 if not started, totalDays if ended)
- `isActive`: boolean whether trip is happening now
- `progress`: Double (0.0-1.0) for progress bars

TripDay provides:
- `visitedCount`: count of visited places

**Theme Colors:**

Static functions support dynamic color selection:
- `categoryColor(for:)` - Place category colors
- `expenseColor(for:)` - Expense category colors
- `moodColor(for:)` - Journal mood colors

**ViewModifiers:**

Reusable style modifiers:
- `cardStyle()` - Card background with 2px border
- `surfaceStyle()` - Surface background with 2px border
- `accentCardStyle()` - Card with 3px red accent border

## Entry Points

**App Entry:**
- Location: `Travel app/Travel_appApp.swift`
- Triggers: App launch
- Responsibilities:
  - Creates TripStore (@State)
  - Configures dark color scheme
  - Creates WindowGroup with MainTabView

**Root View:**
- Location: `Travel app/Views/MainTabView.swift`
- Triggers: App visible
- Responsibilities:
  - TabView navigation (5 tabs)
  - Tab state management (@State selectedTab)
  - Passes store to all feature views

**Feature Roots:**
- DashboardView: Summary stats, budget, recent expenses
- ItineraryView: Day-by-day trip schedule
- TripMapView: Map visualization of places
- ExpensesView: Expense history and management
- JournalView: Journal entries list and editing

## Error Handling

**Strategy:** Defensive programming with computed properties

**Patterns:**

- Place rating is Optional<Int> (nil until rated)
- Journal mood is required (defaults to available enum value)
- Date calculations use Calendar.current with fallback Int (returns 0)
- Array access uses `firstIndex(where:)` with guard statements
- No thrown errors in current implementation (simple state management)

## Cross-Cutting Concerns

**Logging:** Not implemented (simple app, no external integrations)

**Validation:**
- Model validation in SampleData only (test data)
- No user input validation yet (no edit screens for Trip/TripDay properties)

**Authentication:** Not applicable (local data only)

**Theming:**
- AppTheme enum controls all colors, spacing, typography
- Dark mode enforced via `.preferredColorScheme(.dark)`
- Zero rounded corners (brutalist aesthetic)
- Monospaced fonts for numerical data
- High contrast text colors (white, gray, red)

---

*Architecture analysis: 2026-02-28*
