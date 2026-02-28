import Foundation
import UserNotifications

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
        for day in trip.sortedDays {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
            comps.hour = 8; comps.minute = 0
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
        let reminderDate = event.startTime.addingTimeInterval(-30 * 60)
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

    // MARK: - Journal Reminder (daily at 21:00)

    func scheduleJournalReminders(for trip: Trip) {
        cancelCategory("journal")
        for day in trip.sortedDays {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
            comps.hour = 21; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = "Дневник"
            content.body = "Запишите впечатления о сегодняшнем дне"
            content.sound = .default
            content.categoryIdentifier = "journal"
            let request = UNNotificationRequest(identifier: "journal-\(day.id)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Schedule All

    func scheduleAll(for trip: Trip) {
        scheduleMorningPlans(for: trip)
        scheduleAllEventReminders(for: trip)
        scheduleJournalReminders(for: trip)
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
