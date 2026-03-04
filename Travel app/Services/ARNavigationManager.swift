import Foundation
import CoreLocation

@Observable
final class ARNavigationManager: NSObject, CLLocationManagerDelegate {
    static let shared = ARNavigationManager()

    private(set) var currentDistance: Double = 0
    private(set) var bearing: Double = 0
    private(set) var walkingTimeMinutes: Int = 0
    private(set) var isActive = false

    private var targetCoordinate: CLLocationCoordinate2D?
    private var currentHeading: Double = 0

    #if !targetEnvironment(simulator)
    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter = 2
    }

    func startSession(to target: CLLocationCoordinate2D) {
        targetCoordinate = target
        isActive = true
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopSession() {
        isActive = false
        targetCoordinate = nil
        currentDistance = 0
        bearing = 0
        walkingTimeMinutes = 0
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last, let target = targetCoordinate else { return }

        let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
        currentDistance = userLocation.distance(from: targetLocation)

        bearing = calculateBearing(
            from: userLocation.coordinate,
            to: target
        )

        // Walking speed ~5 km/h = ~83.3 m/min
        let walkingSpeedMetersPerMinute: Double = 83.3
        walkingTimeMinutes = max(1, Int(ceil(currentDistance / walkingSpeedMetersPerMinute)))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading.trueHeading
    }

    #else
    // Simulator stubs
    private override init() {
        super.init()
    }

    func startSession(to target: CLLocationCoordinate2D) {
        targetCoordinate = target
        isActive = true
        currentDistance = 450
        bearing = 45
        walkingTimeMinutes = 5
    }

    func stopSession() {
        isActive = false
        targetCoordinate = nil
        currentDistance = 0
        bearing = 0
        walkingTimeMinutes = 0
    }
    #endif

    // MARK: - Haversine Bearing

    private func calculateBearing(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let lat1 = source.latitude.toRadians
        let lon1 = source.longitude.toRadians
        let lat2 = destination.latitude.toRadians
        let lon2 = destination.longitude.toRadians

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        return (radiansBearing.toDegrees + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Angle Conversion

private extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}
