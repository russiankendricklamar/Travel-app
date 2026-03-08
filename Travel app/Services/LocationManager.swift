import Foundation
import CoreLocation
import SwiftData

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()

    var isTracking = false
    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var activeDay: TripDay?
    private var modelContext: ModelContext?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking(for day: TripDay, context: ModelContext) {
        activeDay = day
        modelContext = context
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        activeDay = nil
        modelContext = nil
    }

    // MARK: - CLLocationManagerDelegate

    /// One-shot location request (no tracking needed)
    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        if let loc = currentLocation { return loc }
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            try? await Task.sleep(for: .seconds(1))
        }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return nil }
        return await withCheckedContinuation { continuation in
            oneShotContinuation = continuation
            manager.requestLocation()
        }
    }

    private var oneShotContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate

        // One-shot completion
        if let cont = oneShotContinuation {
            oneShotContinuation = nil
            cont.resume(returning: location.coordinate)
        }

        // Route tracking
        if let day = activeDay, let context = modelContext {
            let point = RoutePoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp
            )
            day.routePoints.append(point)
            try? context.save()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let cont = oneShotContinuation {
            oneShotContinuation = nil
            cont.resume(returning: nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

// MARK: - Route Point Model

@Model
final class RoutePoint: Syncable {
    @Attribute(.unique) var id: UUID = UUID()
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var day: TripDay?

    init(latitude: Double, longitude: Double, timestamp: Date) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
