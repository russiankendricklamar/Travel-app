import Foundation
import Network
import MapKit
import SwiftData

@MainActor @Observable
final class OfflineCacheManager {
    static let shared = OfflineCacheManager()
    private init() {}

    var isOnline = true
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "offline.monitor")

    // MARK: - Weather Cache

    private let weatherCacheKey = "cached_weather_data"

    func cacheWeather(_ data: Data) {
        UserDefaults.standard.set(data, forKey: weatherCacheKey)
    }

    func cachedWeather() -> Data? {
        UserDefaults.standard.data(forKey: weatherCacheKey)
    }

    // MARK: - Network Monitoring

    func startMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
        self.monitor = monitor
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }

    // MARK: - Map Snapshot Pre-Cache

    func generateSnapshot(for day: TripDay) async -> Data? {
        let places = day.places
        guard !places.isEmpty else { return nil }

        let lats = places.map(\.latitude)
        let lons = places.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let spanLat = max((maxLat - minLat) * 1.5, 0.01)
        let spanLon = max((maxLon - minLon) * 1.5, 0.01)

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
        options.size = CGSize(width: 400, height: 300)
        options.scale = 2.0

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            return snapshot.image.pngData()
        } catch {
            return nil
        }
    }

    // MARK: - Route Pre-Cache

    /// Pre-cache all N^2 Place pairs for a day in walking + automobile modes.
    /// Fetches routes in parallel, then stores on @MainActor (ModelContext thread safety).
    func preCacheDay(
        _ day: TripDay,
        tripID: UUID,
        context: ModelContext,
        progress: @escaping @MainActor (Double) -> Void
    ) async {
        let places = day.sortedPlaces
        guard places.count >= 2 else { return }

        // Build all ordered pairs (A->B and B->A both needed)
        var pairs: [(Place, Place)] = []
        for i in 0..<places.count {
            for j in 0..<places.count where i != j {
                pairs.append((places[i], places[j]))
            }
        }

        let modes: [TransportMode] = [.walking, .automobile]
        let totalRequests = pairs.count * modes.count
        guard totalRequests > 0 else { return }

        // Collect results from parallel tasks (thread-safe collection)
        struct CacheEntry: Sendable {
            let result: RouteResult
            let originID: UUID
            let destID: UUID
        }

        var completed = 0

        // Fetch routes in parallel, collect results
        let entries: [CacheEntry] = await withTaskGroup(of: CacheEntry?.self, returning: [CacheEntry].self) { group in
            for (origin, dest) in pairs {
                for mode in modes {
                    let originCoord = origin.coordinate
                    let destCoord = dest.coordinate
                    let originID = origin.id
                    let destID = dest.id
                    group.addTask {
                        // Fetch route from API
                        let results = await RoutingService.shared.calculateRoute(
                            from: originCoord,
                            to: destCoord,
                            mode: mode
                        )
                        guard var route = results.first else { return nil }

                        // Fetch navigation steps if not already present
                        if route.navigationSteps.isEmpty {
                            let steps = await RoutingService.shared.fetchNavigationSteps(
                                from: originCoord,
                                to: destCoord,
                                mode: mode,
                                existingTransitSteps: route.transitSteps
                            )
                            route = RouteResult(
                                polyline: route.polyline,
                                distance: route.distance,
                                expectedTravelTime: route.expectedTravelTime,
                                mode: route.mode,
                                transitSteps: route.transitSteps,
                                trafficDuration: route.trafficDuration,
                                originAddress: route.originAddress,
                                navigationSteps: steps
                            )
                        }

                        return CacheEntry(result: route, originID: originID, destID: destID)
                    }
                }
            }

            var collected: [CacheEntry] = []
            for await entry in group {
                completed += 1
                await progress(Double(completed) / Double(totalRequests))
                if let entry { collected.append(entry) }
            }
            return collected
        }

        // Store all results on @MainActor (ModelContext is main-actor-bound)
        for entry in entries {
            RoutingCacheService.shared.store(
                entry.result,
                origin: entry.originID,
                dest: entry.destID,
                tripID: tripID,
                context: context
            )
        }
    }

    func preCacheTrip(_ trip: Trip, context: ModelContext, progress: @escaping (Double) -> Void) async {
        let daysWithPlaces = trip.sortedDays.filter { !$0.places.isEmpty }
        guard !daysWithPlaces.isEmpty else { return }

        for (index, day) in daysWithPlaces.enumerated() {
            if let data = await generateSnapshot(for: day) {
                let places = day.places
                let lats = places.map(\.latitude)
                let lons = places.map(\.longitude)
                let centerLat = (lats.min()! + lats.max()!) / 2
                let centerLon = (lons.min()! + lons.max()!) / 2

                let cache = OfflineMapCache(
                    tripDayID: day.id,
                    snapshotData: data,
                    centerLatitude: centerLat,
                    centerLongitude: centerLon
                )
                context.insert(cache)
            }
            progress(Double(index + 1) / Double(daysWithPlaces.count))
        }
        try? context.save()

        // Cache weather for first day's city
        if let firstDay = daysWithPlaces.first {
            let coord = await WeatherService.shared.resolveCoordinate(forCity: firstDay.cityName)
            if let coord {
                await WeatherService.shared.fetchWeather(for: coord)
            }
        }
    }
}
