import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    let trip: Trip

    @Query var offlineCaches: [OfflineMapCache]
    @State private var selectedPlace: Place?
    @State private var showRoutes = true
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showDiscoverNearby = false
    #if !targetEnvironment(simulator)
    @State private var arPlace: Place?
    #endif

    // Search
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var searchedItem: MKMapItem?
    @State private var showSearchBar = false

    private var allPlaces: [Place] {
        trip.allPlaces
    }

    private var daysWithRoutes: [TripDay] {
        trip.sortedDays.filter { !$0.routePoints.isEmpty }
    }

    private var cachedSnapshotsForTrip: [(day: TripDay, data: Data)] {
        let dayIDs = Set(trip.days.map(\.id))
        return offlineCaches
            .filter { dayIDs.contains($0.tripDayID) }
            .compactMap { cache in
                guard let day = trip.days.first(where: { $0.id == cache.tripDayID }) else { return nil }
                return (day: day, data: cache.snapshotData)
            }
            .sorted { $0.day.sortOrder < $1.day.sortOrder }
    }

    private var isOfflineWithCache: Bool {
        !OfflineCacheManager.shared.isOnline && !cachedSnapshotsForTrip.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if isOfflineWithCache {
                    offlineSnapshotGallery
                } else {
                Map(position: $cameraPosition, selection: $selectedPlace) {
                    ForEach(allPlaces) { place in
                        Annotation(
                            place.name,
                            coordinate: place.coordinate,
                            anchor: .bottom
                        ) {
                            placePin(place)
                        }
                        .tag(place)
                    }

                    if showRoutes {
                        ForEach(daysWithRoutes) { day in
                            let sortedPoints = day.routePoints.sorted { $0.timestamp < $1.timestamp }
                            let coords = sortedPoints.map(\.coordinate)
                            if coords.count >= 2 {
                                MapPolyline(coordinates: coords)
                                    .stroke(routeColor(for: day), lineWidth: 3)
                            }
                        }
                    }

                    UserAnnotation()

                    if let item = searchedItem,
                       let coord = item.placemark.location?.coordinate {
                        Annotation(
                            item.name ?? "",
                            coordinate: coord,
                            anchor: .bottom
                        ) {
                            searchResultPin
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant])))
                } // end else (online map)

                // Search overlay
                if showSearchBar {
                    mapSearchOverlay
                }

                VStack(spacing: 0) {
                    if !daysWithRoutes.isEmpty {
                        routeStatsBar
                    }

                    if let place = selectedPlace {
                        selectedPlaceCard(place)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: selectedPlace?.id)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("КАРТА")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showSearchBar.toggle()
                            if !showSearchBar {
                                dismissSearch()
                            }
                        }
                    } label: {
                        Image(systemName: showSearchBar ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(showSearchBar ? .secondary : AppTheme.oceanBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            zoomToAll()
                        } label: {
                            Label("Показать все", systemImage: "map")
                        }

                        Divider()

                        ForEach(uniqueCities, id: \.self) { city in
                            Button {
                                zoomToCity(city)
                            } label: {
                                Label(city, systemImage: "building.2")
                            }
                        }

                        if !daysWithRoutes.isEmpty {
                            Divider()
                            Button {
                                showRoutes.toggle()
                            } label: {
                                Label(
                                    showRoutes ? "Скрыть маршруты" : "Показать маршруты",
                                    systemImage: showRoutes ? "eye.slash" : "eye"
                                )
                            }
                        }

                        Divider()
                        Button {
                            showDiscoverNearby = true
                        } label: {
                            Label("Обзор", systemImage: "location.magnifyingglass")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            #if !targetEnvironment(simulator)
            .fullScreenCover(item: $arPlace) { place in
                ARNavigationView(place: place)
            }
            #endif
            .onAppear {
                LocationManager.shared.requestPermission()
            }
            .onChange(of: searchQuery) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await performMapSearch(query: trimmed)
                }
            }
            .sheet(isPresented: $showDiscoverNearby) {
                if let coord = allPlaces.first?.coordinate {
                    DiscoverNearbyView(coordinate: coord)
                }
            }
        }
    }

    // MARK: - Offline Snapshot Gallery

    private var offlineSnapshotGallery: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    ForEach(cachedSnapshotsForTrip, id: \.day.id) { item in
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            HStack(spacing: 6) {
                                Image(systemName: "map")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.sakuraPink)
                                Text(item.day.cityName.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("ДЕНЬ \(item.day.sortOrder + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(.tertiary)
                            }

                            if let uiImage = UIImage(data: item.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(AppTheme.spacingM)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 50)
                .padding(.bottom, AppTheme.spacingM)
            }

            Text("ОФЛАЙН")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.toriiRed.opacity(0.85))
                .clipShape(Capsule())
                .padding(.top, 8)
        }
    }

    private var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName))).sorted()
    }

    // MARK: - Route Stats Bar

    private var routeStatsBar: some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: "figure.walk")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.bambooGreen)

            Text("\(daysWithRoutes.count) " + routeDaysWord(daysWithRoutes.count))
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(.primary)

            Capsule()
                .fill(.tertiary)
                .frame(width: 1, height: 16)

            Text(formatDistance(totalRouteDistance))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.bambooGreen)

            Spacer()

            Text("\(totalRoutePoints) ТОЧЕК")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.bambooGreen.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingXS)
    }

    private var totalRoutePoints: Int {
        daysWithRoutes.reduce(0) { $0 + $1.routePoints.count }
    }

    private var totalRouteDistance: Double {
        daysWithRoutes.reduce(0.0) { total, day in
            total + calculateDistance(for: day)
        }
    }

    private func calculateDistance(for day: TripDay) -> Double {
        let sorted = day.routePoints.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 2 else { return 0 }
        var distance: Double = 0
        for i in 1..<sorted.count {
            let prev = CLLocation(latitude: sorted[i-1].latitude, longitude: sorted[i-1].longitude)
            let curr = CLLocation(latitude: sorted[i].latitude, longitude: sorted[i].longitude)
            distance += curr.distance(from: prev)
        }
        return distance
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f KM", meters / 1000)
        }
        return "\(Int(meters)) M"
    }

    private func routeDaysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return String(localized: "ТРЕКОВ") }
        if mod10 == 1 { return String(localized: "ТРЕК") }
        if mod10 >= 2 && mod10 <= 4 { return String(localized: "ТРЕКА") }
        return String(localized: "ТРЕКОВ")
    }

    private func routeColor(for day: TripDay) -> Color {
        let dayColors: [Color] = [
            AppTheme.sakuraPink,
            AppTheme.oceanBlue,
            AppTheme.bambooGreen,
            AppTheme.templeGold,
            AppTheme.toriiRed,
        ]
        guard let index = trip.sortedDays.firstIndex(where: { $0.id == day.id }) else {
            return AppTheme.sakuraPink
        }
        return dayColors[index % dayColors.count]
    }

    // MARK: - Search Overlay

    private var mapSearchOverlay: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppTheme.spacingS) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                    TextField("Поиск на карте...", text: $searchQuery)
                        .font(.system(size: 14))
                        .autocorrectionDisabled()
                        .onSubmit { submitSearch() }
                    if isSearching {
                        ProgressView().scaleEffect(0.6)
                    }
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
                )

                if !searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.prefix(5).enumerated()), id: \.offset) { _, item in
                            Button {
                                selectSearchResult(item)
                            } label: {
                                mapSearchResultRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }

                if let item = searchedItem {
                    searchedItemCard(item)
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)

            Spacer()
        }
    }

    private func mapSearchResultRow(_ item: MKMapItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.oceanBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = formatSearchAddress(item) {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.oceanBlue.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func searchedItemCard(_ item: MKMapItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.oceanBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle = formatSearchAddress(item) {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                searchedItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(AppTheme.spacingS)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var searchResultPin: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.oceanBlue)
                .background(
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                )
                .shadow(color: AppTheme.oceanBlue.opacity(0.4), radius: 4, y: 2)

            Circle()
                .fill(AppTheme.oceanBlue)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Search Logic

    private func submitSearch() {
        searchTask?.cancel()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        searchTask = Task {
            await performMapSearch(query: trimmed)
        }
    }

    private func performMapSearch(query: String) async {
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        // Scope to trip area for better results
        if let first = allPlaces.first {
            request.region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }

        isSearching = false
    }

    private func selectSearchResult(_ item: MKMapItem) {
        searchedItem = item
        searchResults = []
        searchQuery = ""

        if let coord = item.placemark.location?.coordinate {
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }

    private func dismissSearch() {
        searchQuery = ""
        searchResults = []
        searchedItem = nil
    }

    private func formatSearchAddress(_ item: MKMapItem) -> String? {
        let pm = item.placemark
        var parts: [String] = []
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let locality = pm.locality { parts.append(locality) }
        if let admin = pm.administrativeArea, !parts.contains(admin) { parts.append(admin) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Pin

    private func placePin(_ place: Place) -> some View {
        let pinColor = place.isVisited
            ? AppTheme.bambooGreen
            : AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(spacing: 2) {
            Image(systemName: place.category.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(pinColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .stroke(.white, lineWidth: 2)
                )
                .shadow(color: pinColor.opacity(0.4), radius: 4, y: 2)

            Circle()
                .fill(pinColor)
                .frame(width: 6, height: 6)
        }
        .onTapGesture {
            selectedPlace = place
        }
    }

    // MARK: - Selected Place Card

    private func selectedPlaceCard(_ place: Place) -> some View {
        let categoryColor = AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(place.nameLocal)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    selectedPlace = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
            }

            HStack(spacing: AppTheme.spacingS) {
                CategoryBadge(category: place.category)

                if place.isVisited {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("ПОСЕЩЕНО")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(AppTheme.bambooGreen)
                    .background(AppTheme.bambooGreen.opacity(0.1))
                    .clipShape(Capsule())
                }

                if let rating = place.rating {
                    StarRatingView(rating: rating)
                }
            }

            if !place.address.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(place.address)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }

            #if !targetEnvironment(simulator)
            Button {
                arPlace = place
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arkit")
                        .font(.system(size: 12, weight: .bold))
                    Text("AR НАВИГАЦИЯ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.indigoPurple)
                .clipShape(Capsule())
            }
            #endif

            if !place.notes.isEmpty {
                Text(place.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(
                    place.isVisited ? AppTheme.bambooGreen.opacity(0.3) : categoryColor.opacity(0.2),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    // MARK: - Camera Helpers

    private func zoomToAll() {
        let lats = allPlaces.map(\.latitude)
        let lons = allPlaces.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.5, 0.05)
        let spanLon = max((maxLon - minLon) * 1.5, 0.05)
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                )
            )
        }
    }

    private func zoomToCity(_ city: String) {
        let cityPlaces = trip.days
            .filter { $0.cityName == city }
            .flatMap(\.places)

        guard let first = cityPlaces.first else { return }

        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: first.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
    }
}

#if DEBUG
#Preview {
    TripMapView(trip: .preview)
        .modelContainer(.preview)
}
#endif
