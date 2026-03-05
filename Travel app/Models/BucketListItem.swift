import Foundation
import SwiftData

@Model
final class BucketListItem: Syncable {
    @Attribute(.unique) var id: UUID
    var name: String
    var destination: String
    var category: String
    var notes: String
    var latitude: Double?
    var longitude: Double?
    var dateAdded: Date
    var isConverted: Bool
    @Attribute(.externalStorage) var photoData: Data?
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var photoStoragePath: String?

    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        category: String = PlaceCategory.culture.rawValue,
        notes: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        dateAdded: Date = Date(),
        isConverted: Bool = false,
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.category = category
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.dateAdded = dateAdded
        self.isConverted = isConverted
        self.photoData = photoData
    }
}
