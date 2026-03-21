# Phase 8: Search Bar + Handle - Research

**Researched:** 2026-03-21
**Domain:** SwiftUI search bar styling, drag handle, sticky header, haptics, @FocusState
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Drag Handle**
- D-01: Handle top padding = 8pt (как реализовано в Phase 7, а не 10pt из REQUIREMENTS.md)
- D-02: Handle bottom padding = 6pt (без изменений)
- D-03: Handle размер: 36pt x 5pt, `Color(.systemFill)` (без изменений)
- D-04: Handle идентичен во ВСЕХ состояниях (peek, half, full) — никаких изменений стиля
- D-05: Handle без press feedback (нет dimming/highlight при тапе)
- D-06: Handle a11y: текущие labels (accessibilityLabel + accessibilityHint) — без изменений
- D-07: Handle hit area: текущий full-width Rectangle contentShape — без изменений
- D-08: Handle цвет: `Color(.systemFill)` — без изменений
- D-09: Handle ширина: 36pt fixed — без изменений
- D-10: Handle форма: `Capsule()` — без изменений
- D-11: Handle позиция: centered (текущая) — без изменений

**Search Bar — Размеры и типографика**
- D-12: Search bar padding: 4pt vertical в peek / 8pt vertical в expanded (без изменений)
- D-13: Search bar высота capsule: 36pt единая во всех состояниях
- D-14: Magnifyingglass иконка: 17pt `.regular` weight (CHANGE: было 15pt .medium)
- D-15: Search bar шрифт: 17pt (CHANGE: было 16pt)
- D-16: Inner padding (leading/trailing): 14pt (CHANGE: было 12pt)
- D-17: Spacing между иконкой и текстом: 6pt (CHANGE: было 8pt)
- D-18: Outer horizontal padding (search bar от краёв sheet): 16pt (без изменений)

**Search Bar — Фон и стиль**
- D-19: Peek: нет inner capsule background (pill IS the background)
- D-20: Expanded capsule bg: `.quaternary.opacity(0.5)` (без изменений)
- D-21: Expanded capsule stroke: 0.5pt `Color.white.opacity(0.1)` (NEW)
- D-22: Capsule corner radius: `RoundedRectangle(cornerRadius: 10)` (CHANGE: было Capsule())
- D-23: Bottom spacing (под search bar): 10pt (без изменений)

**Search Bar — Текст и placeholder**
- D-24: Placeholder текст: "Поиск" (CHANGE: было "Поиск мест...")
- D-25: Placeholder цвет: `Color.white.opacity(0.5)` (CHANGE: было .secondary)
- D-26: Peek текст: показывает query если есть, иначе placeholder
- D-27: Peek текст стиль: .primary для query, .secondary для placeholder (без изменений)
- D-28: Text cursor цвет: `AppTheme.sakuraPink` (акцентный)
- D-29: Автокапитализация: `.never`, автокоррекция: disabled (без изменений)
- D-30: Keyboard тип: `.default` (без изменений)
- D-31: Submit action: запускает поиск (onSubmit)

**Search Bar — Фокус и взаимодействие**
- D-32: Тап в peek: раскрывает sheet в half + автофокус TextField
- D-33: Haptic при тапе в peek: `.impact(.light)` (NEW)
- D-34: Переход peek→half: capsule bg fade in вместе с общим crossfade (0.15s easeInOut)
- D-35: Без анимации иконки при фокусе (статичная)

**Search Bar — Микрофон**
- D-36: Нет микрофона — только AI sparkles toggle (deferred: SRCH-07)

**Search Bar — Clear button**
- D-37: `xmark.circle.fill` справа, появляется когда query не пустой
- D-38: Clear button: 16pt, `Color.secondary`
- D-39: Clear button ЗАМЕНЯЕТ AI sparkles (показывается только один из двух)

**Search Bar — Sticky header (full mode)**
- D-40: В full mode drag handle + search bar sticky при скролле контента
- D-41: Тонкий `Divider()` снизу sticky area при скролле
- D-42: В half mode — без sticky (контент не скроллится достаточно)

**Search Bar — Офлайн**
- D-43: Без изменений в офлайн режиме (поиск работает по кэшированным данным)

**Cancel button**
- D-44: Показывается при фокусе ИЛИ query не пустой (текущее поведение)
- D-45: Текст: "Отмена"
- D-46: Шрифт: 17pt `.regular`
- D-47: Цвет: `AppTheme.sakuraPink`
- D-48: Анимация: `.transition(.move(edge: .trailing).combined(with: .opacity))`
- D-49: Действие: очистить query + убрать фокус + sheet остаётся в half (не сворачивается в peek)

**AI Sparkles toggle**
- D-50: Позиция: trailing в search bar (как сейчас)
- D-51: Видимость: только когда query пустой (clear button заменяет при наличии текста — D-39)
- D-52: Размер иконки: 17pt (в тон magnifyingglass)
- D-53: Цвет active: `AppTheme.sakuraPink`
- D-54: Цвет inactive: `Color.secondary`
- D-55: Анимация: `.symbolEffect(.bounce)` при toggle
- D-56: В peek: скрыт (peek слишком компактный)
- D-57: Haptic: `.impact(.light)` при toggle

### Deferred Ideas (OUT OF SCOPE)
- Микрофон в search bar (SRCH-07) — отдельная фаза
- Аватар профиля в search bar (SRCH-06) — отдельная фаза
- `.webSearch` keyboard type — deferred
- Scale bounce анимация иконки при фокусе — overcomplicated
- Dimmed search bar в офлайн — deferred
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HNDL-01 | Drag handle capsule 36pt wide x 5pt tall, `Color(.systemFill)` | Already implemented in Phase 7 — verify dimensions match D-03 |
| HNDL-02 | Handle виден во ВСЕХ detent states (peek, half, full) — по центру над search bar | Already implemented in Phase 7 — no change needed per D-04 |
| HNDL-03 | Handle padding top 10pt, bottom 6pt | CONFLICT: D-01 sets top=8pt. Decision takes precedence over requirement. Confirm 8pt. |
| SRCH-01 | Magnifying glass icon + "Поиск на карте" placeholder + AI sparkles toggle | Requires icon size change (17pt .regular), placeholder text change ("Поиск"), AI sparkles visibility rules |
| SRCH-02 | В peek mode: нет внутреннего capsule background (pill сама является фоном) | Already partially implemented — need to verify no capsule background leaks through |
| SRCH-03 | В half/full mode: capsule background `.quaternary.opacity(0.5)` внутри sheet | Shape change Capsule() → RoundedRectangle(10) + add 0.5pt white stroke (D-21, D-22) |
| SRCH-04 | Тап на pill в peek → expand to full + focus text field | D-32 changes target detent from .full to .half. Decision overrides requirement. |
| SRCH-05 | "Отмена" кнопка справа от поиска в half/full mode | Font size change to 17pt, cancel does not snap to peek (D-49) |
</phase_requirements>

## Summary

Phase 8 is a precision refinement of `MapSearchContent.swift`. All architectural decisions are locked from CONTEXT.md. The work consists of targeted numeric/style changes to an already-functioning component. No new infrastructure is needed. The primary risk is the requirement vs. decision conflicts (HNDL-03 top padding 10pt vs D-01 8pt; SRCH-04 expand-to-full vs D-32 expand-to-half) — CONTEXT.md decisions take precedence.

The sticky header in full mode (D-40/D-41) is the most structurally novel change: it requires wrapping the sheet content in a `ScrollView` with a non-scrolling header area. The existing `MapSearchContent` uses a flat `VStack` — restructuring is needed only when `detent == .full`.

The AI sparkles toggle requires a behavior change: currently it is always visible; the new rule hides it in peek (D-56) and replaces it with clear-button when query is non-empty (D-39). This is logic only, no new components.

**Primary recommendation:** Edit `MapSearchContent.swift` only — do NOT touch `MapBottomSheet.swift` (Phase 7 output, geometry frozen). The handle is already correct. Apply numeric and style changes first, then add haptics, then restructure for sticky header.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All UI layout and animations | Platform SDK |
| UIKit (UIImpactFeedbackGenerator) | iOS 17+ | Haptic feedback via `.impact(.light)` | SwiftUI `.sensoryFeedback` not available pre-iOS 17; direct UIKit call is reliable |
| SF Symbols | 5.x | System icons (magnifyingglass, xmark.circle.fill, sparkles) | Apple platform standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI `.symbolEffect(.bounce)` | iOS 17+ | Sparkles icon animation on toggle | D-55 — bounce effect on AI toggle |
| `@FocusState` | iOS 15+ | TextField keyboard focus management | Already in use via `@FocusState.Binding` passed from TripMapView |
| `ScrollViewReader` | iOS 14+ | Scroll detection for sticky divider | Needed if implementing scroll-offset-aware divider (D-41) |

**Installation:** No new packages. All APIs are platform SDK.

## Architecture Patterns

### Recommended Project Structure

No new files needed. All changes are in:
```
Travel app/Views/Map/
├── MapSearchContent.swift   — PRIMARY target (all search bar changes)
└── MapBottomSheet.swift     — DO NOT MODIFY (Phase 7 output, geometry frozen)
```

### Pattern 1: Conditional Search Bar Background (Peek vs Expanded)

**What:** In peek mode the pill shell is the visual container; inside the HStack there is no background. In expanded mode a `RoundedRectangle(cornerRadius: 10)` fill + stroke provides an inner field.

**When to use:** Conditioned on `vm.sheetDetent == .peek` (same logic as current, shape changes from `Capsule()` to `RoundedRectangle(cornerRadius: 10)`).

**Current code (MapSearchContent.swift lines 225-234):**
```swift
.background(
    Group {
        if vm.sheetDetent != .peek {
            Capsule()
                .fill(.quaternary.opacity(0.5))
        } else {
            Color.clear
        }
    }
)
```

**New code (D-22 + D-21 — shape + stroke):**
```swift
.background(
    Group {
        if vm.sheetDetent != .peek {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        } else {
            Color.clear
        }
    }
)
```

### Pattern 2: Clear Button / Sparkles Mutual Exclusion

**What:** Trailing area shows either clear button (when `!vm.searchQuery.isEmpty`) or sparkles toggle (when `vm.searchQuery.isEmpty && vm.sheetDetent != .peek`). Only one at a time.

**When to use:** Replaces current always-visible sparkles button.

```swift
// Trailing area in searchFieldContent HStack
if !vm.searchQuery.isEmpty {
    Button {
        vm.searchQuery = ""
    } label: {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16))
            .foregroundStyle(Color.secondary)
    }
} else if vm.sheetDetent != .peek {
    // AI sparkles toggle — hidden in peek (D-56)
    Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3)) {
            vm.isAISearchMode.toggle()
            // ... existing toggle cleanup ...
        }
    } label: {
        Image(systemName: "sparkles")
            .font(.system(size: 17))
            .foregroundStyle(vm.isAISearchMode ? AppTheme.sakuraPink : Color.secondary)
            .symbolEffect(.bounce, value: vm.isAISearchMode) // D-55
    }
}
```

### Pattern 3: Haptic on Peek Tap (D-33)

**What:** `UIImpactFeedbackGenerator(style: .light).impactOccurred()` called synchronously before the animation in the `.onTapGesture` handler.

**Current code (MapSearchContent.swift lines 178-185):**
```swift
.onTapGesture {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        vm.sheetDetent = .full
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        isSearchFocused = true
    }
}
```

**New code (D-32 changes .full → .half, D-33 adds haptic):**
```swift
.onTapGesture {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        vm.sheetDetent = .half
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        isSearchFocused = true
    }
}
```

### Pattern 4: Sticky Header in Full Mode (D-40 / D-41)

**What:** When `detent == .full`, the handle + search bar row must remain stationary while the content below (chips, results) scrolls. SwiftUI's native approach: separate the header from the scrollable body — the header lives outside the `ScrollView`, the body lives inside.

**Current structure (MapSearchContent.swift):** Flat `VStack(spacing: 0)` — handle is rendered in `MapBottomSheet`, content is all inside one vertical stack. Since `MapBottomSheet` renders the handle above `content()`, the handle is already sticky. The search bar row (the `HStack` with `searchFieldContent`) is the first child of `MapSearchContent.body`. Making it sticky means it must stay outside any `ScrollView`.

**Approach:** Conditional restructuring based on `detent`:
- `detent != .full`: current flat VStack (no scroll needed — half mode fits content without overflow)
- `detent == .full`: VStack with sticky header (search bar HStack) + `ScrollView` wrapping the rest

```swift
var body: some View {
    VStack(spacing: 0) {
        // Sticky search bar row — always outside ScrollView
        HStack(spacing: 10) {
            searchFieldContent.frame(maxWidth: .infinity)
            if isSearchFocused || !vm.searchQuery.isEmpty {
                cancelButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .animation(.spring(response: 0.3), value: isSearchFocused || !vm.searchQuery.isEmpty)

        // Divider — only in full mode when content is scrollable (D-41)
        // Use @State isScrolled to show/hide
        if detent == .full && isScrolled {
            Divider()
        }

        // Scrollable body (full mode) or flat body (half mode)
        if detent == .full {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    scrollableContent
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y > 0
            } action: { _, newValue in
                isScrolled = newValue
            }
        } else {
            scrollableContent
        }
    }
    .animation(.spring(response: 0.3), value: isSearchFocused)
}
```

Note: `onScrollGeometryChange` is iOS 18+. For iOS 17 fallback use a `GeometryReader` inside the ScrollView to track offset.

### Pattern 5: TextField Cursor Tint (D-28)

**What:** `.accentColor(AppTheme.sakuraPink)` applied to the TextField sets cursor and selection highlight color.

```swift
TextField("Поиск", text: $vm.searchQuery)
    .font(.system(size: 17))
    .autocorrectionDisabled()
    .autocapitalization(.none)
    .focused($isSearchFocused)
    .onSubmit { vm.submitSearch() }
    .accentColor(AppTheme.sakuraPink)
```

### Anti-Patterns to Avoid

- **Modifying MapBottomSheet.swift:** Handle dimensions are already correct (Phase 7). Any change to that file risks breaking sheet geometry. The handle capsule (36x5, .systemFill, top:8, bottom:6) is confirmed correct.
- **Using `.presentationDetents`:** Research from Phase 7 confirms this causes content-height bugs. Stay with custom implementation.
- **SwiftUI `.sensoryFeedback`:** Only iOS 17.0+. Prefer direct `UIImpactFeedbackGenerator` which is reliable back to iOS 13.
- **Wrapping entire content in ScrollView unconditionally:** Half mode doesn't need scroll; adding ScrollView in half causes layout constraints to collapse without explicit frame.
- **Using `Capsule()` for inner field background:** D-22 explicitly changes this to `RoundedRectangle(cornerRadius: 10)`. Do not revert.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Haptic triggers | Custom timer/debounce | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` | Direct, reliable, instant |
| Icon bounce animation | Manual scale/opacity keyframes | `.symbolEffect(.bounce, value:)` | SF Symbol native, respects Reduce Motion |
| Scroll offset detection | Preference key + GeometryReader | `onScrollGeometryChange` (iOS 18) or GeometryReader inside ScrollView | Platform-provided |
| Cancel button slide animation | Custom MatchedGeometryEffect | `.transition(.move(edge: .trailing).combined(with: .opacity))` | Already defined D-48 |

**Key insight:** All visual polish in this phase is achievable with existing SwiftUI modifiers — no custom animation infrastructure needed.

## Common Pitfalls

### Pitfall 1: Cancel Button Snaps Sheet to Peek
**What goes wrong:** Current `vm.dismissSearch()` in the cancel handler resets detent to `.peek`. D-49 says sheet stays at `.half`.
**Why it happens:** `vm.dismissSearch()` may have side-effects beyond clearing the query.
**How to avoid:** In the cancel action, set `vm.searchQuery = ""`, then `isSearchFocused = false`, then explicitly set `vm.sheetDetent = .half`. Do NOT call `vm.dismissSearch()` if it sets detent to peek.
**Warning signs:** Sheet visually collapses after tapping cancel.

### Pitfall 2: `detent` Not Available in `MapSearchContent`
**What goes wrong:** `MapSearchContent` currently reads `vm.sheetDetent` for peek/expanded branching. This works. But for the sticky header pattern, `detent` needs to be a parameter (or the VM binding continues to provide it).
**Why it happens:** The view already uses `vm.sheetDetent` — this is fine and consistent.
**How to avoid:** Continue using `vm.sheetDetent` (not a separate parameter binding) for peek/half/full branching. No interface change needed.

### Pitfall 3: `.symbolEffect(.bounce)` iOS Version
**What goes wrong:** `.symbolEffect` is iOS 17+. Deploying below iOS 17 will fail to compile.
**Why it happens:** SF Symbol effects were added in iOS 17.
**How to avoid:** Confirm deployment target. Memory notes say "Build target: iPhone 17 Pro Max simulator (iOS 26.2)" — iOS 17+ is guaranteed. Safe to use.

### Pitfall 4: `onScrollGeometryChange` iOS Version
**What goes wrong:** `onScrollGeometryChange` requires iOS 18+. If minimum deployment target is iOS 17, this crashes or fails to compile.
**Why it happens:** Scroll geometry observation API added in iOS 18.
**How to avoid:** Check project's minimum deployment target. If iOS 17 minimum, use GeometryReader-inside-ScrollView fallback for scroll offset detection. If iOS 18 minimum (likely given iOS 26.2 target), use `onScrollGeometryChange` directly.

### Pitfall 5: HStack Spacing Change Conflict
**What goes wrong:** The HStack in `searchFieldContent` currently uses `spacing: 8`. D-17 changes icon-to-text spacing to 6pt. But HStack spacing applies uniformly — if there are multiple items (icon, text, progressView, button), all gaps change.
**Why it happens:** `HStack(spacing:)` applies one gap between all adjacent children.
**How to avoid:** Set `HStack(spacing: 0)` and apply explicit `.padding(.leading, 6)` to the text/field element to get the 6pt icon-to-text gap. Trailing button can have its own `.padding(.leading, 4)` or use `Spacer()` to push it right.

### Pitfall 6: Placeholder Color in Dark Mode
**What goes wrong:** `Color.white.opacity(0.5)` as placeholder color is correct in dark mode (`.preferredColorScheme(.dark)` on parent) but would be invisible in light mode.
**Why it happens:** The pill is always in dark mode (inherited from map view's dark scheme). This is intentional and safe.
**How to avoid:** Confirm `.preferredColorScheme(.dark)` is still applied to parent (TripMapView). It is. No issue.

### Pitfall 7: AI Sparkles Toggle State After Clear
**What goes wrong:** When user has `isAISearchMode = true` and types text (query non-empty), sparkles are hidden (clear button shows). If user clears text, sparkles must reappear showing the active state (pink, not grey).
**Why it happens:** The toggle just shows/hides based on `vm.searchQuery.isEmpty` — the `vm.isAISearchMode` state is preserved.
**How to avoid:** The current logic is correct — `vm.isAISearchMode` persists independently of query content. Sparkles icon color is driven by `vm.isAISearchMode`, so it will show correctly in active state when query is cleared.

## Code Examples

### All Changes Checklist in `searchFieldContent`

```swift
// Source: CONTEXT.md decisions D-14 through D-22, D-25, D-28
private var searchFieldContent: some View {
    HStack(spacing: 0) {  // spacing 0, manual padding for D-17 (6pt icon-text gap)
        Image(systemName: "magnifyingglass")
            .font(.system(size: 17, weight: .regular))  // D-14: was 15pt .medium
            .foregroundStyle(.secondary)
            .padding(.leading, 14)  // D-16: was 12pt
            .padding(.trailing, 6)  // D-17: 6pt gap between icon and text

        // Peek: tappable Text / Expanded: TextField
        if vm.sheetDetent == .peek && !isSearchFocused {
            Text(vm.searchQuery.isEmpty ? "Поиск" : vm.searchQuery)  // D-24: was "Поиск на карте"
                .font(.system(size: 17))  // D-15: was 16pt
                .foregroundStyle(
                    vm.searchQuery.isEmpty
                        ? Color.white.opacity(0.5)  // D-25: was .secondary
                        : Color.primary
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-33
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        vm.sheetDetent = .half  // D-32: was .full
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isSearchFocused = true
                    }
                }
        } else {
            TextField("Поиск", text: $vm.searchQuery)  // D-24
                .font(.system(size: 17))  // D-15
                .autocorrectionDisabled()
                .autocapitalization(.none)  // D-29
                .focused($isSearchFocused)
                .onSubmit { vm.submitSearch() }
                .accentColor(AppTheme.sakuraPink)  // D-28: cursor color
                .frame(maxWidth: .infinity)
        }

        // Trailing: clear XOR sparkles (D-37/D-38/D-39/D-50..D-57)
        if !vm.searchQuery.isEmpty {
            Button {
                vm.searchQuery = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.trailing, 14)  // D-16
        } else if vm.sheetDetent != .peek {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-57
                withAnimation(.spring(response: 0.3)) {
                    vm.isAISearchMode.toggle()
                    vm.searchResults = []
                    vm.searchedItem = nil
                    vm.completerResults = []
                    if !vm.isAISearchMode { AIMapSearchService.shared.clear() }
                }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 17))  // D-52
                    .foregroundStyle(vm.isAISearchMode ? AppTheme.sakuraPink : Color.secondary)  // D-53/D-54
                    .symbolEffect(.bounce, value: vm.isAISearchMode)  // D-55
            }
            .padding(.trailing, 14)  // D-16
        }
    }
    .frame(height: 36)  // D-13: fixed capsule height
    .padding(.vertical, vm.sheetDetent == .peek ? 4 : 8)  // D-12
    .background(
        Group {
            if vm.sheetDetent != .peek {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            } else {
                Color.clear
            }
        }
    )
    // D-34: capsule bg fade with peek→expanded crossfade
    .animation(.easeInOut(duration: 0.15), value: vm.sheetDetent == .peek)
}
```

### Cancel Button (updated font size)

```swift
// Source: CONTEXT.md D-44..D-49
if isSearchFocused || !vm.searchQuery.isEmpty {
    Button("Отмена") {
        vm.searchQuery = ""
        isSearchFocused = false
        // D-49: do NOT collapse to peek — explicit half
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            vm.sheetDetent = .half
        }
    }
    .font(.system(size: 17, weight: .regular))  // D-46: was 16pt
    .foregroundStyle(AppTheme.sakuraPink)        // D-47
    .transition(.move(edge: .trailing).combined(with: .opacity))  // D-48
}
```

### Scroll-Aware Sticky Header (full mode, D-40/D-41)

```swift
// Source: CONTEXT.md D-40, D-41 + iOS 18 onScrollGeometryChange
@State private var isScrolled: Bool = false

var body: some View {
    VStack(spacing: 0) {
        // STICKY: search row always rendered here, outside any ScrollView
        searchRowAndCancel

        if detent == .full && isScrolled {
            Divider()  // D-41: thin divider on scroll
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: isScrolled)
        }

        if detent == .full {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) { sheetBodyContent }
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y > 2  // small threshold to avoid false triggers
            } action: { _, newScrolled in
                isScrolled = newScrolled
            }
        } else {
            sheetBodyContent
        }
    }
    .animation(.spring(response: 0.3), value: isSearchFocused)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Capsule()` as inner field | `RoundedRectangle(cornerRadius: 10)` | D-22 (Phase 8) | More Apple Maps-accurate field shape |
| `spacing: 8` between icon and text | `spacing: 0` + manual padding | D-17 (Phase 8) | Precise 6pt gap between icon and text |
| Always-visible sparkles toggle | Sparkles only when query empty and not peek | D-39, D-56 (Phase 8) | Prevents cluttered trailing area |
| Cancel action calls `vm.dismissSearch()` | Cancel explicitly sets `.half` detent | D-49 (Phase 8) | Sheet doesn't collapse on cancel |
| Expand-to-full on peek tap | Expand-to-half on peek tap | D-32 (Phase 8) | More gentle initial expansion |

## Open Questions

1. **`vm.dismissSearch()` implementation**
   - What we know: it clears query and possibly changes detent
   - What's unclear: exact implementation — does it set `sheetDetent = .peek`?
   - Recommendation: Planner must check `MapViewModel.dismissSearch()` implementation before using it in cancel action. If it collapses to peek, DO NOT call it — inline the cancel logic per D-49.

2. **Minimum deployment target**
   - What we know: project targets iOS 26.2 simulator
   - What's unclear: project's minimum deployment target setting in Xcode
   - Recommendation: If min target is iOS 18+, use `onScrollGeometryChange`. If iOS 17, use GeometryReader fallback. Check `IPHONEOS_DEPLOYMENT_TARGET` in project settings.

3. **`detent` property access in `MapSearchContent`**
   - What we know: the view uses `vm.sheetDetent` throughout
   - What's unclear: whether the sticky header restructuring should read `vm.sheetDetent` or a passed-in parameter
   - Recommendation: Continue using `vm.sheetDetent` — it's already the established pattern and avoids interface changes.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, `Travel appTests/`) |
| Config file | None (Xcode native test target) |
| Quick run command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:"Travel appTests/MapSearchContentTests"` |
| Full suite command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HNDL-01 | Handle 36x5pt, systemFill | Visual/manual | Physical device visual check | N/A |
| HNDL-02 | Handle visible all detents | Visual/manual | Physical device visual check | N/A |
| HNDL-03 | Handle top padding 8pt (D-01) | Unit | Verify constant in source | N/A |
| SRCH-01 | 17pt icon + "Поиск" placeholder + sparkles | Visual/manual | Physical device visual check | N/A |
| SRCH-02 | No inner bg in peek | Visual/manual | Physical device visual check | N/A |
| SRCH-03 | RoundedRect(10) bg + 0.5pt stroke in expanded | Visual/manual | Physical device visual check | N/A |
| SRCH-04 | Peek tap → half + focus | Unit | `MapViewModelTests` — test detent change | ❌ Wave 0 |
| SRCH-05 | Cancel shows in half/full, stays at half | Unit | `MapViewModelTests` — test cancel behavior | ❌ Wave 0 |

Most requirements in this phase are visual/proportional and require manual device verification. Unit tests cover the two behavioral requirements (SRCH-04, SRCH-05).

### Sampling Rate
- **Per task commit:** Build succeeds, no compiler warnings
- **Per wave merge:** Manual device walkthrough of all 3 detent states
- **Phase gate:** Side-by-side comparison with Apple Maps on physical device before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Travel appTests/MapViewModelTests.swift` — covers SRCH-04 (peek tap → half detent) and SRCH-05 (cancel stays at half)

## Sources

### Primary (HIGH confidence)
- Direct code inspection of `MapSearchContent.swift` and `MapBottomSheet.swift` — confirmed current implementation state
- `08-CONTEXT.md` — all decisions are locked user decisions, authoritative for this phase
- `07-CONTEXT.md` — Phase 7 geometry decisions (handle already implemented)
- SwiftUI platform documentation (`.symbolEffect`, `onScrollGeometryChange`, `.accentColor`, `UIImpactFeedbackGenerator`) — iOS 17/18 SDK

### Secondary (MEDIUM confidence)
- iOS deployment target inferred from "iPhone 17 Pro Max (iOS 26.2)" — project is iOS 17+ minimum, iOS 18+ features likely available

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure SwiftUI platform APIs, no third-party libraries
- Architecture: HIGH — changes are surgical edits to one file with locked decisions
- Pitfalls: HIGH — identified from direct code inspection and known SwiftUI behavior

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable SwiftUI APIs, locked decisions)
