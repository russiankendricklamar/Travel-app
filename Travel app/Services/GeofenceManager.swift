import Foundation
import CoreLocation
import UserNotifications
import SwiftData

@Observable
final class GeofenceManager: NSObject, CLLocationManagerDelegate {
    static let shared = GeofenceManager()

    private let locationManager = CLLocationManager()
    private(set) var isActive = false
    private var monitoredPlaceIDs: Set<String> = []

    @ObservationIgnored
    private var modelContext: ModelContext?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func activate(for trip: Trip, context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "geofence_enabled") else { return }
        self.modelContext = context
        isActive = true
        refreshMonitoredRegions(for: trip)
    }

    func deactivate() {
        isActive = false
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredPlaceIDs.removeAll()
    }

    func refreshMonitoredRegions(for trip: Trip) {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredPlaceIDs.removeAll()

        // Smart selection: today's unvisited (up to 10) + next day (up to 5) + nearest (up to 5) = max 20
        var selected: [Place] = []

        let todayPlaces = trip.sortedDays
            .first(where: { $0.isToday })?
            .places.filter { !$0.isVisited } ?? []
        selected.append(contentsOf: todayPlaces.prefix(10))

        let tomorrowPlaces = trip.sortedDays
            .first(where: { $0.isFuture })?
            .places.filter { !$0.isVisited } ?? []
        let remaining = 15 - selected.count
        selected.append(contentsOf: tomorrowPlaces.prefix(max(0, min(5, remaining))))

        let finalRemaining = 20 - selected.count
        if finalRemaining > 0 {
            let existingIDs = Set(selected.map(\.id))
            let others = trip.days.flatMap(\.places)
                .filter { !$0.isVisited && !existingIDs.contains($0.id) }
                .prefix(finalRemaining)
            selected.append(contentsOf: others)
        }

        for place in selected {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                radius: 150,
                identifier: place.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
            monitoredPlaceIDs.insert(place.id.uuidString)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let context = modelContext else { return }
        let placeID = region.identifier

        let descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.id.uuidString == placeID })
        guard let place = try? context.fetch(descriptor).first else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(place.name)"
        content.body = "Вы рядом с запланированным местом!"
        if !place.notes.isEmpty {
            content.body += "\n\(place.notes)"
        }
        content.sound = .default
        content.categoryIdentifier = "geofence"
        content.userInfo = ["placeID": placeID]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "geofence-\(placeID)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)

        if UserDefaults.standard.bool(forKey: "geofence_automark_visited") {
            place.isVisited = true
            try? context.save()
        }
    }
}
