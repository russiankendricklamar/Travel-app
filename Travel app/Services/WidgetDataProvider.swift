import Foundation
import WidgetKit

enum WidgetDataProvider {
    private static let suiteName = "group.ru.travel.Travel-app"
    private static let tripDataKey = "widgetTripData"

    static func updateWidgetData(trips: [Trip]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        // Find the most relevant trip: active first, then upcoming (nearest)
        let active = trips.first { $0.isActive }
        let upcoming = trips
            .filter { $0.isUpcoming }
            .sorted { $0.startDate < $1.startDate }
            .first

        let trip = active ?? upcoming

        guard let trip else {
            defaults.removeObject(forKey: tripDataKey)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        // Find next event for active trips
        var nextEvent: WidgetEventData?
        if trip.isActive, let today = trip.todayDay {
            let now = Date()
            let upcoming = today.events
                .sorted { $0.startTime < $1.startTime }
                .first { $0.endTime > now }

            if let event = upcoming {
                nextEvent = WidgetEventData(
                    title: event.title,
                    categoryIcon: event.category.systemImage,
                    startTime: event.startTime,
                    endTime: event.endTime
                )
            }
        }

        let palette = UserDefaults.standard.string(forKey: "colorPalette") ?? "sakura"

        let data = WidgetTripData(
            id: trip.id.uuidString,
            name: trip.name,
            destination: trip.countriesDisplay,
            startDate: trip.startDate,
            endDate: trip.endDate,
            flightDate: trip.flightDate,
            isActive: trip.isActive,
            isUpcoming: trip.isUpcoming,
            totalDays: trip.totalDays,
            currentDay: trip.currentDay,
            nextEvent: nextEvent,
            palette: palette
        )

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: tripDataKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readTripData() -> WidgetTripData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: tripDataKey) else { return nil }
        return try? JSONDecoder().decode(WidgetTripData.self, from: data)
    }
}
