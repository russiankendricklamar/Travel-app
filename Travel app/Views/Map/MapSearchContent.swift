import SwiftUI
import MapKit

/// Содержимое bottom sheet: поисковая строка + результаты
struct MapSearchContent: View {
    @Bindable var vm: MapViewModel
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search pill
            searchBar
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

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
    }

    // MARK: - Search Bar (Apple Maps style)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.isAISearchMode ? "sparkles" : "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(vm.isAISearchMode ? AppTheme.sakuraPink : .secondary)

            TextField(
                vm.isAISearchMode ? "Спросите ИИ..." : "Поиск на карте",
                text: $vm.searchQuery
            )
            .font(.system(size: 16))
            .autocorrectionDisabled()
            .focused($isSearchFocused)
            .onSubmit { vm.submitSearch() }

            if vm.isSearching || AIMapSearchService.shared.isLoading {
                ProgressView().scaleEffect(0.65)
            }

            if !vm.searchQuery.isEmpty {
                Button {
                    vm.dismissDetail()
                    withAnimation(.spring(response: 0.3)) { vm.sheetDetent = .peek }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }

            // AI toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    vm.isAISearchMode.toggle()
                    vm.searchResults = []
                    vm.searchedItem = nil
                    if !vm.isAISearchMode {
                        AIMapSearchService.shared.clear()
                        vm.selectedAIResult = nil
                    }
                }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(vm.isAISearchMode ? .white : AppTheme.sakuraPink)
                    .frame(width: 30, height: 30)
                    .background(vm.isAISearchMode ? AppTheme.sakuraPink : .clear)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
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
