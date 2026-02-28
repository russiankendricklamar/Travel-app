# Codebase Structure

**Analysis Date:** 2026-02-28

## Directory Layout

```
Travel app/
├── Travel app/
│   ├── Travel_appApp.swift          # App entry point, creates store
│   ├── ContentView.swift            # Unused placeholder view
│   ├── Models/
│   │   ├── TripModels.swift         # Domain models (Trip, TripDay, Place, etc.)
│   │   └── SampleData.swift         # Sample/test data for demo
│   ├── ViewModels/
│   │   └── TripStore.swift          # Observable state store (MVVM)
│   ├── Views/
│   │   ├── MainTabView.swift        # Root tabbed navigation (5 tabs)
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift  # Summary, budget, stats
│   │   ├── Itinerary/
│   │   │   ├── ItineraryView.swift  # Day list
│   │   │   └── DayDetailView.swift  # Day details & places
│   │   ├── Map/
│   │   │   └── TripMapView.swift    # Map visualization
│   │   ├── Expenses/
│   │   │   ├── ExpensesView.swift   # Expense list
│   │   │   └── AddExpenseSheet.swift # Add expense form
│   │   ├── Journal/
│   │   │   ├── JournalView.swift    # Journal entries list
│   │   │   └── AddJournalEntrySheet.swift # Entry editor
│   │   └── Components/
│   │       └── StatCard.swift       # Reusable card components
│   ├── Theme/
│   │   └── AppTheme.swift           # Design system & colors
│   └── Assets.xcassets/             # Images, app icons
├── Travel app.xcodeproj/            # Xcode project
└── .planning/
    └── codebase/                    # (This document location)
```

## Directory Purposes

**Travel app/** (main source)
- Purpose: All source code and resources
- Contains: Swift files, assets, configuration

**Models/**
- Purpose: Data model definitions and sample data
- Contains: Structs (Trip, TripDay, Place, Expense, JournalEntry), enums (PlaceCategory, ExpenseCategory, Mood), SampleData builder
- Key files: `TripModels.swift`, `SampleData.swift`

**ViewModels/**
- Purpose: State management and business logic
- Contains: TripStore observable class
- Key files: `TripStore.swift` (single source of truth)

**Views/**
- Purpose: All UI components (SwiftUI views)
- Contains: Organized by feature area
- Key files: See below

**Views/Dashboard/**
- DashboardView: Hero section (day counter), stats banner, budget visualization, recent expenses

**Views/Itinerary/**
- ItineraryView: List of trip days
- DayDetailView: Day details, place list with visit status, ratings

**Views/Map/**
- TripMapView: Map showing all places with coordinates

**Views/Expenses/**
- ExpensesView: Expense list, total spent, delete functionality
- AddExpenseSheet: Form to create new expense

**Views/Journal/**
- JournalView: Journal entries list with moods
- AddJournalEntrySheet: Entry editor with mood selector

**Views/Components/**
- StatCard: Stat display card (title, value, icon, color)
- ProgressRing: Square progress indicator (brutalist, not circular)
- CategoryBadge: Inline category label with icon
- StarRatingView: 5-star rating selector

**Theme/**
- AppTheme.swift:
  - Color palette (toriiRed, sakuraPink, templeGold, bambooGreen, oceanBlue)
  - Spacing scale (XS: 4, S: 8, M: 16, L: 24, XL: 32)
  - Typography (system fonts with monospaced for numbers)
  - Modifier extensions (cardStyle, surfaceStyle, accentCardStyle)

**Assets.xcassets/**
- App icons, accent colors, other resources

## Key File Locations

**Entry Points:**
- `Travel app/Travel_appApp.swift`: @main app struct, creates TripStore, configures dark mode
- `Travel app/Views/MainTabView.swift`: Root view with TabView (5 tabs)

**Configuration:**
- `Travel app/Theme/AppTheme.swift`: All visual constants and design tokens

**Core Logic:**
- `Travel app/ViewModels/TripStore.swift`: @Observable store, all state mutations
- `Travel app/Models/TripModels.swift`: Domain entities

**Features:**
- Dashboard: `Travel app/Views/Dashboard/DashboardView.swift`
- Itinerary: `Travel app/Views/Itinerary/ItineraryView.swift`, `DayDetailView.swift`
- Map: `Travel app/Views/Map/TripMapView.swift`
- Expenses: `Travel app/Views/Expenses/ExpensesView.swift`, `AddExpenseSheet.swift`
- Journal: `Travel app/Views/Journal/JournalView.swift`, `AddJournalEntrySheet.swift`

**Testing:**
- `Travel app/Models/SampleData.swift`: Demo data for previews and runtime

## Naming Conventions

**Files:**
- PascalCase for Swift files: `TripStore.swift`, `DashboardView.swift`
- Suffix pattern: `*View.swift` for SwiftUI views, `*Store.swift` for state
- Sheet components: `Add*Sheet.swift` (e.g., `AddExpenseSheet.swift`)

**Structs:**
- PascalCase: `Trip`, `TripDay`, `Place`, `Expense`, `JournalEntry`
- Enums: `PlaceCategory`, `ExpenseCategory`, `Mood`
- ViewModels: `TripStore` (suffix: Store)

**Functions & Variables:**
- camelCase: `togglePlaceVisited()`, `formatYen()`, `animateIn()`
- Computed properties: camelCase with verb prefixes: `totalSpent`, `budgetUsedPercent`, `allPlaces`
- Actions: Verb-first: `addExpense()`, `deleteExpense()`, `ratePlace()`

**Colors:**
- Semantic naming: `toriiRed`, `sakuraPink`, `templeGold`, `bambooGreen`, `oceanBlue`
- Text: `textPrimary`, `textSecondary`, `textMuted`
- Backgrounds: `background`, `surface`, `card`, `cardHover`

**Spacing:**
- Scale-based: `spacingXS` (4), `spacingS` (8), `spacingM` (16), `spacingL` (24), `spacingXL` (32)

## Where to Add New Code

**New Feature (e.g., "Itinerary Notes"):**
- Primary code: Create `Views/ItineraryNotes/ItineraryNotesView.swift`
- Store methods: Add to `ViewModels/TripStore.swift` (addNote, deleteNote, etc.)
- Models: Add NoteType enum to `Models/TripModels.swift` if needed
- Sample data: Extend `SampleData.buildNotes()` function
- Navigation: Add tab to `Views/MainTabView.swift`

**New Reusable Component (e.g., "Chip"):**
- Implementation: `Views/Components/ChipView.swift`
- Styling: Use AppTheme colors and spacing
- Include preview at bottom of file

**New Enum or Struct:**
- Models: `Models/TripModels.swift` (if domain entity)
- Extension in the file where used (if helper type)

**Utilities/Helpers:**
- New file pattern: Create in appropriate feature folder (e.g., `Views/Components/Extensions.swift`)
- Or `Models/Utilities.swift` for cross-cutting helpers
- Keep files focused (<400 lines)

**Theme Updates:**
- All colors/spacing: `Theme/AppTheme.swift`
- Don't hardcode values in views

**Sample/Test Data:**
- `Models/SampleData.swift` with build functions separated by entity type

## Special Directories

**Assets.xcassets/**
- Purpose: App icons, colors, images
- Generated: Partially (some Xcode-managed, some manual)
- Committed: Yes

**Travel app.xcodeproj/**
- Purpose: Xcode project configuration
- Generated: Yes (Xcode manages this)
- Committed: Yes (project.pbxproj and some metadata)

**.planning/codebase/**
- Purpose: GSD documentation (this location)
- Generated: No (manually created)
- Committed: Yes

## File Size Guidelines

**Current State:**
- Largest views: DashboardView (392 lines) - acceptable but at upper limit
- Typical views: 100-250 lines
- Components: 30-150 lines
- Store: 118 lines

**When to Extract:**
- Views >300 lines: Extract sub-views as separate files
- Multiple responsibilities: Extract helper functions or components
- Reusable logic: Create in Views/Components/ or Models/

**Example Refactoring Pattern:**
If DashboardView grows:
- Extract `heroSection` → `Views/Dashboard/HeroSectionView.swift`
- Extract `budgetSection` → `Views/Dashboard/BudgetSectionView.swift`
- Keep main DashboardView as container orchestrator

## Patterns for New Code

**Adding Store Actions:**
```swift
// In TripStore
func addNewFeature(_ item: NewType) {
    items.append(item)
}

func deleteNewFeature(at offsets: IndexSet) {
    let sorted = items.sorted { $0.date > $1.date }
    let idsToRemove = offsets.map { sorted[$0].id }
    items.removeAll { idsToRemove.contains($0.id) }
}

// Computed property for derived state
var totalNewFeature: Int {
    items.count
}
```

**Adding View:**
```swift
struct NewFeatureView: View {
    let store: TripStore

    var body: some View {
        NavigationStack {
            VStack {
                // Content
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TITLE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(AppTheme.toriiRed)
                }
            }
        }
    }
}
```

**Color Usage:**
Always reference AppTheme, never hardcode hex:
```swift
// Good
.foregroundStyle(AppTheme.toriiRed)

// Bad
.foregroundStyle(Color(hex: "DC2626"))
```

---

*Structure analysis: 2026-02-28*
