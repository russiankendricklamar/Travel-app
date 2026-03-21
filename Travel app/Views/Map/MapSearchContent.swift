import SwiftUI
import MapKit

// PreferenceKey to track scroll offset from within a ScrollView (iOS 17 compatible)
private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Содержимое bottom sheet: поисковая строка + результаты
struct MapSearchContent: View {
    @Bindable var vm: MapViewModel
    @FocusState.Binding var isSearchFocused: Bool

    @State private var isScrolled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // STICKY: search bar + cancel — always outside ScrollView
            HStack(spacing: 10) {
                searchFieldContent
                    .frame(maxWidth: .infinity)

                // "Отмена" — shown when search is active, hidden in peek
                if vm.sheetDetent != .peek && (isSearchFocused || !vm.searchQuery.isEmpty) {
                    Button("Отмена") {
                        vm.searchQuery = ""
                        isSearchFocused = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.sheetDetent = .peek
                        }
                    }
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, vm.sheetDetent == .peek ? 0 : 16)
            .padding(.bottom, vm.sheetDetent == .peek ? 0 : 10)
            .animation(MapViewModel.sheetSpring, value: isSearchFocused || !vm.searchQuery.isEmpty)

            // Divider — only in full mode when scrolled (D-41)
            if vm.sheetDetent == .full && isScrolled {
                Divider()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: isScrolled)
            }

            // Scrollable in full mode, flat in half/peek
            if vm.sheetDetent == .full {
                ScrollView(.vertical, showsIndicators: false) {
                    // Invisible geometry reader anchored to .named("scrollView") reports offset
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("scrollView")).origin.y
                        )
                    }
                    .frame(height: 0)

                    scrollableContent
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    isScrolled = offset > 2
                }
            } else {
                scrollableContent
            }
        }
        .animation(MapViewModel.sheetSpring, value: isSearchFocused)
        .onChange(of: vm.sheetDetent) { _, newDetent in
            if newDetent != .full {
                isScrolled = false
            }
        }
    }

    // Idle content is visible when: no completer active, no search query typed,
    // no search results loaded, and sheet is in idle state (not showing category/text results).
    // Removing isSearchFocused gate achieves Apple Maps parity (CONT-01 through CONT-03).
    private var showIdleContent: Bool {
        vm.sheetDetent != .peek
            && vm.completerResults.isEmpty
            && vm.searchQuery.isEmpty
            && vm.searchResults.isEmpty
            && vm.sheetContent == .idle
    }

    @ViewBuilder
    private var scrollableContent: some View {
        // Typeahead completer suggestions — shown while typing, hidden in peek
        if vm.sheetDetent != .peek && vm.isCompleterActive && !vm.completerResults.isEmpty {
            Divider().padding(.horizontal, 14)
            completerSuggestionsList
        }

        // Idle content: category chips, today's places, map controls.
        // Visible immediately in half/full mode — no search focus required (CONT-01 to CONT-03).
        Group {
            if showIdleContent {
                categoryChips
                    .padding(.bottom, 8)
                    .transition(.opacity)

                todayPlacesSection
                    .transition(.opacity)

                mapControlsSection
                    .transition(.opacity)

                // Full-mode only: recent searches placeholder (D-03)
                if vm.sheetDetent == .full {
                    recentSearchesSection
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showIdleContent)

        if vm.sheetContent == .searchResults, !vm.searchResults.isEmpty {
            Divider().padding(.horizontal, 14)
            searchResultsList
        }

        if vm.sheetContent == .aiSearchResults || (vm.isAISearchMode && !AIMapSearchService.shared.results.isEmpty) {
            Divider().padding(.horizontal, 14)
            aiSearchResultsList
        }

        if vm.isAISearchMode {
            aiMessages
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapViewModel.quickCategories, id: \.name) { cat in
                    Button {
                        Task { await vm.performCategorySearch(query: cat.query, category: cat.name) }
                    } label: {
                        HStack(spacing: 5) {
                            if vm.isLoadingCategory && vm.selectedCategory == cat.name {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text(cat.name)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(vm.selectedCategory == cat.name
                                      ? Color(.label)
                                      : Color(.label).opacity(0.12))
                        )
                        .foregroundStyle(vm.selectedCategory == cat.name ? Color(.systemBackground) : Color(.label).opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Completer Suggestions (instant typeahead)

    private var completerSuggestionsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.completerResults.enumerated()), id: \.offset) { index, completion in
                    Button {
                        Task { await vm.selectCompleterResult(completion) }
                        isSearchFocused = false
                    } label: {
                        completerRow(completion)
                    }
                    .buttonStyle(.plain)

                    if index < vm.completerResults.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func completerRow(_ completion: MKLocalSearchCompletion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Search Field Content (Apple Maps style)
    // Note: the outer Cancel button lives in `body` alongside this view.

    private var searchFieldContent: some View {
        HStack(spacing: vm.sheetDetent == .peek ? 6 : 0) {
            // Leading icon — always magnifyingglass
            Image(systemName: "magnifyingglass")
                .font(.system(size: vm.sheetDetent == .peek ? 15 : 17, weight: .regular))
                .foregroundStyle(vm.sheetDetent == .peek ? Color.white.opacity(0.85) : .secondary)
                .padding(.leading, vm.sheetDetent == .peek ? 0 : 14)
                .padding(.trailing, vm.sheetDetent == .peek ? 0 : 6)

            // In peek: show tappable placeholder that expands sheet
            // In half/full: show real TextField
            if vm.sheetDetent == .peek && !isSearchFocused {
                Text("Поиск")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.sheetDetent = .half
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isSearchFocused = true
                        }
                    }
            } else {
                TextField(
                    vm.isAISearchMode ? "Спросите ИИ..." : "Поиск",  // D-24
                    text: $vm.searchQuery
                )
                .font(.system(size: 17))  // D-15
                .autocorrectionDisabled()
                .autocapitalization(.none)  // D-29
                .accentColor(AppTheme.sakuraPink)  // D-28: cursor color
                .focused($isSearchFocused)
                .onSubmit { vm.submitSearch() }
            }

            // Hide progress/clear/sparkle in peek — only icon + "Поиск" visible
            if vm.sheetDetent != .peek {
                if vm.isSearching || AIMapSearchService.shared.isLoading {
                    ProgressView().scaleEffect(0.65)
                }
            }

            // Clear button — shown when query is not empty and not peek
            if !vm.searchQuery.isEmpty && vm.sheetDetent != .peek {
                Button {
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.trailing, 14)
            }
            // AI sparkles — shown when query empty AND not peek
            else if vm.sheetDetent != .peek {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-57
                    withAnimation(MapViewModel.sheetSpring) {
                        vm.isAISearchMode.toggle()
                        vm.searchResults = []
                        vm.searchedItem = nil
                        vm.completerResults = []
                        if !vm.isAISearchMode {
                            AIMapSearchService.shared.clear()
                            vm.selectedAIResult = nil
                        }
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17))  // D-52
                        .foregroundStyle(vm.isAISearchMode ? AppTheme.sakuraPink : Color.secondary)  // D-53/D-54
                        .symbolEffect(.bounce, value: vm.isAISearchMode)  // D-55
                }
                .padding(.trailing, 14)
            }
        }
        .padding(.vertical, vm.sheetDetent == .peek ? 12 : 8)
        // In peek mode the sheet itself IS the dark bar — no inner capsule background needed (D-19)
        .background(
            Group {
                if vm.sheetDetent != .peek {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)  // D-22
                        .fill(.quaternary.opacity(0.5))  // D-20
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)  // D-21
                        )
                } else {
                    Color.clear
                }
            }
        )
        .animation(.easeInOut(duration: 0.15), value: vm.sheetDetent == .peek)  // D-34
    }

    // MARK: - MK Search Results

    private var searchResultsList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.searchResults.enumerated()), id: \.offset) { index, item in
                    Button {
                        vm.selectSearchResult(item)
                        isSearchFocused = false
                    } label: {
                        searchResultRow(item)
                    }
                    .buttonStyle(.plain)

                    if index < vm.searchResults.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func searchResultRow(_ item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.indigoPurple)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = vm.formatSearchAddress(item) {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - AI Search Results

    private var aiSearchResultsList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(Array(AIMapSearchService.shared.results.enumerated()), id: \.element.id) { index, rec in
                    Button {
                        vm.selectAIResult(rec)
                        isSearchFocused = false
                    } label: {
                        aiResultRow(rec)
                    }
                    .buttonStyle(.plain)

                    if index < AIMapSearchService.shared.results.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func aiResultRow(_ rec: PlaceRecommendation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rec.categoryIcon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink, AppTheme.indigoPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(rec.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Today's Places Section

    @ViewBuilder
    private var todayPlacesSection: some View {
        if let today = vm.trip.todayDay, !today.sortedPlaces.isEmpty {
            VStack(spacing: 0) {
                // Section header
                HStack(spacing: 6) {
                    Text("Сегодня")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(today.cityName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(today.visitedCount)/\(today.sortedPlaces.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                Divider().padding(.horizontal, 14)

                let allPlaces = today.sortedPlaces
                let isHalf = vm.sheetDetent == .half
                let displayedPlaces = isHalf && allPlaces.count > 3
                    ? Array(allPlaces.prefix(3))
                    : allPlaces

                ForEach(Array(displayedPlaces.enumerated()), id: \.element.id) { index, place in
                    Button {
                        vm.selectedPlaceID = place.id
                        isSearchFocused = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.sheetDetent = .peek
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Category icon in circle
                            Image(systemName: place.category.systemImage)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(.quaternary)
                                .clipShape(Circle())

                            Text(place.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            // Visited indicator
                            Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(place.isVisited ? AnyShapeStyle(AppTheme.bambooGreen) : AnyShapeStyle(.tertiary))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if index < displayedPlaces.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }

                // "Show all" overflow button — half mode with >3 places
                if isHalf && allPlaces.count > 3 {
                    Divider().padding(.leading, 52)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            vm.sheetDetent = .full
                        }
                    } label: {
                        Text("Показать все (\(allPlaces.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.sakuraPink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Map Controls Section

    private var mapControlsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Карта")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Layers menu button
                    Menu {
                        Section("Слои") {
                            Toggle(isOn: $vm.showPlaces) {
                                Label("Места", systemImage: "mappin.and.ellipse")
                            }
                            if vm.trip.isActive {
                                Toggle(isOn: $vm.showAllCities) {
                                    Label("Все города", systemImage: "globe")
                                }
                            }
                            Toggle(isOn: $vm.showRoutes) {
                                Label("GPS-треки", systemImage: "figure.walk")
                            }
                            if !vm.trainRoutes.isEmpty {
                                Toggle(isOn: $vm.showTrainRoutes) {
                                    Label("Поезда", systemImage: "tram.fill")
                                }
                            }
                            if !vm.flightArcs.isEmpty {
                                Toggle(isOn: $vm.showFlightArcs) {
                                    Label("Перелёты", systemImage: "airplane")
                                }
                            }
                        }
                        Section("Навигация") {
                            Button {
                                vm.zoomToAll()
                            } label: {
                                Label("Показать все", systemImage: "map")
                            }
                            ForEach(vm.uniqueCities, id: \.self) { city in
                                Button {
                                    vm.zoomToCity(city)
                                } label: {
                                    Label(city, systemImage: "building.2")
                                }
                            }
                        }
                    } label: {
                        mapControlButton(icon: "line.3.horizontal.decrease.circle", label: "Слои", tint: nil)
                    }

                    // Precipitation toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.showPrecipitation.toggle()
                        }
                    } label: {
                        mapControlButton(
                            icon: "cloud.rain",
                            label: "Осадки",
                            tint: vm.showPrecipitation ? AppTheme.oceanBlue : nil
                        )
                    }
                    .buttonStyle(.plain)

                    // Discover nearby
                    Button {
                        vm.showDiscoverNearby = true
                    } label: {
                        mapControlButton(icon: "location.magnifyingglass", label: "Обзор", tint: nil)
                    }
                    .buttonStyle(.plain)

                    // Zoom to all
                    Button {
                        vm.zoomToAll()
                    } label: {
                        mapControlButton(icon: "map", label: "Все места", tint: nil)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private func mapControlButton(icon: String, label: String, tint: Color?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint ?? Color(.label).opacity(0.7))
                .frame(width: 36, height: 36)
                .background(.quaternary.opacity(0.5))
                .clipShape(Circle())

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(tint ?? .secondary)
        }
    }

    // MARK: - Recent Searches (Full Mode)

    @ViewBuilder
    private var recentSearchesSection: some View {
        // Renders nothing until recent search history is implemented (CONT-06 deferred)
        EmptyView()
    }

    // MARK: - AI Messages

    @ViewBuilder
    private var aiMessages: some View {
        let service = AIMapSearchService.shared

        if let clarification = service.clarificationMessage {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.oceanBlue)
                Text(clarification)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }

        if let error = service.lastError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.templeGold)
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}
