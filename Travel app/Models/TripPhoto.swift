import Foundation
import SwiftUI
import SwiftData

@Model
final class TripPhoto {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var caption: String
    var createdAt: Date

    var place: Place?
    var expense: Expense?
    var day: TripDay?
    var journalEntry: JournalEntry?

    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data? = nil,
        caption: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.caption = caption
        self.createdAt = createdAt
    }
}
