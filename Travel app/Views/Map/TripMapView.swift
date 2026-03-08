import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    let trip: Trip

    @Query var offlineCaches: [OfflineMapCache]
    @State private var selectedPlaceID: Place.ID?
    @State private var showRoutes = true
    @State private var showPlaces = true
    @State private var showTrainRoutes = true
    @State private var showFlightArcs = true
    @State private var showFilterPanel = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasSetInitialCamera = false
    @State private var visibleRegion: MKCoordinateRegion?
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

    // AI Search
    @State private var isAISearchMode = false
    @State private var selectedAIResult: PlaceRecommendation?
    @State private var showDayPickerForAI: PlaceRecommendation?

    // Apple Maps info
    @State private var appleMapsInfo: AppleMapsPlaceInfo?
    @State private var isLoadingInfo = false
    @State private var showAppleMapsDetail = false

    // Routing
    @State private var activeRoute: RouteResult?
    @State private var selectedTransportMode: TransportMode = .walking
    @State private var routeFromCurrentLocation = true
    @State private var routeOriginPlaceID: Place.ID?
    @State private var isCalculatingRoute = false
    @State private var routeError: String?
    @State private var isNotesExpanded = false

    // Precipitation overlay
    @State private var showPrecipitation = false
    @State private var isLoadingRadar = false
    @State private var flightArcs: [FlightArc] = []
    @State private var trainRoutes: [TrainRoute] = []

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

    private var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return allPlaces.first { $0.id == id }
    }

    private var routeOriginPlace: Place? {
        guard let id = routeOriginPlaceID else { return nil }
        return allPlaces.first { $0.id == id }
    }

    private var isOfflineWithCache: Bool {
        !OfflineCacheManager.shared.isOnline && !cachedSnapshotsForTrip.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if isOfflineWithCache {
                    offlineSnapshotGallery
                } else if showPrecipitation {
                    RadarOverlayView(
                        places: allPlaces,
                        initialCenter: allPlaces.first?.coordinate,
                        isLoading: $isLoadingRadar
                    )
                    .ignoresSafeArea(edges: .all)
                } else {
                Map(position: $cameraPosition, selection: $selectedPlaceID) {
                    if showPlaces {
                        ForEach(allPlaces) { place in
                            Annotation(
                                place.name,
                                coordinate: place.coordinate,
                                anchor: .bottom
                            ) {
                                placePin(place)
                            }
                            .tag(place.id)
                        }
                    }

                    if showRoutes {
                        ForEach(daysWithRoutes) { day in
                            let sortedPoints = day.routePoints.sorted { $0.timestamp < $1.timestamp }
                            let coords = sortedPoints.map(\.coordinate)
                            if coords.count >= 2 {
                                MapPolyline(coordinates: coords)
                                    .stroke(routeColor(for: day), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            }
                        }
                    }

                    if showTrainRoutes {
                        ForEach(trainRoutes) { train in
                            MapPolyline(coordinates: train.polyline)
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            Annotation("", coordinate: train.midpoint, anchor: .center) {
                                Image(systemName: "tram.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.4), radius: 3)
                            }
                        }
                    }

                    // Calculated direction route (always visible when active)
                    if let route = activeRoute {
                        MapPolyline(coordinates: route.polyline)
                            .stroke(route.mode.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }

                    if showFlightArcs {
                        ForEach(flightArcs) { arc in
                            MapPolyline(coordinates: arc.points)
                                .stroke(.white.opacity(0.85), lineWidth: 2)
                        }
                        ForEach(flightArcs) { arc in
                            Annotation("", coordinate: arc.midpoint, anchor: .center) {
                                Image(systemName: "airplane")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(arc.bearing - 45))
                                    .shadow(color: .black.opacity(0.5), radius: 3)
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

                    ForEach(AIMapSearchService.shared.results) { rec in
                        if rec.latitude != 0, rec.longitude != 0 {
                            Annotation(
                                rec.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: rec.latitude,
                                    longitude: rec.longitude
                                ),
                                anchor: .bottom
                            ) {
                                aiResultPin(rec)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant])))
                .onMapCameraChange { context in
                    visibleRegion = context.region
                }
                } // end else (online map)

                // Search overlay
                if showSearchBar {
                    mapSearchOverlay
                }

                VStack(spacing: 0) {
                    if !daysWithRoutes.isEmpty && activeRoute == nil {
                        routeStatsBar
                    }

                    if let route = activeRoute {
                        routeInfoCard(route)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if let rec = selectedAIResult {
                        aiResultCard(rec)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: selectedAIResult?.id)
                    } else if let place = selectedPlace {
                        selectedPlaceCard(place)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: selectedPlaceID)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if showPrecipitation {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.rain.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.oceanBlue)
                            Text("ОСАДКИ")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(4)
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                    } else {
                        Text("КАРТА")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
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
                        // Layers section
                        Section("Слои") {
                            Toggle(isOn: $showPlaces) {
                                Label("Места", systemImage: "mappin.and.ellipse")
                            }
                            Toggle(isOn: $showRoutes) {
                                Label("GPS-треки", systemImage: "figure.walk")
                            }
                            if !trainRoutes.isEmpty {
                                Toggle(isOn: $showTrainRoutes) {
                                    Label("Поезда", systemImage: "tram.fill")
                                }
                            }
                            if !flightArcs.isEmpty {
                                Toggle(isOn: $showFlightArcs) {
                                    Label("Перелёты", systemImage: "airplane")
                                }
                            }
                        }

                        Section {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showPrecipitation.toggle()
                                }
                            } label: {
                                Label(
                                    showPrecipitation ? "Скрыть осадки" : "Карта осадков",
                                    systemImage: showPrecipitation ? "cloud.rain.fill" : "cloud.rain"
                                )
                            }

                            Button {
                                showDiscoverNearby = true
                            } label: {
                                Label("Обзор", systemImage: "location.magnifyingglass")
                            }
                        }

                        Section("Навигация") {
                            Button {
                                zoomToAll()
                            } label: {
                                Label("Показать все", systemImage: "map")
                            }

                            ForEach(uniqueCities, id: \.self) { city in
                                Button {
                                    zoomToCity(city)
                                } label: {
                                    Label(city, systemImage: "building.2")
                                }
                            }
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
                setInitialCamera()
            }
            .task {
                if !hasSetInitialCamera {
                    await geocodeCountryCamera()
                }
                await loadFlightArcs()
                await loadTrainRoutes()
            }
            .task(id: selectedPlaceID) {
                appleMapsInfo = nil
                activeRoute = nil
                guard let place = selectedPlace else { return }
                isLoadingInfo = true
                appleMapsInfo = await AppleMapsInfoService.shared.fetchInfo(
                    name: place.name,
                    coordinate: place.coordinate
                )
                isLoadingInfo = false
            }
            .onChange(of: searchQuery) { _, newValue in
                guard !isAISearchMode else { return }
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
            .sheet(item: $showDayPickerForAI) { rec in
                DayPickerSheet(trip: trip, recommendation: rec)
            }
            .sheet(isPresented: $showAppleMapsDetail) {
                if #available(iOS 18.0, *), let mapItem = appleMapsInfo?.mapItem {
                    MapItemDetailView(mapItem: mapItem)
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
        // High-contrast colors that stand out on map tiles
        let dayColors: [Color] = [
            AppTheme.sakuraPink,
            .red,
            .brown,
            .green,
            .orange,
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
                    Image(systemName: isAISearchMode ? "sparkles" : "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(isAISearchMode ? AnyShapeStyle(AppTheme.sakuraPink) : AnyShapeStyle(.tertiary))
                    TextField(
                        isAISearchMode ? "Спросите ИИ..." : "Поиск на карте...",
                        text: $searchQuery
                    )
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .onSubmit { submitSearch() }

                    if isSearching || AIMapSearchService.shared.isLoading {
                        ProgressView().scaleEffect(0.6)
                    }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                            if isAISearchMode {
                                AIMapSearchService.shared.clear()
                                selectedAIResult = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isAISearchMode.toggle()
                            searchResults = []
                            searchedItem = nil
                            if !isAISearchMode {
                                AIMapSearchService.shared.clear()
                                selectedAIResult = nil
                            }
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isAISearchMode ? .white : AppTheme.sakuraPink)
                            .frame(width: 30, height: 30)
                            .background(isAISearchMode ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(
                            isAISearchMode ? AppTheme.sakuraPink.opacity(0.4) : AppTheme.oceanBlue.opacity(0.2),
                            lineWidth: isAISearchMode ? 1 : 0.5
                        )
                )

                if isAISearchMode {
                    aiSearchResultsList
                } else {
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

        if isAISearchMode {
            let city = trip.sortedDays.first?.cityName ?? ""
            let coord = visibleRegion?.center ?? allPlaces.first?.coordinate
            searchTask = Task {
                await AIMapSearchService.shared.search(
                    query: trimmed,
                    city: city,
                    nearCoordinate: coord,
                    mapRegion: visibleRegion
                )
                if let first = AIMapSearchService.shared.results.first,
                   first.latitude != 0, first.longitude != 0 {
                    zoomToAIResults()
                }
            }
        } else {
            searchTask = Task {
                await performMapSearch(query: trimmed)
            }
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
        isAISearchMode = false
        selectedAIResult = nil
        AIMapSearchService.shared.clear()
    }

    private func formatSearchAddress(_ item: MKMapItem) -> String? {
        let pm = item.placemark
        var parts: [String] = []
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let locality = pm.locality { parts.append(locality) }
        if let admin = pm.administrativeArea, !parts.contains(admin) { parts.append(admin) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - AI Search Results List

    private var aiSearchResultsList: some View {
        let service = AIMapSearchService.shared
        return Group {
            if let clarification = service.clarificationMessage {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.oceanBlue)
                    Text(clarification)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }

            if let error = service.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.templeGold)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }

            if !service.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(service.results) { rec in
                        Button {
                            selectAIResult(rec)
                        } label: {
                            aiSearchResultRow(rec)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
        }
    }

    private func aiSearchResultRow(_ rec: PlaceRecommendation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rec.categoryIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.sakuraPink)
                .frame(width: 28, height: 28)
                .background(AppTheme.sakuraPink.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(rec.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - AI Result Card

    private func aiResultCard(_ rec: PlaceRecommendation) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(rec.category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    selectedAIResult = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
            }

            Text(rec.description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !rec.address.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(rec.address)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                }
                .foregroundStyle(.secondary)
            }

            if !rec.estimatedTime.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .bold))
                    Text(rec.estimatedTime)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            }

            Button {
                showDayPickerForAI = rec
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("ДОБАВИТЬ В МАРШРУТ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.sakuraPink)
                .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    // MARK: - AI Result Pin

    private func aiResultPin(_ rec: PlaceRecommendation) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink, AppTheme.indigoPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .stroke(.white, lineWidth: 2)
                )
                .shadow(color: AppTheme.sakuraPink.opacity(0.4), radius: 4, y: 2)

            Circle()
                .fill(AppTheme.sakuraPink)
                .frame(width: 6, height: 6)
        }
        .onTapGesture {
            selectedAIResult = rec
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: rec.latitude, longitude: rec.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }

    // MARK: - AI Search Helpers

    private func selectAIResult(_ rec: PlaceRecommendation) {
        selectedAIResult = rec
        if rec.latitude != 0, rec.longitude != 0 {
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: rec.latitude, longitude: rec.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }

    private func zoomToAIResults() {
        let results = AIMapSearchService.shared.results.filter { $0.latitude != 0 && $0.longitude != 0 }
        guard !results.isEmpty else { return }

        let lats = results.map(\.latitude)
        let lons = results.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.5, 0.02)
        let spanLon = max((maxLon - minLon) * 1.5, 0.02)

        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                )
            )
        }
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
            selectedPlaceID = place.id
        }
    }

    // MARK: - Selected Place Card

    private func selectedPlaceCard(_ place: Place) -> some View {
        let categoryColor = AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            // Header: name + localName + close
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
                    selectedPlaceID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
            }

            // Category + visited + rating
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

            // Address — local + English
            if isLoadingInfo {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Загрузка...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } else if let info = appleMapsInfo {
                if let localAddr = info.localAddress {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(localAddr)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.secondary)
                }
                if let engAddr = info.englishAddress, engAddr != info.localAddress {
                    Text(engAddr)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 15)
                }
            } else if !place.address.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(place.address)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }

            // Phone
            if let phone = appleMapsInfo?.phoneNumber, !phone.isEmpty {
                let cleaned = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                if let telURL = URL(string: "tel:\(cleaned)") {
                    Link(destination: telURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(phone)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.oceanBlue)
                    }
                }
            }

            // Website
            if let url = appleMapsInfo?.website {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 11, weight: .bold))
                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(AppTheme.oceanBlue)
                }
            }

            // "ПОДРОБНЕЕ" — Apple Maps detail card
            if appleMapsInfo?.mapItem != nil {
                Button {
                    showAppleMapsDetail = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("ПОДРОБНЕЕ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.oceanBlue)
                    .clipShape(Capsule())
                }
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            // Route error
            if let error = routeError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppTheme.toriiRed)
            }

            // Origin + Route + AR buttons row
            HStack(spacing: AppTheme.spacingS) {
                // Origin picker
                Menu {
                    Button {
                        routeFromCurrentLocation = true
                    } label: {
                        Label("От меня", systemImage: "location.fill")
                    }
                    if let day = place.day {
                        ForEach(day.sortedPlaces.filter { $0.id != place.id }) { p in
                            Button {
                                routeFromCurrentLocation = false
                                routeOriginPlaceID = p.id
                            } label: {
                                Label(p.name, systemImage: p.category.systemImage)
                            }
                        }
                    }
                } label: {
                    Image(systemName: routeFromCurrentLocation ? "location.fill" : "mappin")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.sakuraPink.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                }

                Button {
                    Task { await calculateDirectionRoute(to: place) }
                } label: {
                    HStack(spacing: 6) {
                        if isCalculatingRoute {
                            ProgressView().scaleEffect(0.7).tint(.white)
                        } else {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text("МАРШРУТ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.oceanBlue)
                    .clipShape(Capsule())
                }
                .disabled(isCalculatingRoute)

                #if !targetEnvironment(simulator)
                Button {
                    arPlace = place
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arkit")
                            .font(.system(size: 12, weight: .bold))
                        Text("AR")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.indigoPurple)
                    .clipShape(Capsule())
                }
                #endif
            }

            // Collapsible notes
            if !place.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isNotesExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11, weight: .bold))
                            Text("ЗАМЕТКИ")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                            Spacer()
                            Image(systemName: isNotesExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.tertiary)
                    }
                    if isNotesExpanded {
                        Text(place.notes)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
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

    // MARK: - Route Info Card

    private func routeInfoCard(_ route: RouteResult) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            // Transport mode switcher
            HStack(spacing: 6) {
                ForEach(TransportMode.allCases) { mode in
                    Button {
                        selectedTransportMode = mode
                        guard let place = selectedPlace else { return }
                        if mode == .cycling {
                            // Cycling opens Apple Maps
                            Task { await calculateDirectionRoute(to: place) }
                        } else {
                            Task { await calculateDirectionRoute(to: place) }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 13, weight: .bold))
                            Text(mode.label)
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundStyle(route.mode == mode ? .white : mode.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(route.mode == mode ? mode.color : mode.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    }
                }
            }

            // Route info row
            HStack(spacing: AppTheme.spacingS) {
                if isCalculatingRoute {
                    ProgressView().scaleEffect(0.7)
                    Text("Расчёт...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: route.mode.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(route.mode.color)

                    Text(RoutingService.formatDuration(route.expectedTravelTime))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(route.mode.color)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(RoutingService.formatDistance(route.distance))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        activeRoute = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(AppTheme.spacingS)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(route.mode.color.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingXS)
    }

    // MARK: - Route Calculation

    private func calculateDirectionRoute(to place: Place) async {
        isCalculatingRoute = true
        routeError = nil
        let destination = place.coordinate

        // Determine origin
        let origin: CLLocationCoordinate2D
        if routeFromCurrentLocation {
            guard let loc = await LocationManager.shared.requestCurrentLocation() else {
                routeError = "Не удалось определить геопозицию"
                isCalculatingRoute = false
                return
            }
            origin = loc
        } else if let originPlace = routeOriginPlace {
            origin = originPlace.coordinate
        } else {
            routeError = "Выберите начальную точку"
            isCalculatingRoute = false
            return
        }

        // Cycling: open Apple Maps
        if selectedTransportMode == .cycling {
            RoutingService.openCyclingInAppleMaps(
                from: origin,
                to: destination,
                destinationName: place.name
            )
            isCalculatingRoute = false
            return
        }

        let result = await RoutingService.shared.calculateRoute(
            from: origin,
            to: destination,
            mode: selectedTransportMode
        )

        if result == nil {
            routeError = "Маршрут не найден"
        }

        withAnimation(.spring(response: 0.3)) {
            activeRoute = result
        }

        // Zoom to show route
        if let route = result {
            let lats = route.polyline.map(\.latitude)
            let lons = route.polyline.map(\.longitude)
            if let minLat = lats.min(), let maxLat = lats.max(),
               let minLon = lons.min(), let maxLon = lons.max() {
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: (minLat + maxLat) / 2,
                                longitude: (minLon + maxLon) / 2
                            ),
                            span: MKCoordinateSpan(
                                latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                                longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
                            )
                        )
                    )
                }
            }
        }

        isCalculatingRoute = false
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

    // MARK: - Initial Camera

    /// Synchronously set camera from existing place coordinates (no geocoding needed)
    private func setInitialCamera() {
        let coords = allPlaces.map(\.coordinate)
        guard !coords.isEmpty else { return }

        let minLat = coords.map(\.latitude).min()!
        let maxLat = coords.map(\.latitude).max()!
        let minLon = coords.map(\.longitude).min()!
        let maxLon = coords.map(\.longitude).max()!

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.4, 0.02)
        let spanLon = max((maxLon - minLon) * 1.4, 0.02)

        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
        )
        hasSetInitialCamera = true
    }

    /// Async fallback: geocode trip countries when no places exist yet
    private func geocodeCountryCamera() async {
        let countryNames = trip.countries
        guard !countryNames.isEmpty else { return }

        var allCoords: [CLLocationCoordinate2D] = []
        let geocoder = CLGeocoder()

        for name in countryNames {
            if let placemarks = try? await geocoder.geocodeAddressString(name),
               let location = placemarks.first?.location {
                allCoords.append(location.coordinate)
            }
        }

        guard !allCoords.isEmpty else { return }

        if allCoords.count == 1 {
            // Single country — use a reasonable zoom
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: allCoords[0],
                        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
                    )
                )
            }
        } else {
            // Multiple countries — fit bounding box
            let minLat = allCoords.map(\.latitude).min()!
            let maxLat = allCoords.map(\.latitude).max()!
            let minLon = allCoords.map(\.longitude).min()!
            let maxLon = allCoords.map(\.longitude).max()!
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let spanLat = max((maxLat - minLat) * 1.5, 4)
            let spanLon = max((maxLon - minLon) * 1.5, 4)

            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                        span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                    )
                )
            }
        }
        hasSetInitialCamera = true
    }

    // MARK: - Flight Arcs

    private func loadFlightArcs() async {
        guard !trip.flights.isEmpty, AirLabsService.shared.hasApiKey else { return }

        var arcs: [FlightArc] = []

        for flight in trip.flights {
            guard let data = await AirLabsService.shared.fetchFlight(number: flight.number, date: flight.date),
                  let depCoord = FlightData.coordinate(forIata: data.departureIata),
                  let arrCoord = FlightData.coordinate(forIata: data.arrivalIata) else { continue }

            let points = flightArcPoints(from: depCoord, to: arrCoord)
            let midIdx = points.count / 2
            let midpoint = points[midIdx]
            // Tangent at midpoint — wider window for stable direction
            let before = points[max(midIdx - 5, 0)]
            let after = points[min(midIdx + 5, points.count - 1)]
            let bearing = screenBearing(from: before, to: after)

            arcs.append(FlightArc(
                points: points,
                depCoord: depCoord,
                arrCoord: arrCoord,
                midpoint: midpoint,
                bearing: bearing,
                flightNumber: data.flightIata
            ))
        }

        flightArcs = arcs
    }

    private func flightArcPoints(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        segments: Int = 60
    ) -> [CLLocationCoordinate2D] {
        let dLat = end.latitude - start.latitude
        let dLon = end.longitude - start.longitude
        let dist = sqrt(dLat * dLat + dLon * dLon)
        guard dist > 0 else { return [start, end] }

        let midLat = (start.latitude + end.latitude) / 2
        let midLon = (start.longitude + end.longitude) / 2

        // Perpendicular offset for curved control point
        let perpLat = -dLon / dist
        let perpLon = dLat / dist

        // Always bulge toward positive latitude (northward)
        let sign: Double = perpLat >= 0 ? 1 : -1
        let height = dist * 0.15

        let ctrlLat = midLat + sign * perpLat * height
        let ctrlLon = midLon + sign * perpLon * height

        // Quadratic Bezier curve
        return (0...segments).map { i in
            let t = Double(i) / Double(segments)
            let lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * ctrlLat + t * t * end.latitude
            let lon = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * ctrlLon + t * t * end.longitude
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// Visual bearing on a Mercator-projected map (matches what the user sees on screen)
    private func screenBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLat = to.latitude - from.latitude
        let dLon = to.longitude - from.longitude
        let midLatRad = ((from.latitude + to.latitude) / 2) * .pi / 180
        // Scale longitude by cos(lat) to match Mercator visual proportions
        let visualDLon = dLon * cos(midLatRad)
        return atan2(visualDLon, dLat) * 180 / .pi
    }

    // MARK: - Train Routes

    private func loadTrainRoutes() async {
        let trainEvents = trip.days.flatMap(\.events).filter { $0.category == .train }
        guard !trainEvents.isEmpty else { return }

        var routes: [TrainRoute] = []

        for event in trainEvents {
            guard let start = event.primaryCoordinate,
                  let end = event.arrivalCoordinate else { continue }

            // Use MKDirections with .transit to follow real rail/transit tracks
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            request.transportType = .transit

            if let response = try? await MKDirections(request: request).calculate(),
               let mkRoute = response.routes.first {
                var coords = [CLLocationCoordinate2D](
                    repeating: CLLocationCoordinate2D(),
                    count: mkRoute.polyline.pointCount
                )
                mkRoute.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: mkRoute.polyline.pointCount))

                let midIdx = coords.count / 2
                routes.append(TrainRoute(
                    polyline: coords,
                    midpoint: coords[midIdx],
                    title: event.title,
                    distance: mkRoute.distance,
                    duration: mkRoute.expectedTravelTime
                ))
            } else {
                // Fallback: straight line if transit directions unavailable
                routes.append(TrainRoute(
                    polyline: [start, end],
                    midpoint: CLLocationCoordinate2D(
                        latitude: (start.latitude + end.latitude) / 2,
                        longitude: (start.longitude + end.longitude) / 2
                    ),
                    title: event.title,
                    distance: nil,
                    duration: nil
                ))
            }
        }

        trainRoutes = routes
    }
}

// MARK: - Flight Arc Data

private struct FlightArc: Identifiable {
    let id = UUID()
    let points: [CLLocationCoordinate2D]
    let depCoord: CLLocationCoordinate2D
    let arrCoord: CLLocationCoordinate2D
    let midpoint: CLLocationCoordinate2D
    let bearing: Double
    let flightNumber: String
}

// MARK: - Train Route Data

private struct TrainRoute: Identifiable {
    let id = UUID()
    let polyline: [CLLocationCoordinate2D]
    let midpoint: CLLocationCoordinate2D
    let title: String
    let distance: CLLocationDistance?
    let duration: TimeInterval?
}

#if DEBUG
#Preview {
    TripMapView(trip: .preview)
        .modelContainer(.preview)
}
#endif
