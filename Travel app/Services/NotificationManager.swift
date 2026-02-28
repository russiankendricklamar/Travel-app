import Foundation
import UserNotifications
import CoreLocation

@Observable
final class NotificationManager {
    static let shared = NotificationManager()
    var isAuthorized = false

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

    // MARK: - Morning Plan (daily at 8:00 during trip)

    func scheduleMorningPlans(for trip: Trip) {
        cancelCategory("morning")
        let timeMinutes = UserDefaults.standard.integer(forKey: "notif_morning_time")
        let hour = timeMinutes > 0 ? timeMinutes / 60 : 8
        let minute = timeMinutes > 0 ? timeMinutes % 60 : 0
        for day in trip.sortedDays {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
            comps.hour = hour; comps.minute = minute
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

    // MARK: - Event Reminders (30 min before)

    func scheduleEventReminder(for event: TripEvent) {
        let leadMins = UserDefaults.standard.integer(forKey: "notif_event_lead")
        let reminderDate = event.startTime.addingTimeInterval(-Double(leadMins > 0 ? leadMins : 30) * 60)
        guard reminderDate > Date() else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = event.category.rawValue
        content.body = "\(event.title) через 30 минут"
        content.sound = .default
        content.categoryIdentifier = "event"
        let request = UNNotificationRequest(identifier: "event-\(event.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
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
            coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        }

        await weatherService.fetchWeather(for: coordinate)

        let wMorning = UserDefaults.standard.integer(forKey: "notif_weather_morning_time")
        let wMorningH = wMorning > 0 ? wMorning / 60 : 8
        let wMorningM = wMorning > 0 ? wMorning % 60 : 0
        let wEvening = UserDefaults.standard.integer(forKey: "notif_weather_evening_time")
        let wEveningH = wEvening > 0 ? wEvening / 60 : 21
        let wEveningM = wEvening > 0 ? wEvening % 60 : 0

        for day in trip.sortedDays {
            // Morning — today's weather
            if let summary = weatherService.notificationSummary(for: day.date) {
                var morningComps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
                morningComps.hour = wMorningH
                morningComps.minute = wMorningM
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
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day.date),
               let summary = weatherService.notificationSummary(for: tomorrow) {
                var eveningComps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
                eveningComps.hour = wEveningH
                eveningComps.minute = wEveningM
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

    // MARK: - Schedule All

    func scheduleAll(for trip: Trip) async {
        scheduleMorningPlans(for: trip)
        scheduleAllEventReminders(for: trip)
        await scheduleWeatherNotifications(for: trip)
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
