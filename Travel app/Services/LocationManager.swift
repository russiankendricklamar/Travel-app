import Foundation
import CoreLocation
import SwiftData
import ActivityKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()

    var isTracking = false
    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var activeDay: TripDay?
    private var modelContext: ModelContext?
    private var trackingActivity: Activity<TrackingActivityAttributes>?
    private var trackingStartTime: Date?
    private var lastLocation: CLLocation?

    /// Persisted tracking state for resume after app relaunch
    private let trackingDayIDKey = "trackingDayID"
    private let trackingTripNameKey = "trackingTripName"
    private let trackingDayLabelKey = "trackingDayLabel"
    private let trackingStartTimeKey = "trackingStartTime"

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Tracking

    func startTracking(for day: TripDay, context: ModelContext) {
        activeDay = day
        modelContext = context
        isTracking = true
        trackingStartTime = Date()
        lastLocation = nil

        // Persist state for app relaunch
        let tripName = day.trip?.country ?? day.trip?.name ?? ""
        let dayLabel = day.cityName ?? "День"
        UserDefaults.standard.set(day.id.uuidString, forKey: trackingDayIDKey)
        UserDefaults.standard.set(tripName, forKey: trackingTripNameKey)
        UserDefaults.standard.set(dayLabel, forKey: trackingDayLabelKey)
        UserDefaults.standard.set(trackingStartTime!.timeIntervalSince1970, forKey: trackingStartTimeKey)

        manager.startUpdatingLocation()
        startLiveActivity(tripName: tripName, dayLabel: dayLabel)
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        activeDay = nil
        modelContext = nil
        trackingStartTime = nil
        lastLocation = nil

        // Clear persisted state
        UserDefaults.standard.removeObject(forKey: trackingDayIDKey)
        UserDefaults.standard.removeObject(forKey: trackingTripNameKey)
        UserDefaults.standard.removeObject(forKey: trackingDayLabelKey)
        UserDefaults.standard.removeObject(forKey: trackingStartTimeKey)

        endLiveActivity()
    }

    /// Resume tracking from persisted state (call on app launch)
    func resumeTrackingIfNeeded(context: ModelContext) {
        guard let dayIDString = UserDefaults.standard.string(forKey: trackingDayIDKey),
              let dayID = UUID(uuidString: dayIDString) else { return }

        let descriptor = FetchDescriptor<TripDay>(predicate: #Predicate { $0.id == dayID })
        guard let day = try? context.fetch(descriptor).first else {
            // Day no longer exists — clean up
            stopTracking()
            return
        }

        activeDay = day
        modelContext = context
        isTracking = true

        let startInterval = UserDefaults.standard.double(forKey: trackingStartTimeKey)
        trackingStartTime = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()

        manager.startUpdatingLocation()

        // Resume or start Live Activity
        let tripName = UserDefaults.standard.string(forKey: trackingTripNameKey) ?? ""
        let dayLabel = UserDefaults.standard.string(forKey: trackingDayLabelKey) ?? "День"

        if Activity<TrackingActivityAttributes>.activities.isEmpty {
            startLiveActivity(tripName: tripName, dayLabel: dayLabel)
        } else {
            trackingActivity = Activity<TrackingActivityAttributes>.activities.first
            updateLiveActivity()
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity(tripName: String, dayLabel: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TrackingActivityAttributes(
            dayLabel: dayLabel,
            tripName: tripName,
            startedAt: trackingStartTime ?? Date()
        )

        let state = TrackingActivityAttributes.ContentState(
            pointCount: activeDay?.routePoints.count ?? 0,
            distanceMeters: 0,
            elapsedSeconds: 0
        )

        let content = ActivityContent(state: state, staleDate: nil)

        do {
            trackingActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("[LocationManager] Failed to start tracking Live Activity: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = trackingActivity, let day = activeDay else { return }

        let elapsed = Int(Date().timeIntervalSince(trackingStartTime ?? Date()))
        let dist = computeRouteDistance(day.routePoints)

        let state = TrackingActivityAttributes.ContentState(
            pointCount: day.routePoints.count,
            distanceMeters: dist,
            elapsedSeconds: elapsed
        )

        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endLiveActivity() {
        Task {
            for activity in Activity<TrackingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        trackingActivity = nil
    }

    private func computeRouteDistance(_ points: [RoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        var total: Double = 0
        for i in 1..<sorted.count {
            let a = CLLocation(latitude: sorted[i - 1].latitude, longitude: sorted[i - 1].longitude)
            let b = CLLocation(latitude: sorted[i].latitude, longitude: sorted[i].longitude)
            total += a.distance(from: b)
        }
        return total
    }

    // MARK: - One-shot location

    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        if let loc = currentLocation { return loc }
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            try? await Task.sleep(for: .seconds(1))
        }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return nil }

        if let pending = oneShotContinuation {
            oneShotContinuation = nil
            pending.resume(returning: currentLocation)
        }

        return await withCheckedContinuation { continuation in
            oneShotContinuation = continuation
            manager.requestLocation()

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                if let cont = self?.oneShotContinuation {
                    self?.oneShotContinuation = nil
                    cont.resume(returning: self?.currentLocation)
                }
            }
        }
    }

    private var oneShotContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate

        // One-shot completion
        if let cont = oneShotContinuation {
            oneShotContinuation = nil
            cont.resume(returning: location.coordinate)
        }

        // Route tracking — filter out points too close together (< 5m)
        if let day = activeDay, let context = modelContext {
            let dominated = lastLocation.map { location.distance(from: $0) < 5 } ?? false
            if !dominated {
                lastLocation = location
                let point = RoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: location.timestamp
                )
                day.routePoints.append(point)
                try? context.save()

                // Update Live Activity every 10 points
                if day.routePoints.count % 10 == 0 {
                    updateLiveActivity()
                }
            }
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
