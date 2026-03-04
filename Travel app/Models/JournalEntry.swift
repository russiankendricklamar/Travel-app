import Foundation
import SwiftUI
import SwiftData

@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var text: String
    var mood: String
    var timestamp: Date
    var isStandalone: Bool
    var latitude: Double?
    var longitude: Double?

    var place: Place?
    var day: TripDay?

    @Relationship(deleteRule: .cascade, inverse: \TripPhoto.journalEntry)
    var photos: [TripPhoto] = []

    init(
        id: UUID = UUID(),
        text: String,
        mood: String = JournalMood.good.rawValue,
        timestamp: Date = Date(),
        isStandalone: Bool = true,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.mood = mood
        self.timestamp = timestamp
        self.isStandalone = isStandalone
        self.latitude = latitude
        self.longitude = longitude
    }

    var journalMood: JournalMood {
        get { JournalMood(rawValue: mood) ?? .good }
        set { mood = newValue.rawValue }
    }
}

enum JournalMood: String, CaseIterable, Codable {
    case great, good, neutral, tired, bad

    var emoji: String {
        switch self {
        case .great: return "🌸"
        case .good: return "😊"
        case .neutral: return "😐"
        case .tired: return "😴"
        case .bad: return "😔"
        }
    }

    var label: String {
        switch self {
        case .great: return "Отлично"
        case .good: return "Хорошо"
        case .neutral: return "Нормально"
        case .tired: return "Устал"
        case .bad: return "Плохо"
        }
    }

    var color: Color {
        switch self {
        case .great: return AppTheme.sakuraPink
        case .good: return AppTheme.bambooGreen
        case .neutral: return AppTheme.templeGold
        case .tired: return AppTheme.oceanBlue
        case .bad: return AppTheme.toriiRed
        }
    }
}
