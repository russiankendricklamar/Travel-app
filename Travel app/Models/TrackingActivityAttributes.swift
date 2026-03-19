import ActivityKit
import Foundation

struct TrackingActivityAttributes: ActivityAttributes {
    let dayLabel: String
    let tripName: String
    let startedAt: Date

    struct ContentState: Codable, Hashable {
        let pointCount: Int
        let distanceMeters: Double
        let elapsedSeconds: Int
    }
}
