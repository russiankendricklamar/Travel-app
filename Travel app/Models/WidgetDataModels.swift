import Foundation

// Shared between main app and widget extension
// Must be added to BOTH target memberships in Xcode

struct WidgetTripData: Codable {
    let id: String
    let name: String
    let destination: String
    let startDate: Date
    let endDate: Date
    let flightDate: Date?
    let isActive: Bool
    let isUpcoming: Bool
    let totalDays: Int
    let currentDay: Int
    let nextEvent: WidgetEventData?
    let palette: String
}

struct WidgetEventData: Codable {
    let title: String
    let categoryIcon: String
    let startTime: Date
    let endTime: Date
}
