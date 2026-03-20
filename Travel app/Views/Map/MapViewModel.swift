import SwiftUI
import MapKit

// MARK: - Search Completer Delegate

/// NSObject-based delegate that forwards MKLocalSearchCompleter callbacks to MapViewModel.
/// Stored strongly on the view model to keep it alive for the completer's lifetime.
private final class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    weak var viewModel: MapViewModel?

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor [weak self] in
            self?.viewModel?.completerResults = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.viewModel?.completerResults = []
        }
    }
}

// MARK: - Sheet Content Enum

/// Что показывать в bottom sheet
enum MapSheetContent: Equatable {
    case idle
    case searchResults
    case aiSearchResults
    case placeDetail
    case searchItemDetail
    case aiResultDetail
    case routeInfo
    case navigation

    static func == (lhs: MapSheetContent, rhs: MapSheetContent) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.searchResults, .searchResults),
             (.aiSearchResults, .aiSearchResults), (.placeDetail, .placeDetail),
             (.searchItemDetail, .searchItemDetail), (.aiResultDetail, .aiResultDetail),
             (.routeInfo, .routeInfo), (.navigation, .navigation):
            return true
        default:
            return false
        }
    }
}

@Observable
final class MapViewModel {
    let trip: Trip

    // Sheet state
    var sheetDetent: SheetDetent = .peek
    var sheetContent: MapSheetContent = .idle

    // Map layers
    var showPlaces = true
    var showRoutes = true
    var showTrainRoutes = false
    var showFlightArcs = false
    var showAllCities = false
    var showPrecipitation = false
    var isLoadingRadar = false

    // Camera
    var cameraPosition: MapCameraPosition = .automatic
    var hasSetInitialCamera = false
    var visibleRegion: MKCoordinateRegion?

    // Place selection
    var selectedPlaceID: Place.ID?
    var appleMapsInfo: AppleMapsPlaceInfo?
    var isLoadingInfo = false
    var showAppleMapsDetail = false
    var googleDetail: GooglePlaceDetail?
    var isLoadingGoogleDetail = false
    var showAllHours = false
    var showAllReviews = false
    var isNotesExpanded = false

    // Search
    var searchQuery = ""
    var searchResults: [MKMapItem] = []
    var searchTask: Task<Void, Never>?
    var isSearching = false
    var searchedItem: MKMapItem?
    var isAISearchMode = false
    var selectedAIResult: PlaceRecommendation?
    var showDayPickerForAI: PlaceRecommendation?

    // Typeahead completer
    var completerResults: [MKLocalSearchCompletion] = []
    private let searchCompleter = MKLocalSearchCompleter()
    private var completerDelegate: SearchCompleterDelegate?

    /// True when typeahead suggestions should be shown in the UI
    var isCompleterActive: Bool {
        !searchQuery.isEmpty && searchedItem == nil && sheetContent != .searchResults
    }

    // Category quick search
    var selectedCategory: String?
    var isLoadingCategory = false

    static let quickCategories: [(name: String, icon: String, query: String)] = [
        ("Рестораны", "fork.knife", "restaurant"),
        ("Кафе", "cup.and.saucer.fill", "cafe"),
        ("Музеи", "building.columns.fill", "museum"),
        ("Парки", "leaf.fill", "park"),
        ("Магазины", "bag.fill", "shop"),
        ("Отели", "bed.double.fill", "hotel"),
    ]

    // Look Around
    var lookAroundScene: MKLookAroundScene?
    var isLoadingLookAround = false

    // Routing
    var activeRoute: RouteResult?
    var selectedTransportMode: TransportMode = .walking
    var routeFromCurrentLocation = true
    var routeOriginPlaceID: Place.ID?
    var isCalculatingRoute = false
    var routeError: String?
    var alternativeRoutes: [RouteResult] = []
    var selectedRouteIndex: Int = 0

    var selectedRoute: RouteResult? {
        guard selectedRouteIndex < alternativeRoutes.count else { return nil }
        return alternativeRoutes[selectedRouteIndex]
    }

    // Navigation
    var isNavigating: Bool = false
    var navigationEngine: NavigationEngine?
    var navigationSteps: [NavigationStep] = []
    var currentStepIndex: Int = 0
    var distanceToNextStep: CLLocationDistance = 0
    private var voiceService: NavigationVoiceService?
    /// Destination coordinate of the active navigation route
    var activeRouteDestination: CLLocationCoordinate2D?
    /// HUD urgency state — hysteresis: activates < 50m, deactivates > 65m
    var isUrgent: Bool = false
    /// True when user manually panned away from their location during navigation
    var isOffNavCenter: Bool = false

    // Transport overlays
    var flightArcs: [FlightArc] = []
    var trainRoutes: [TrainRoute] = []

    // Misc
    var showDiscoverNearby = false
    #if !targetEnvironment(simulator)
    var arPlace: Place?
    #endif

    init(trip: Trip) {
        self.trip = trip
        let delegate = SearchCompleterDelegate()
        completerDelegate = delegate
        searchCompleter.delegate = delegate
        searchCompleter.resultTypes = [.pointOfInterest, .address]
        delegate.viewModel = self
    }

    // MARK: - Computed Properties

    var allPlaces: [Place] { trip.allPlaces }

    var visiblePlaces: [Place] {
        guard trip.isActive, !showAllCities else { return allPlaces }
        if let today = trip.sortedDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            let cityName = today.cityName
            return trip.days.filter { $0.cityName == cityName }.flatMap(\.places)
        }
        return allPlaces
    }

    var daysWithRoutes: [TripDay] {
        trip.sortedDays.filter { !$0.routePoints.isEmpty }
    }

    var selectedPlace: Place? {
        guard let id = selectedPlaceID else { return nil }
        return allPlaces.first { $0.id == id }
    }

    var routeOriginPlace: Place? {
        guard let id = routeOriginPlaceID else { return nil }
        return allPlaces.first { $0.id == id }
    }

    var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName))).sorted()
    }

    var hasSearchResults: Bool {
        !searchResults.isEmpty || (isAISearchMode && !AIMapSearchService.shared.results.isEmpty)
    }

    var flightAirportAnnotations: [FlightAirportPin] {
        TransportOverlayLoader.flightAirportAnnotations(from: flightArcs)
    }

    /// "День N из M — Город" label for navigation context
    var tripContextLabel: String {
        let days = trip.sortedDays
        guard !days.isEmpty else { return "" }
        let todayIndex = days.firstIndex(where: { Calendar.current.isDateInToday($0.date) })
        let idx = (todayIndex ?? 0) + 1
        let city = days.first(where: { Calendar.current.isDateInToday($0.date) })?.cityName
                   ?? days.first?.cityName ?? trip.country
        return "День \(idx) из \(days.count) — \(city)"
    }

    /// ETA as time-of-arrival string (e.g. "14:32")
    var etaString: String {
        guard let route = activeRoute else { return "" }
        let arrival = Date().addingTimeInterval(route.expectedTravelTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: arrival)
    }

    // MARK: - Sheet State Machine

    func onPlaceSelected() {
        appleMapsInfo = nil
        googleDetail = nil
        activeRoute = nil
        alternativeRoutes = []
        selectedRouteIndex = 0
        showAllHours = false
        showAllReviews = false
        lookAroundScene = nil

        guard selectedPlace != nil else {
            if sheetContent == .placeDetail {
                sheetContent = .idle
                withAnimation(.spring(response: 0.3)) { sheetDetent = .peek }
            }
            return
        }
        sheetContent = .placeDetail
        withAnimation(.spring(response: 0.3)) { sheetDetent = .half }
    }

    func selectSearchResult(_ item: MKMapItem) {
        searchedItem = item
        sheetContent = .searchItemDetail
        withAnimation(.spring(response: 0.3)) { sheetDetent = .half }

        if let coord = item.placemark.location?.coordinate {
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                )
            }
        }
    }

    func selectAIResult(_ rec: PlaceRecommendation) {
        selectedAIResult = rec
        sheetContent = .aiResultDetail
        withAnimation(.spring(response: 0.3)) { sheetDetent = .half }

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

    func clearSelection() {
        selectedPlaceID = nil
        searchedItem = nil
        selectedAIResult = nil
        activeRoute = nil
        alternativeRoutes = []
        selectedRouteIndex = 0
        sheetContent = .idle
        withAnimation(.spring(response: 0.3)) { sheetDetent = .peek }
    }

    /// Dismiss detail view and return to fresh search (swipe-down behavior)
    func dismissDetail() {
        selectedPlaceID = nil
        searchedItem = nil
        selectedAIResult = nil
        activeRoute = nil
        alternativeRoutes = []
        selectedRouteIndex = 0
        searchQuery = ""
        searchResults = []
        completerResults = []
        searchCompleter.queryFragment = ""
        lookAroundScene = nil
        selectedCategory = nil
        AIMapSearchService.shared.clear()
        isAISearchMode = false
        sheetContent = .idle
    }

    // MARK: - Search

    func submitSearch() {
        searchTask?.cancel()
        searchedItem = nil
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }

        if isAISearchMode {
            let city = trip.sortedDays.first?.cityName ?? ""
            let coord = visibleRegion?.center ?? allPlaces.first?.coordinate
            searchTask = Task {
                await AIMapSearchService.shared.search(
                    query: trimmed, city: city,
                    nearCoordinate: coord, mapRegion: visibleRegion
                )
                if let first = AIMapSearchService.shared.results.first,
                   first.latitude != 0, first.longitude != 0 {
                    sheetContent = .aiSearchResults
                    zoomToAIResults()
                }
            }
        } else {
            searchTask = Task { await performMapSearch(query: trimmed) }
        }
    }

    func performMapSearch(query: String) async {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        if let region = visibleRegion {
            request.region = region
        } else if let first = allPlaces.first {
            request.region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
            sheetContent = .searchResults
            withAnimation(.spring(response: 0.3)) { sheetDetent = .half }
            zoomToSearchResults()
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func performCategorySearch(query: String, category: String) async {
        isLoadingCategory = true
        selectedCategory = category
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest]

        if let region = visibleRegion {
            request.region = region
        } else if let first = allPlaces.first {
            request.region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
            sheetContent = .searchResults
            withAnimation(.spring(response: 0.3)) { sheetDetent = .half }
            zoomToSearchResults()
        } catch {
            searchResults = []
        }
        isLoadingCategory = false
    }

    func fetchLookAround(coordinate: CLLocationCoordinate2D) async {
        isLoadingLookAround = true
        lookAroundScene = nil
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        lookAroundScene = try? await request.scene
        isLoadingLookAround = false
    }

    /// Feed a new query fragment to the completer for instant typeahead suggestions.
    /// Call this on every keystroke (no debounce needed — MKLocalSearchCompleter is throttled internally).
    func updateCompleterQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            completerResults = []
            searchCompleter.queryFragment = ""
            return
        }
        if let region = visibleRegion {
            searchCompleter.region = region
        }
        searchCompleter.queryFragment = trimmed
    }

    /// Resolve a completer completion to a full MKMapItem and show it as a selected search result.
    func selectCompleterResult(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if let item = response.mapItems.first {
                completerResults = []
                selectSearchResult(item)
            }
        } catch {
            // If resolution fails, fill the text field so user can submit manually
            searchQuery = completion.title
            completerResults = []
        }
    }

    func dismissSearch() {
        searchQuery = ""
        searchResults = []
        searchedItem = nil
        isAISearchMode = false
        selectedAIResult = nil
        completerResults = []
        searchCompleter.queryFragment = ""
        AIMapSearchService.shared.clear()
        sheetContent = .idle
        withAnimation(.spring(response: 0.3)) { sheetDetent = .peek }
    }

    func formatSearchAddress(_ item: MKMapItem) -> String? {
        let pm = item.placemark
        var parts: [String] = []
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let locality = pm.locality { parts.append(locality) }
        if let admin = pm.administrativeArea, !parts.contains(admin) { parts.append(admin) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Routing

    func calculateDirectionRoute(to place: Place) async {
        isCalculatingRoute = true
        routeError = nil
        let destination = place.coordinate

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

        let results = await RoutingService.shared.calculateRoute(
            from: origin, to: destination, mode: selectedTransportMode
        )

        if let firstRoute = results.first {
            withAnimation(.spring(response: 0.3)) {
                alternativeRoutes = results
                selectedRouteIndex = 0
                activeRoute = firstRoute
                sheetContent = .routeInfo
                sheetDetent = .half
            }
            zoomToRoute(firstRoute)

            // Store destination for rerouting
            activeRouteDestination = destination

            // Fetch turn-by-turn steps in background
            Task {
                let steps = await RoutingService.shared.fetchNavigationSteps(
                    from: origin,
                    to: destination,
                    mode: selectedTransportMode,
                    existingTransitSteps: firstRoute.transitSteps
                )
                self.navigationSteps = steps
            }

            // Load ETA previews for other modes in background
            Task { await RoutingService.shared.fetchETAPreviews(from: origin, to: destination) }
        } else {
            routeError = RoutingService.shared.lastError ?? "Маршрут не найден"
        }

        isCalculatingRoute = false
    }

    func calculateRouteToSearchedItem(_ item: MKMapItem) async {
        guard let destination = item.placemark.location?.coordinate else { return }
        isCalculatingRoute = true
        routeError = nil

        guard let origin = await LocationManager.shared.requestCurrentLocation() else {
            routeError = "Не удалось определить геопозицию"
            isCalculatingRoute = false
            return
        }

        let results = await RoutingService.shared.calculateRoute(
            from: origin, to: destination, mode: selectedTransportMode
        )

        if let firstRoute = results.first {
            withAnimation(.spring(response: 0.3)) {
                alternativeRoutes = results
                selectedRouteIndex = 0
                activeRoute = firstRoute
                sheetContent = .routeInfo
                sheetDetent = .half
            }
            zoomToRoute(firstRoute)

            // Store destination for rerouting
            activeRouteDestination = destination

            // Fetch turn-by-turn steps in background
            Task {
                let steps = await RoutingService.shared.fetchNavigationSteps(
                    from: origin,
                    to: destination,
                    mode: selectedTransportMode,
                    existingTransitSteps: firstRoute.transitSteps
                )
                self.navigationSteps = steps
            }

            // Load ETA previews for other modes in background
            Task { await RoutingService.shared.fetchETAPreviews(from: origin, to: destination) }
        } else {
            routeError = RoutingService.shared.lastError ?? "Маршрут не найден"
        }

        isCalculatingRoute = false
    }

    func clearRoute() {
        if isNavigating {
            stopNavigation()
        }
        withAnimation(.spring(response: 0.3)) {
            activeRoute = nil
            alternativeRoutes = []
            selectedRouteIndex = 0
            navigationSteps = []
            activeRouteDestination = nil
            if selectedPlace != nil {
                sheetContent = .placeDetail
            } else if searchedItem != nil {
                sheetContent = .searchItemDetail
            } else {
                sheetContent = .idle
                sheetDetent = .peek
            }
        }
    }

    // MARK: - Navigation

    /// Start turn-by-turn navigation on the active route.
    /// If navigation steps have not been fetched yet (e.g., user taps Start before
    /// the background fetch completes), this method awaits the fetch inline to
    /// prevent a silent no-op.
    func startNavigation() async {
        guard let route = activeRoute else { return }

        // If steps not yet fetched, await them now instead of silently failing
        if navigationSteps.isEmpty, let destination = activeRouteDestination {
            let origin = LocationManager.shared.currentLocation
                ?? route.polyline.first ?? CLLocationCoordinate2D()
            navigationSteps = await RoutingService.shared.fetchNavigationSteps(
                from: origin,
                to: destination,
                mode: selectedTransportMode,
                existingTransitSteps: route.transitSteps
            )
        }

        guard !navigationSteps.isEmpty else { return }

        let voice = NavigationVoiceService()
        voiceService = voice

        let engine = NavigationEngine(route: route, steps: navigationSteps, voiceService: voice)
        engine.onStepAdvanced = { [weak self] index, distance in
            self?.currentStepIndex = index
            self?.distanceToNextStep = distance
            // Urgency hysteresis: activate < 50m, deactivate > 65m
            if distance < 50 { self?.isUrgent = true }
            else if distance > 65 { self?.isUrgent = false }
        }
        engine.onRerouteNeeded = { [weak self] from in
            Task { @MainActor in
                await self?.rerouteNavigation(from: from)
            }
        }
        engine.onNavigationFinished = { [weak self] in
            self?.stopNavigation()
        }

        navigationEngine = engine
        isNavigating = true

        // Camera heading lock
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
        }

        // Switch sheet to navigation mode
        withAnimation(.spring(response: 0.3)) {
            sheetContent = .navigation
            sheetDetent = .peek
        }

        // Switch LocationManager to navigation mode and wire GPS callback.
        // CRITICAL: capture [weak self] and use self?.navigationEngine to avoid
        // capturing the local `engine` variable — once startNavigation() returns,
        // the local binding is released and a [weak engine] capture becomes nil.
        LocationManager.shared.startNavigationMode()
        LocationManager.shared.onLocationUpdate = { [weak self] location in
            self?.navigationEngine?.processLocation(location)
        }

        // Announce first step
        if let firstStep = navigationSteps.first {
            voice.announceStep(instruction: firstStep.instruction, distanceRemaining: firstStep.distance)
        }
    }

    /// Stop navigation and clean up
    func stopNavigation() {
        navigationEngine = nil
        voiceService?.resetAll()
        voiceService = nil
        isNavigating = false
        currentStepIndex = 0
        distanceToNextStep = 0
        activeRouteDestination = nil
        alternativeRoutes = []
        selectedRouteIndex = 0
        isUrgent = false
        isOffNavCenter = false

        // Restore camera to automatic
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .automatic
        }

        // Return to route info sheet
        withAnimation(.spring(response: 0.3)) {
            sheetContent = .routeInfo
            sheetDetent = .half
        }

        // Revert LocationManager to standard mode and clear callback
        LocationManager.shared.onLocationUpdate = nil
        LocationManager.shared.stopNavigationMode()
    }

    /// Re-center map on user location with heading lock after manual pan
    func recenterNavigation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
            isOffNavCenter = false
        }
    }

    /// Reroute after off-route detection
    private func rerouteNavigation(from origin: CLLocationCoordinate2D) async {
        guard let destination = activeRouteDestination else {
            navigationEngine?.cancelReroute()
            return
        }

        // Fetch new route via RoutingService
        let results = await RoutingService.shared.calculateRoute(
            from: origin,
            to: destination,
            mode: selectedTransportMode
        )

        guard let newRoute = results.first else {
            navigationEngine?.cancelReroute()
            return
        }

        // Clear alternatives during navigation reroute (no carousel in nav mode)
        alternativeRoutes = []
        selectedRouteIndex = 0

        // Fetch new navigation steps
        let newSteps = await RoutingService.shared.fetchNavigationSteps(
            from: origin,
            to: destination,
            mode: selectedTransportMode,
            existingTransitSteps: newRoute.transitSteps
        )

        // Update route display
        activeRoute = newRoute
        navigationSteps = newSteps

        // Update engine with new route data
        navigationEngine?.didReceiveNewRoute(newRoute, steps: newSteps)
        currentStepIndex = 0
    }

    // MARK: - Camera

    func zoomToAll() {
        let lats = allPlaces.map(\.latitude)
        let lons = allPlaces.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                    span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.05), longitudeDelta: max((maxLon - minLon) * 1.5, 0.05))
                )
            )
        }
    }

    func zoomToCity(_ city: String) {
        let cityPlaces = trip.days.filter { $0.cityName == city }.flatMap(\.places)
        guard let first = cityPlaces.first else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: first.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
            )
        }
    }

    func zoomToSearchResults() {
        let coords = searchResults.compactMap { $0.placemark.location?.coordinate }
        guard !coords.isEmpty else { return }
        zoomToBoundingBox(coords)
    }

    func zoomToAIResults() {
        let results = AIMapSearchService.shared.results.filter { $0.latitude != 0 && $0.longitude != 0 }
        let coords = results.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard !coords.isEmpty else { return }
        zoomToBoundingBox(coords)
    }

    func setInitialCamera() {
        if trip.isActive, let current = LocationManager.shared.currentLocation {
            cameraPosition = .region(
                MKCoordinateRegion(center: current, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            )
            hasSetInitialCamera = true
            return
        }

        if trip.isActive {
            let coords = (visiblePlaces.isEmpty ? allPlaces : visiblePlaces).map(\.coordinate)
            if !coords.isEmpty { zoomToBoundingBoxImmediate(coords, padding: 1.4) }
            return
        }

        let coords = allPlaces.map(\.coordinate)
        guard !coords.isEmpty else { return }
        zoomToBoundingBoxImmediate(coords, padding: 1.4)
        hasSetInitialCamera = true
    }

    func geocodeCountryCamera() async {
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
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(center: allCoords[0], span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8))
                )
            }
        } else {
            zoomToBoundingBox(allCoords, padding: 1.5, minSpan: 4)
        }
        hasSetInitialCamera = true
    }

    // MARK: - Transport Loading

    func loadTransportOverlays() async {
        flightArcs = await TransportOverlayLoader.loadFlightArcs(for: trip)
        trainRoutes = await TransportOverlayLoader.loadTrainRoutes(for: trip)
    }

    // MARK: - Helpers

    func routeColor(for day: TripDay) -> Color {
        let dayColors: [Color] = [AppTheme.sakuraPink, .red, .brown, .green, .orange]
        guard let index = trip.sortedDays.firstIndex(where: { $0.id == day.id }) else {
            return AppTheme.sakuraPink
        }
        return dayColors[index % dayColors.count]
    }

    func transportModeIcon() -> String {
        switch selectedTransportMode {
        case .walking: return "figure.walk"
        case .automobile: return "car.fill"
        case .transit: return "tram.fill"
        case .cycling: return "bicycle"
        }
    }

    func priceLevelDisplay(_ level: String) -> String {
        switch level {
        case "PRICE_LEVEL_FREE": return "Бесплатно"
        case "PRICE_LEVEL_INEXPENSIVE": return "$"
        case "PRICE_LEVEL_MODERATE": return "$$"
        case "PRICE_LEVEL_EXPENSIVE": return "$$$"
        case "PRICE_LEVEL_VERY_EXPENSIVE": return "$$$$"
        default: return ""
        }
    }

    // MARK: - Private Camera Helpers

    private func zoomToRoute(_ result: RouteResult?) {
        guard let route = result else { return }
        let lats = route.polyline.map(\.latitude)
        let lons = route.polyline.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                    span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.01), longitudeDelta: max((maxLon - minLon) * 1.5, 0.01))
                )
            )
        }
    }

    private func zoomToBoundingBox(_ coords: [CLLocationCoordinate2D], padding: Double = 1.5, minSpan: Double = 0.01) {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                    span: MKCoordinateSpan(
                        latitudeDelta: max((maxLat - minLat) * padding, minSpan),
                        longitudeDelta: max((maxLon - minLon) * padding, minSpan)
                    )
                )
            )
        }
    }

    private func zoomToBoundingBoxImmediate(_ coords: [CLLocationCoordinate2D], padding: Double) {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                span: MKCoordinateSpan(
                    latitudeDelta: max((maxLat - minLat) * padding, 0.02),
                    longitudeDelta: max((maxLon - minLon) * padding, 0.02)
                )
            )
        )
    }
}
