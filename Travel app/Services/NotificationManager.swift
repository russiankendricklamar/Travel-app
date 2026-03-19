import Foundation
import UserNotifications
import CoreLocation

@Observable
final class NotificationManager {
    static let shared = NotificationManager()
    var isAuthorized = false

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
        }
    }

    func registerGeofenceCategory() {
        let markAction = UNNotificationAction(
            identifier: "MARK_VISITED",
            title: "Отметить посещённым",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "geofence",
            actions: [markAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Morning Plan (daily at 8:00 during trip)

    func scheduleMorningPlans(for trip: Trip) {
        cancelCategory("morning")
        let timeMinutes = UserDefaults.standard.integer(forKey: "notif_morning_time")
        let hour = timeMinutes > 0 ? timeMinutes / 60 : 8
        let minute = timeMinutes > 0 ? timeMinutes % 60 : 0
        for day in trip.sortedDays {
            var cal = Calendar.current
            if let tz = day.resolvedTimeZone { cal.timeZone = tz }
            var comps = cal.dateComponents([.year, .month, .day], from: day.date)
            comps.hour = hour; comps.minute = minute
            comps.timeZone = day.resolvedTimeZone ?? .current
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = "Доброе утро!"
            content.body = "Сегодня: \(day.title) в \(day.cityName)"
            content.sound = .default
            content.categoryIdentifier = "morning"
            let request = UNNotificationRequest(identifier: "morning-\(day.id)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Event Reminders (multiple lead times)

    private var eventLeadMinutes: [Int] {
        let str = UserDefaults.standard.string(forKey: "notif_event_leads") ?? "30"
        return str.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 > 0 }
    }

    private func formatLeadBody(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h > 0 && m > 0 { return "\(h) ч \(m) мин" }
        if h > 0 { return "\(h) ч" }
        return "\(m) мин"
    }

    func scheduleEventReminder(for event: TripEvent) {
        let leads = eventLeadMinutes
        guard !leads.isEmpty else { return }

        var cal = Calendar.current
        if let tz = event.day?.resolvedTimeZone {
            cal.timeZone = tz
        }

        for lead in leads {
            let reminderDate = event.startTime.addingTimeInterval(-Double(lead) * 60)
            guard reminderDate > Date() else { continue }

            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            comps.timeZone = event.day?.resolvedTimeZone ?? .current

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = event.category.rawValue
            content.body = "\(event.title) через \(formatLeadBody(lead))"
            content.sound = .default
            content.categoryIdentifier = "event"
            let request = UNNotificationRequest(identifier: "event-\(event.id)-\(lead)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func scheduleAllEventReminders(for trip: Trip) {
        cancelCategory("event")
        for day in trip.days {
            for event in day.events {
                scheduleEventReminder(for: event)
            }
        }
    }

    // MARK: - Budget Alert

    func checkBudgetAlert(for trip: Trip) {
        guard trip.budgetUsedPercent > 0.8 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Внимание: бюджет!"
        let percent = Int(trip.budgetUsedPercent * 100)
        content.body = "Использовано \(percent)% бюджета"
        content.sound = .default
        content.categoryIdentifier = "budget"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "budget-alert", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weather Notifications

    func scheduleWeatherNotifications(for trip: Trip) async {
        cancelCategory("weather")

        let weatherService = WeatherService.shared
        let coordinate: CLLocationCoordinate2D
        if let firstPlace = trip.sortedDays.first?.places.first {
            coordinate = firstPlace.coordinate
        } else {
            return
        }

        await weatherService.fetchWeather(for: coordinate)

        let wMorning = UserDefaults.standard.integer(forKey: "notif_weather_morning_time")
        let wMorningH = wMorning > 0 ? wMorning / 60 : 8
        let wMorningM = wMorning > 0 ? wMorning % 60 : 0
        let wEvening = UserDefaults.standard.integer(forKey: "notif_weather_evening_time")
        let wEveningH = wEvening > 0 ? wEvening / 60 : 21
        let wEveningM = wEvening > 0 ? wEvening % 60 : 0

        for day in trip.sortedDays {
            var cal = Calendar.current
            if let tz = day.resolvedTimeZone { cal.timeZone = tz }
            let dayTZ = day.resolvedTimeZone ?? .current

            // Morning — today's weather
            if let summary = weatherService.notificationSummary(for: day.date) {
                var morningComps = cal.dateComponents([.year, .month, .day], from: day.date)
                morningComps.hour = wMorningH
                morningComps.minute = wMorningM
                morningComps.timeZone = dayTZ
                let content = UNMutableNotificationContent()
                content.title = "Погода сегодня"
                content.body = "\(day.cityName): \(summary)"
                content.sound = .default
                content.categoryIdentifier = "weather"
                let trigger = UNCalendarNotificationTrigger(dateMatching: morningComps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "weather-morning-\(day.id)",
                    content: content,
                    trigger: trigger
                )
                try? await UNUserNotificationCenter.current().add(request)
            }

            // Evening 21:00 — tomorrow's weather
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: day.date),
               let summary = weatherService.notificationSummary(for: tomorrow) {
                var eveningComps = cal.dateComponents([.year, .month, .day], from: day.date)
                eveningComps.hour = wEveningH
                eveningComps.minute = wEveningM
                eveningComps.timeZone = dayTZ
                let content = UNMutableNotificationContent()
                content.title = "Погода завтра"
                content.body = "\(day.cityName): \(summary)"
                content.sound = .default
                content.categoryIdentifier = "weather"
                let trigger = UNCalendarNotificationTrigger(dateMatching: eveningComps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "weather-evening-\(day.id)",
                    content: content,
                    trigger: trigger
                )
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Weather Alert Notifications

    func scheduleWeatherAlertNotifications(for trip: Trip) async {
        cancelCategory("weather-alert")

        let weatherService = WeatherService.shared

        // Collect unique coordinates from trip
        var seenKeys = Set<String>()
        var coordinates: [(String, CLLocationCoordinate2D)] = []

        for day in trip.sortedDays {
            let city = day.cityName
            guard !city.isEmpty, !seenKeys.contains(city) else { continue }
            seenKeys.insert(city)
            if let place = day.places.first {
                coordinates.append((city, place.coordinate))
            }
        }

        for (city, coord) in coordinates {
            // Fetch fresh data to get alerts
            _ = await weatherService.fetchCurrentWeather(for: coord)
            let alerts = weatherService.weatherAlerts(at: coord)

            for alert in alerts {
                let content = UNMutableNotificationContent()
                content.title = alert.isSevere ? "Опасная погода" : "Погодное предупреждение"
                content.body = "\(city): \(alert.event ?? alert.headline ?? "Внимание")"
                if let desc = alert.desc {
                    content.body += "\n\(String(desc.prefix(100)))"
                }
                content.sound = alert.isSevere ? .defaultCritical : .default
                content.categoryIdentifier = "weather-alert"

                // Send immediately (alerts are time-sensitive)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let id = "weather-alert-\(city)-\(alert.id.hashValue)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Schedule All

    func scheduleAll(for trip: Trip) async {
        scheduleMorningPlans(for: trip)
        scheduleAllEventReminders(for: trip)
        await scheduleWeatherNotifications(for: trip)
        await scheduleWeatherAlertNotifications(for: trip)
    }

    // MARK: - Cancel

    func cancelCategory(_ category: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.content.categoryIdentifier == category }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
