import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    let trip: Trip

    @Query var offlineCaches: [OfflineMapCache]
    @State private var vm: MapViewModel
    @FocusState private var isSearchFocused: Bool
    @Environment(\.modelContext) private var modelContext

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

    /// Idle mode: sheet at peek with no active content — tab bar visible
    private var isIdleMode: Bool {
        vm.sheetDetent == .peek && vm.sheetContent == .idle
    }

    /// Returns the most relevant day for pre-caching (today if active trip, else first day with >= 2 places).
    private var currentDayForPrecache: TripDay? {
        let days = trip.sortedDays.filter { $0.sortedPlaces.count >= 2 }
        if let today = days.first(where: { Calendar.current.isDateInToday($0.date) }) {
            return today
        }
        return days.first
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

                // MARK: - Offline cache indicator (floating, above sheet)
                if !isOfflineWithCache && isIdleMode, let day = currentDayForPrecache,
                   RoutingCacheService.shared.isDayCached(day, tripID: trip.id, context: modelContext) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.bambooGreen)
                                .accessibilityLabel("День подготовлен офлайн")
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.bottom, 128) // Above sheet peek
                    }
                }

                // MARK: - Navigation HUD (floating top card)
                if vm.isNavigating {
                    VStack {
                        NavigationHUDView(vm: vm)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Offline reroute warning toast
                        if vm.showOfflineRerouteWarning {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.templeGold)
                                Text("Перестроение недоступно офлайн")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeOut(duration: 0.25), value: vm.showOfflineRerouteWarning)
                        }

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: vm.isNavigating)
                }

                // MARK: - Precipitation Overlay Label (floating capsule)
                if vm.showPrecipitation {
                    VStack {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.rain.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.oceanBlue)
                            Text("ОСАДКИ")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(3)
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.top, 60)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: vm.showPrecipitation)
                }

                // MARK: - Recenter Button (appears on manual pan during navigation)
                if vm.isNavigating && vm.isOffNavCenter {
                    VStack {
                        Spacer()
                        MapRecenterButton {
                            vm.recenterNavigation()
                        }
                        .padding(.bottom, 100) // Above the bottom sheet peek
                    }
                    .animation(.spring(response: 0.3), value: vm.isOffNavCenter)
                }

                // MARK: - Bottom Sheet (always visible — Apple Maps style)
                if !isOfflineWithCache {
                    MapBottomSheet(detent: $vm.sheetDetent) {
                        sheetBody
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isIdleMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
                vm.modelContext = modelContext   // inject for offline cache access
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
                await backgroundRefreshIfNeeded()
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
                await vm.fetchLookAround(coordinate: place.coordinate)
            }
            .onChange(of: vm.searchedItem) { _, newItem in
                guard let coord = newItem?.placemark.location?.coordinate else {
                    vm.lookAroundScene = nil
                    return
                }
                Task { await vm.fetchLookAround(coordinate: coord) }
            }
            .onChange(of: vm.sheetDetent) { oldDetent, newDetent in
                // Guard: do NOT dismiss during active navigation — user may collapse sheet to peek
                guard newDetent == .peek && oldDetent != .peek && !vm.isNavigating else { return }

                let hasActiveSearch = !vm.searchQuery.isEmpty || !vm.searchResults.isEmpty || !vm.completerResults.isEmpty
                let isInDetailMode = vm.sheetContent == .placeDetail || vm.sheetContent == .searchItemDetail || vm.sheetContent == .aiResultDetail

                if isInDetailMode {
                    // Viewing place detail → full reset (Apple Maps: swipe down closes detail)
                    vm.dismissDetail()
                } else if hasActiveSearch {
                    // Active search/typeahead → preserve search, just minimize
                    // Bounce to half so search bar stays visible (74pt peek is too small)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        vm.sheetDetent = .half
                    }
                } else {
                    // No search, no detail → full reset
                    vm.dismissDetail()
                }
            }
            .onChange(of: vm.searchQuery) { _, newValue in
                guard !vm.isAISearchMode else { return }
                vm.searchTask?.cancel()
                vm.searchedItem = nil
                // Drive the instant typeahead completer — no debounce needed.
                // Explicit MKLocalSearch is only triggered on keyboard submit (vm.submitSearch).
                vm.updateCompleterQuery(newValue)
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
                    let rawCoords = day.routePoints.sorted { $0.timestamp < $1.timestamp }.map(\.coordinate)
                    let coords = PolylineSmoother.smooth(coordinates: rawCoords)
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
                // Outer glow layer — wide, translucent
                MapPolyline(coordinates: route.polyline)
                    .stroke(route.mode.color.opacity(0.3), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                // Inner core layer — narrow, solid
                MapPolyline(coordinates: route.polyline)
                    .stroke(route.mode.color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
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
            MapCompass()
            MapUserLocationButton()
            MapPitchToggle()
        }
        .safeAreaPadding(.bottom, isIdleMode ? 120 : 0)
        .onMapCameraChange { context in
            vm.visibleRegion = context.region
            // Detect manual pan during navigation — show recenter button if > 50m from user location
            if vm.isNavigating, let userLoc = LocationManager.shared.currentLocation {
                let center = context.region.center
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                vm.isOffNavCenter = distance > 50
            }
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
            NavigationSheetContent(vm: vm)
        }
    }

    // MARK: - Background Refresh

    /// Silently refresh stale route caches when online (no progress UI).
    private func backgroundRefreshIfNeeded() async {
        guard OfflineCacheManager.shared.isOnline else { return }
        guard let day = currentDayForPrecache else { return }
        // Only refresh if day was previously cached but TTL expired
        guard !RoutingCacheService.shared.isDayCached(day, tripID: trip.id, context: modelContext) else { return }
        // Check if any routes exist for this trip (partial/stale cache)
        // If isDayCached returns false but routes exist for the day, refresh silently
        await OfflineCacheManager.shared.preCacheDay(
            day,
            tripID: trip.id,
            context: modelContext,
            progress: { _ in }  // Silent — no UI feedback
        )
    }
}

#if DEBUG
#Preview {
    TripMapView(trip: .preview)
        .modelContainer(.preview)
}
#endif
