import ActivityKit
import Foundation
import SwiftUI

@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    @ObservationIgnored
    @AppStorage("liveActivityEnabled") var isEnabled: Bool = true

    private var currentActivity: Activity<TravelActivityAttributes>?
    private var updateTimer: Timer?
    private var currentEvent: TripEvent?
    private var allEvents: [TripEvent] = []

    private init() {}

    // MARK: - Public API

    func refreshActivities(trip: Trip) {
        guard isEnabled else {
            endAllActivities()
            return
        }

        let now = Date()
        let todayEvents = trip.sortedDays
            .first { Calendar.current.isDateInToday($0.date) }?
            .events
            .sorted { $0.startTime < $1.startTime } ?? []

        allEvents = todayEvents

        // Find ongoing event or nearest upcoming event within 1 hour
        if let ongoing = todayEvents.first(where: { $0.isOngoing }) {
            startOrUpdateActivity(for: ongoing)
        } else if let upcoming = todayEvents.first(where: {
            $0.isFuture && ($0.timeUntilStart ?? .infinity) <= 3600
        }) {
            startOrUpdateActivity(for: upcoming)
        } else {
            endAllActivities()
        }
    }

    func endAllActivities() {
        stopTimer()
        Task {
            for activity in Activity<TravelActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
        currentEvent = nil
    }

    // MARK: - Activity Lifecycle

    private func startOrUpdateActivity(for event: TripEvent) {
        if currentEvent?.id == event.id, currentActivity != nil {
            updateCurrentActivity()
            return
        }

        endAllActivities()
        currentEvent = event
        startActivity(for: event)
    }

    private func startActivity(for event: TripEvent) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TravelActivityAttributes(
            eventTitle: event.title,
            eventSubtitle: event.subtitle,
            categoryRawValue: event.category.rawValue,
            categoryIcon: event.category.systemImage,
            startTime: event.startTime,
            endTime: event.endTime
        )

        let state = TravelActivityAttributes.ContentState(
            progress: event.progress,
            isOngoing: event.isOngoing,
            secondsRemaining: max(0, Int(event.endTime.timeIntervalSince(Date())))
        )

        let content = ActivityContent(state: state, staleDate: event.endTime)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            startTimer()
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    private func updateCurrentActivity() {
        guard let activity = currentActivity, let event = currentEvent else { return }

        let now = Date()

        // Event finished — chain to next
        if now > event.endTime {
            chainToNextEvent()
            return
        }

        let state = TravelActivityAttributes.ContentState(
            progress: event.progress,
            isOngoing: event.isOngoing,
            secondsRemaining: max(0, Int(event.endTime.timeIntervalSince(now)))
        )

        let content = ActivityContent(state: state, staleDate: event.endTime)

        Task {
            await activity.update(content)
        }
    }

    // MARK: - Auto-Chain

    private func chainToNextEvent() {
        guard let current = currentEvent else {
            endAllActivities()
            return
        }

        let nextEvents = allEvents.filter { $0.startTime > current.endTime && !$0.isPast }

        if let next = nextEvents.first, (next.timeUntilStart ?? .infinity) <= 3600 {
            startOrUpdateActivity(for: next)
        } else {
            endAllActivities()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateCurrentActivity()
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
