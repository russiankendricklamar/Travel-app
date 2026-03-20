# Coding Conventions

**Analysis Date:** 2026-03-20

## Naming Patterns

**Files:**
- View files: PascalCase ending in `View` (e.g., `DashboardView.swift`, `TripsListView.swift`)
- Service files: PascalCase ending in `Service` (e.g., `CurrencyService.swift`, `AuthManager.swift`)
- Manager files: PascalCase ending in `Manager` (e.g., `AuthManager.swift`, `OfflineCacheManager.swift`)
- Model files: Grouped logically (e.g., `TripModels.swift` contains Trip, TripDay, TripEvent, Place, Expense)
- Test files: `[TargetName]Tests.swift` (e.g., `KeychainHelperTests.swift`, `CurrencyServiceTests.swift`)
- Helper/Component files: PascalCase (e.g., `KeychainHelper.swift`, `GlassComponents.swift`)

**Functions and Methods:**
- camelCase with descriptive verbs (e.g., `fetchRates()`, `convertWithRate()`, `handleScenePhase()`)
- Boolean returns/properties use `is`, `has`, `can` prefix (e.g., `isActive`, `hasProfile`, `canEvaluatePolicy()`)
- Private utility functions prefixed with underscore or marked `private` (e.g., `private var fallbackRates`)
- Computed properties use nouns without prefix (e.g., `totalDays`, `currentDay`, `selectedTrip`)

**Variables and Properties:**
- camelCase for local variables and properties (e.g., `selectedTripID`, `showSideMenu`, `modelContext`)
- Boolean properties use `is`, `has`, `can` prefix (e.g., `isSignedIn`, `isBiometricEnabled`, `hasApiKey`)
- Constants in services use `static let` (e.g., `CurrencyService.supportedCurrencies`, `KeychainHelper.service`)
- AppStorage keys use camelCase (e.g., `@AppStorage("colorPalette")`, `@AppStorage("appLanguage")`)

**Types:**
- Enums: PascalCase (e.g., `Tab`, `TripPhase`, `EventCategory`, `PlaceCategory`, `ExpenseCategory`)
- Structs: PascalCase (e.g., `TripFlight`, `PlaceInfo`, `ScannedBooking`, `BudgetSource`)
- Classes: PascalCase with semantic suffix (e.g., `AuthManager`, `CurrencyService`, `Trip` @Model)
- Protocol names: PascalCase, often with `able` suffix (e.g., `Syncable`)

## Code Style

**Formatting:**
- Xcode native formatter (no explicit linting config detected)
- 4-space indentation (standard Swift)
- Spacing: consistent 2-4px padding/spacing constants via `AppTheme.spacingM` etc.

**Linting:**
- No .eslintrc, swiftlint.yml, or similar detected
- Type safety enforced by Swift compiler
- No explicit linter configuration

**Mark Comments:**
- Used for section organization: `// MARK: - Section Name`
- Examples: `// MARK: - Trip Flight`, `// MARK: - Flights (multi-flight support)`, `// MARK: - Conversion`
- Nested marks for subsections: `// MARK: - State`, `// MARK: - Init`, `// MARK: - Scene Phase`

## Import Organization

**Order:**
1. Foundation imports (`import Foundation`, `import CoreLocation`, etc.)
2. Apple frameworks (`import SwiftUI`, `import SwiftData`, `import UserNotifications`)
3. Third-party frameworks (`import Supabase`, `import AuthenticationServices`)
4. Conditional imports (`@testable import Travel_app` in tests only)

**Examples:**
```swift
// Services pattern
import Foundation
import SwiftData

// Views pattern
import SwiftUI
import MapKit
import CoreLocation

// Tests pattern
import XCTest
@testable import Travel_app
```

**Path Aliases:**
- No explicit path aliases detected
- Relative imports from same module (e.g., Views import Models directly)
- All code within single module: `Travel_app`

## Error Handling

**Patterns:**
- `try?` for optional results: `try? context.save()`, `try? await fetchRates()`
- `try!` only for deterministic code: `ModelContainer(..., configurations: config)` in preview setup
- `guard let` with nil coalescing in services: `errorMessage ?? "Неожиданный формат ответа"`
- Explicit `catch` blocks with error description:
  ```swift
  do {
    let data = try await SupabaseProxy.request(...)
    // process
  } catch {
    lastError = "Ошибка загрузки курсов"
    if lastFetchDate == nil { rates = fallbackRates }
  }
  ```
- Fallback values for API failures: `fallbackRates` in CurrencyService, `fallbackMatrix`
- Error types conform to `LocalizedError` protocol with `errorDescription` computed property
  ```swift
  enum SomeError: LocalizedError {
    var errorDescription: String? { "User-friendly message" }
  }
  ```
- Print statements for logging errors (not production logging framework):
  ```swift
  print("[ServiceName] Error: \(error)")
  ```

## Logging

**Framework:** No dedicated logging framework; uses `print()` for debug output

**Patterns:**
- Prefixed logs: `print("[ServiceName] Operation: result")`
- Error logs: `print("[CurrencyService] Fetch error: \(error)")`
- Operation logs: `print("[GeminiService] 📤 Request: \"\(promptPreview)...\" (\(prompt.count) chars)")`
- Emoji prefixes for clarity: 📤 (outgoing), ❌ (error), 📜 (info)
- No console.log statements in production code (hooks catch stray prints)

## Comments

**When to Comment:**
- Section markers: `// MARK: - [Section Name]`
- Algorithm explanation: When logic is non-obvious (e.g., timezone handling in Trip)
- API/Protocol conformance notes: `// MARK: - Syncable` before protocol methods
- Intentional workarounds: `// Corporate mode disabled` (inline explanation of commented code)
- Complex computed properties rarely commented (self-documenting names used)

**JSDoc/TSDoc:**
- Swift documentation comments not consistently used
- Nil docstrings; code clarity via naming preferred
- No formal documentation generation detected

## Function Design

**Size:**
- Typical: 10-30 lines for service methods
- Large: Up to 50 lines for UI layout methods
- Computed properties: Often 5-15 lines, some reach 50+ (e.g., `flights` computed property in Trip)
- No strict line limit enforced; readability prioritized

**Parameters:**
- Labelled parameters for clarity: `convert(_ amount: Double, from: String, to: String)`
- Default parameters in init methods: `isVisited: Bool = false`, `rating: Int? = nil`
- Single unnamed parameter for value operands: `convert(_ amount:...)`, `format(_ amount:...)`
- @ViewBuilder for closures in components: `GlassFormField` uses `@ViewBuilder let content`

**Return Values:**
- Computed properties for derived data: `totalDays`, `currentDay`, `remainingBudget`
- Optional returns for fallible operations: `PlaceInfo?`, `Double?` for rates
- Tuple returns for grouped results: `[(category: ExpenseCategory, total: Double)]` for expenses by category
- Void methods for mutations (rare; immutability patterns preferred)

## Module Design

**Exports:**
- All public types in shared modules (Services, Models)
- View components: public by default (no explicit private until needed)
- Singleton pattern for services: `static let shared` (e.g., CurrencyService.shared, AuthManager.shared)
- Observable services: `@Observable` macro on shared instances

**Barrel Files:**
- No barrel file pattern observed
- Models grouped by domain: `TripModels.swift` (Trip + TripDay + TripEvent + Place + Expense + enums)
- Related components in single file: `GlassComponents.swift` (GlassTextFieldStyle + GlassFormField + GlassSectionHeader)

## SwiftUI State Management

**@State Pattern:**
- Local view state only: `@State private var showSideMenu = false`
- Used for UI interactions: tab selection, sheet visibility, form values
- Private access (not exposed to parent)

**@Binding Pattern:**
- Sheet/modal presentation parameters: `@Binding var isPresented`
- Form field bindings: `TextField("...", text: $formValue)`

**@Observable Pattern:**
- Service singletons: `@Observable final class CurrencyService`, `@Observable final class AuthManager`
- @MainActor enforced on UI-touching services: `@MainActor @Observable final class GeminiService`
- Accessed via `let service = ServiceName.shared` in views

**@Query Pattern:**
- SwiftData queries in views: `@Query var trips: [Trip]`
- No parameters in simple queries; filtering done via computed properties
- Environment injection: `@Environment(\.modelContext) private var modelContext`

**@AppStorage Pattern:**
- User preferences: palette, language, currency, biometric settings
- Key names: camelCase strings (e.g., "colorPalette", "appLanguage", "preferredCurrency")
- Initialization with default values: `@AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue`

## Data Model Patterns

**@Model (SwiftData):**
- Marked with `@Model final class` for SwiftData persistence
- UUID primary keys: `@Attribute(.unique) var id: UUID`
- Relationship declarations: `@Relationship(deleteRule: .cascade, inverse: \RelatedModel.field)`
- Soft deletes: `var isDeleted: Bool = false` (used for sync, not actual deletion)
- Timestamp tracking: `var updatedAt: Date = Date()`

**Codable/Syncable:**
- Models conform to `Syncable` protocol for cloud sync
- JSON serialization for complex fields: flights stored as `flightsJSON: String`, decoded to `[TripFlight]`
- Fallback parsing: guard let with nil-coalescing in computed properties

**Enums:**
- Conform to `Codable` for API serialization
- Conform to `CaseIterable` for iteration (ExpenseCategory.allCases)
- Conform to `Identifiable` for SwiftUI lists: `var id: String { rawValue }`
- String-based rawValue for localized labels: `case flight = "Перелёт"`

## String Localization

**Pattern:**
- `String(localized: "Russian text")` for all user-facing strings
- Russian UI language primary
- Localization keys are inline strings (not separate .strings files detected)
- Fallback language: English (not fully localized but supported via appLanguage setting)

**Usage:**
```swift
Text(String(localized: "СЕЙЧАС"))
case .active: return String(localized: "В путешествии")
```

**Scope:**
- Button labels, error messages, enum display names
- Section headers and titles
- Not used for technical logs or debug strings

## Type Safety & Optionals

**Optional Handling:**
- Guard-let extraction for required values: `guard let day = try? context.fetch(descriptor).first`
- Nil-coalescing for defaults: `placeName ?? "Unknown"`
- Optional chaining: `day?.resolvedTimeZone`
- Forced unwrap (!) only in guaranteed-safe contexts: preview setup, unit tests

**Computed Property Guards:**
- Early return with nil: `guard !timezoneIdentifier.isEmpty else { return nil }`
- Multiple optional checks: `guard let lat = latitude, let lon = longitude else { return nil }`

## File Organization

**Typical Service File Structure:**
```
1. Imports
2. @MainActor/@Observable declarations
3. Class/struct definition with static properties
4. Stored properties grouped by MARK
5. Initialization (init, private init)
6. Public methods grouped by MARK
7. Private helper methods
```

**Typical View File Structure:**
```
1. Imports
2. struct ViewName: View declarations
3. @State/@Binding properties
4. Environment properties
5. Computed properties (filtered data, derived state)
6. var body: some View { }
7. Private subviews as separate structs or @ViewBuilder methods
```

**Test File Structure:**
```
1. Imports (XCTest, @testable)
2. final class TestNameTests: XCTestCase
3. Setup properties (testKey, etc.)
4. tearDown() method
5. Test methods (func testXxx())
6. Helper methods (private func makeTrip(), etc.)
```

---

*Convention analysis: 2026-03-20*
