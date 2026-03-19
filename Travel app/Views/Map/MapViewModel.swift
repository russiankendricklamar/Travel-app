import SwiftUI
import MapKit

/// Что показывать в bottom sheet
enum MapSheetContent: Equatable {
    case idle
    case searchResults
    case aiSearchResults
    case placeDetail
    case searchItemDetail
    case aiResultDetail
    case routeInfo

    static func == (lhs: MapSheetContent, rhs: MapSheetContent) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.searchResults, .searchResults),
             (.aiSearchResults, .aiSearchResults), (.placeDetail, .placeDetail),
             (.searchItemDetail, .searchItemDetail), (.aiResultDetail, .aiResultDetail),
             (.routeInfo, .routeInfo):
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

    // Routing
    var activeRoute: RouteResult?
    var selectedTransportMode: TransportMode = .walking
    var routeFromCurrentLocation = true
    var routeOriginPlaceID: Place.ID?
    var isCalculatingRoute = false
    var routeError: String?

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

    // MARK: - Sheet State Machine

    func onPlaceSelected() {
        appleMapsInfo = nil
        googleDetail = nil
        activeRoute = nil
        showAllHours = false
        showAllReviews = false

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
        sheetContent = .idle
        withAnimation(.spring(response: 0.3)) { sheetDetent = .peek }
    }

    /// Dismiss detail view and return to fresh search (swipe-down behavior)
    func dismissDetail() {
        selectedPlaceID = nil
        searchedItem = nil
        selectedAIResult = nil
        activeRoute = nil
        searchQuery = ""
        searchResults = []
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

    func dismissSearch() {
        searchQuery = ""
        searchResults = []
        searchedItem = nil
        isAISearchMode = false
        selectedAIResult = nil
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

        let result = await RoutingService.shared.calculateRoute(
            from: origin, to: destination, mode: selectedTransportMode
        )

        if let result {
            withAnimation(.spring(response: 0.3)) {
                activeRoute = result
                sheetContent = .routeInfo
                sheetDetent = .half
            }
            zoomToRoute(result)

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

        let result = await RoutingService.shared.calculateRoute(
            from: origin, to: destination, mode: selectedTransportMode
        )

        if let result {
            withAnimation(.spring(response: 0.3)) {
                activeRoute = result
                sheetContent = .routeInfo
                sheetDetent = .half
            }
            zoomToRoute(result)

            // Load ETA previews for other modes in background
            Task { await RoutingService.shared.fetchETAPreviews(from: origin, to: destination) }
        } else {
            routeError = RoutingService.shared.lastError ?? "Маршрут не найден"
        }

        isCalculatingRoute = false
    }

    func clearRoute() {
        withAnimation(.spring(response: 0.3)) {
            activeRoute = nil
            // Return to previous detail or idle
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
