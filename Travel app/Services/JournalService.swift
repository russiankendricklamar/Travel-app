import Foundation
import SwiftData

enum JournalService {
    static func createStubEntry(for place: Place, in day: TripDay, context: ModelContext) {
        let entry = JournalEntry(
            text: "",
            mood: JournalMood.good.rawValue,
            timestamp: Date(),
            isStandalone: false,
            latitude: place.latitude,
            longitude: place.longitude
        )
        entry.place = place
        entry.day = day
        context.insert(entry)
        try? context.save()
    }

    static func exportSummary(for trip: Trip) -> String {
        var lines: [String] = ["# \(trip.name)\n"]
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM"
        for day in trip.sortedDays {
            lines.append("## \(df.string(from: day.date)) — \(day.cityName)")
            for entry in day.journalEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
                let mood = entry.journalMood
                lines.append("\(mood.emoji) \(entry.text)")
                if let place = entry.place {
                    lines.append("  📍 \(place.name)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
