import ActivityKit
import Foundation

struct TravelActivityAttributes: ActivityAttributes {
    let eventTitle: String
    let eventSubtitle: String
    let categoryRawValue: String
    let categoryIcon: String
    let startTime: Date
    let endTime: Date

    struct ContentState: Codable, Hashable {
        let progress: Double
        let isOngoing: Bool
        let secondsRemaining: Int
    }
}
