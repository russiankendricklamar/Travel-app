import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct TripTimelineProvider: TimelineProvider {
    private let suiteName = "group.ru.travel.Travel-app"

    func placeholder(in context: Context) -> TripTimelineEntry {
        TripTimelineEntry(date: Date(), trip: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TripTimelineEntry) -> Void) {
        let trip = readTripData()
        completion(TripTimelineEntry(date: Date(), trip: trip))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripTimelineEntry>) -> Void) {
        let trip = readTripData()
        let entry = TripTimelineEntry(date: Date(), trip: trip)
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readTripData() -> WidgetTripData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "widgetTripData") else { return nil }
        return try? JSONDecoder().decode(WidgetTripData.self, from: data)
    }
}

// MARK: - Timeline Entry

struct TripTimelineEntry: TimelineEntry {
    let date: Date
    let trip: WidgetTripData?
}

// MARK: - Countdown Widget

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripTimelineProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Обратный отсчёт")
        .description("Дни до поездки и следующее событие")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View

struct CountdownWidgetView: View {
    let entry: TripTimelineEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let trip = entry.trip {
                switch family {
                case .systemSmall:
                    smallWidget(trip: trip)
                default:
                    mediumWidget(trip: trip)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            if let trip = entry.trip {
                let palette = WidgetPalette.from(name: trip.palette)
                LinearGradient(
                    colors: palette.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(widgetHex: "FFF5F8"), Color(widgetHex: "FDF2F8")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Small Widget

    private func smallWidget(trip: WidgetTripData) -> some View {
        let palette = WidgetPalette.from(name: trip.palette)
        let textColor: Color = palette.isDark ? .white : Color(widgetHex: "1A1A2E")

        return VStack(spacing: 8) {
            if trip.isActive {
                // Active: show day X of Y
                Text("ДЕНЬ \(trip.currentDay)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(palette.accentColor)

                Text("\(trip.currentDay)/\(trip.totalDays)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                // Pre-trip countdown
                let days = countdownDays(to: trip.flightDate ?? trip.startDate)

                Text("\(days)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(daysWord(days).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(palette.accentColor)
            }

            Text(trip.destination.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(textColor.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium Widget

    private func mediumWidget(trip: WidgetTripData) -> some View {
        let palette = WidgetPalette.from(name: trip.palette)
        let textColor: Color = palette.isDark ? .white : Color(widgetHex: "1A1A2E")
        let secondaryColor = textColor.opacity(0.6)

        return HStack(spacing: 16) {
            // Left: countdown
            VStack(spacing: 4) {
                if trip.isActive {
                    Text("ДЕНЬ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(palette.accentColor)
                    Text("\(trip.currentDay)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(0.6)
                    Text("из \(trip.totalDays)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryColor)
                } else {
                    let days = countdownDays(to: trip.flightDate ?? trip.startDate)
                    Text("\(days)")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(0.5)
                    Text(daysWord(days).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(palette.accentColor)
                }
            }
            .frame(width: 80)

            // Divider
            RoundedRectangle(cornerRadius: 1)
                .fill(textColor.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 8)

            // Right: trip info
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.destination.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(palette.accentColor)
                    .lineLimit(1)

                // Dates
                Text(formatDateRange(start: trip.startDate, end: trip.endDate))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Next event or trip status
                if trip.isActive, let event = trip.nextEvent {
                    HStack(spacing: 6) {
                        Image(systemName: event.categoryIcon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textColor)
                                .lineLimit(1)
                            Text(formatTime(event.startTime))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(secondaryColor)
                        }
                    }
                } else if trip.isUpcoming {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.accentColor)
                        Text(trip.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color(widgetHex: "EC4899").opacity(0.5))
            Text("Нет поездок")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func countdownDays(to date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "d MMM"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
