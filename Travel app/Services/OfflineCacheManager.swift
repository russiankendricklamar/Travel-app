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
