import Foundation
import SwiftData

@Model
final class OfflineMapCache {
    @Attribute(.unique) var id: UUID
    var tripDayID: UUID
    @Attribute(.externalStorage) var snapshotData: Data
    var createdAt: Date
    var centerLatitude: Double
    var centerLongitude: Double

    init(
        id: UUID = UUID(),
        tripDayID: UUID,
        snapshotData: Data,
        createdAt: Date = Date(),
        centerLatitude: Double,
        centerLongitude: Double
    ) {
        self.id = id
        self.tripDayID = tripDayID
        self.snapshotData = snapshotData
        self.createdAt = createdAt
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
    }
}
