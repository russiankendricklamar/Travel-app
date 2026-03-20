import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    let trip: Trip

    @Query var offlineCaches: [OfflineMapCache]
    @State private var vm: MapViewModel
    @FocusState private var isSearchFocused: Bool

    init(trip: Trip) {
        self.trip = trip
        self._vm = State(initialValue: MapViewModel(trip: trip))
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

    /// Idle mode: поисковая таблетка над tab bar, sheet скрыт
    private var isIdleMode: Bool {
        vm.sheetDetent == .peek && vm.sheetContent == .idle
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Map Layer
                if isOfflineWithCache {
                    MapOfflineGallery(snapshots: cachedSnapshotsForTrip)
                } else if vm.showPrecipitation {
                    RadarOverlayView(
                        places: vm.allPlaces,
                        initialCenter: vm.allPlaces.first?.coordinate,
                        isLoading: $vm.isLoadingRadar
                    )
                    .ignoresSafeArea(edges: .all)
                } else {
                    mapContent
                }

                // MARK: - Search Pill (idle, above tab bar)
                if !isOfflineWithCache && isIdleMode {
                    VStack(spacing: 0) {
                        Spacer()
                        MapFloatingSearchPill(vm: vm) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                vm.sheetDetent = .half
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFocused = true
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // MARK: - Bottom Sheet (active content: search, detail, route)
                if !isOfflineWithCache && !isIdleMode {
                    MapBottomSheet(detent: $vm.sheetDetent) {
                        sheetBody
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isIdleMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            // Hide tab bar when sheet is active (solid fill to bottom)
            .toolbar(isIdleMode ? .visible : .hidden, for: .tabBar)
            #if !targetEnvironment(simulator)
            .fullScreenCover(item: $vm.arPlace) { place in
                ARNavigationView(place: place)
            }
            #endif
            .sheet(isPresented: $vm.showDiscoverNearby) {
                if let coord = vm.allPlaces.first?.coordinate {
                    DiscoverNearbyView(coordinate: coord)
                }
            }
            .sheet(item: $vm.showDayPickerForAI) { rec in
                DayPickerSheet(trip: trip, recommendation: rec)
            }
            .sheet(isPresented: $vm.showAppleMapsDetail) {
                if #available(iOS 18.0, *), let mapItem = vm.appleMapsInfo?.mapItem {
                    MapItemDetailView(mapItem: mapItem)
                }
            }
            .onAppear {
                LocationManager.shared.requestPermission()
                vm.setInitialCamera()
            }
            .task {
                if trip.isActive, !vm.hasSetInitialCamera {
                    if let loc = await LocationManager.shared.requestCurrentLocation() {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            vm.cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: loc,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                )
                            )
                        }
                        vm.hasSetInitialCamera = true
                    }
                }
                if !vm.hasSetInitialCamera {
                    await vm.geocodeCountryCamera()
                }
                await vm.loadTransportOverlays()
            }
            .task(id: vm.selectedPlaceID) {
                vm.onPlaceSelected()
                guard let place = vm.selectedPlace else { return }
                vm.isLoadingInfo = true
                vm.isLoadingGoogleDetail = true
                async let appleInfo = AppleMapsInfoService.shared.fetchInfo(
                    name: place.name,
                    coordinate: place.coordinate
                )
                async let googleInfo = PlaceDetailService.shared.fetchDetails(
                    name: place.name,
                    coordinate: place.coordinate
                )
                vm.appleMapsInfo = await appleInfo
                vm.isLoadingInfo = false
                vm.googleDetail = await googleInfo
                vm.isLoadingGoogleDetail = false
            }
            .onChange(of: vm.sheetDetent) { oldDetent, newDetent in
                // Swipe down to peek → full reset (clear pins, search, selections)
                if newDetent == .peek && oldDetent != .peek {
                    vm.dismissDetail()
                }
            }
            .onChange(of: vm.searchQuery) { _, newValue in
                guard !vm.isAISearchMode else { return }
                vm.searchTask?.cancel()
                vm.searchedItem = nil
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    vm.searchResults = []
                    return
                }
                vm.searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await vm.performMapSearch(query: trimmed)
                }
            }
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        Map(position: $vm.cameraPosition, selection: $vm.selectedPlaceID) {
            // Place pins
            if vm.showPlaces {
                ForEach(vm.visiblePlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        PlacePinView(place: place, isSelected: place.id == vm.selectedPlaceID)
                            .onTapGesture { vm.selectedPlaceID = place.id }
                    }
                    .tag(place.id)
                }
            }

            // GPS route tracks
            if vm.showRoutes {
                ForEach(vm.daysWithRoutes) { day in
                    let coords = day.routePoints.sorted { $0.timestamp < $1.timestamp }.map(\.coordinate)
                    if coords.count >= 2 {
                        MapPolyline(coordinates: coords)
                            .stroke(vm.routeColor(for: day), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }
            }

            // Train routes
            if vm.showTrainRoutes {
                ForEach(vm.trainRoutes) { train in
                    if train.isRealTrack {
                        // Real MLIT track geometry — thicker with rail-style rendering
                        MapPolyline(coordinates: train.polyline)
                            .stroke(train.routeColor.opacity(0.3), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        MapPolyline(coordinates: train.polyline)
                            .stroke(train.routeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: train.isShinkansen ? [] : [8, 4]))
                    } else {
                        MapPolyline(coordinates: train.polyline)
                            .stroke(train.routeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    Annotation("", coordinate: train.midpoint, anchor: .center) {
                        Image(systemName: train.isShinkansen ? "train.side.front.car" : "tram.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(train.routeColor)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.4), radius: 3)
                    }
                }
            }

            // Active route
            if let route = vm.activeRoute {
                MapPolyline(coordinates: route.polyline)
                    .stroke(route.mode.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }

            // Flight arcs
            if vm.showFlightArcs {
                ForEach(vm.flightArcs) { arc in
                    MapPolyline(coordinates: arc.points)
                        .stroke(.white.opacity(0.85), lineWidth: 2)
                }
                ForEach(vm.flightArcs) { arc in
                    Annotation("", coordinate: arc.midpoint, anchor: .center) {
                        Image(systemName: "airplane")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(arc.bearing - 45))
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    }
                }
                ForEach(vm.flightAirportAnnotations) { ap in
                    Annotation("", coordinate: ap.coordinate, anchor: .center) {
                        AirportPinView(iata: ap.iata)
                    }
                }
            }

            UserAnnotation()

            // Search result pins
            ForEach(Array(vm.searchResults.enumerated()), id: \.offset) { _, item in
                if let coord = item.placemark.location?.coordinate {
                    Annotation(item.name ?? "", coordinate: coord, anchor: .bottom) {
                        SearchResultPinView(isSelected: item == vm.searchedItem)
                    }
                }
            }

            // Single selected search item
            if vm.searchResults.isEmpty,
               let item = vm.searchedItem,
               let coord = item.placemark.location?.coordinate {
                Annotation(item.name ?? "", coordinate: coord, anchor: .bottom) {
                    SearchResultPinView(isSelected: true)
                }
            }

            // AI search result pins
            ForEach(AIMapSearchService.shared.results) { rec in
                if rec.latitude != 0, rec.longitude != 0 {
                    Annotation(
                        rec.name,
                        coordinate: CLLocationCoordinate2D(latitude: rec.latitude, longitude: rec.longitude),
                        anchor: .bottom
                    ) {
                        AIResultPinView()
                            .onTapGesture { vm.selectAIResult(rec) }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant])))
        .mapControls {
            MapScaleView()
        }
        .safeAreaPadding(.bottom, isIdleMode ? 48 : 0)
        .onMapCameraChange { context in
            vm.visibleRegion = context.region
        }
    }

    // MARK: - Sheet Body

    @ViewBuilder
    private var sheetBody: some View {
        switch vm.sheetContent {
        case .idle, .searchResults, .aiSearchResults:
            MapSearchContent(vm: vm, isSearchFocused: $isSearchFocused)
        case .placeDetail, .searchItemDetail, .aiResultDetail:
            MapPlaceDetailContent(vm: vm)
        case .routeInfo:
            MapRouteContent(vm: vm)
        case .navigation:
            MapRouteContent(vm: vm)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if vm.showPrecipitation {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.rain.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.oceanBlue)
                    Text("ОСАДКИ")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            } else {
                EmptyView()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Слои") {
                    Toggle(isOn: $vm.showPlaces) {
                        Label("Места", systemImage: "mappin.and.ellipse")
                    }
                    if trip.isActive {
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

                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.showPrecipitation.toggle()
                        }
                    } label: {
                        Label(
                            vm.showPrecipitation ? "Скрыть осадки" : "Карта осадков",
                            systemImage: vm.showPrecipitation ? "cloud.rain.fill" : "cloud.rain"
                        )
                    }

                    Button {
                        vm.showDiscoverNearby = true
                    } label: {
                        Label("Обзор", systemImage: "location.magnifyingglass")
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
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .gray.opacity(0.5))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
    }
}

#if DEBUG
#Preview {
    TripMapView(trip: .preview)
        .modelContainer(.preview)
}
#endif
