import SwiftUI
import Combine

struct EventCard: View {
    let event: TripEvent
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Color bar + icon
            VStack(spacing: 0) {
                Rectangle()
                    .fill(event.category.color)
                    .frame(width: 48)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: event.category.systemImage)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                            if event.isOngoing {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                                    .opacity(pulseOpacity)
                            }
                        }
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                // Time range
                HStack {
                    Text(event.formattedTimeRange)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(event.category.color)

                    Rectangle()
                        .fill(event.category.color.opacity(0.3))
                        .frame(height: 1)

                    Text(event.formattedDuration)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textMuted)

                    Spacer()

                    statusBadge
                }

                // Title
                Text(event.title.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.textPrimary)

                if !event.subtitle.isEmpty {
                    Text(event.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Progress bar for ongoing events
                if event.isOngoing {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.surface)
                            Rectangle()
                                .fill(event.category.color)
                                .frame(width: geo.size.width * event.progress)
                        }
                    }
                    .frame(height: 4)

                    if let remaining = event.timeUntilEnd {
                        Text(formatRemaining(remaining))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(event.category.color)
                    }
                }

                // Countdown to start for upcoming events
                if event.isFuture, let until = event.timeUntilStart, until < 3600 * 2 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .bold))
                        Text("Через \(formatRemaining(until))")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(event.category.color)
                }

                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(AppTheme.spacingS)
        }
        .background(event.isOngoing ? event.category.color.opacity(0.04) : AppTheme.card)
        .overlay(
            Rectangle().stroke(
                event.isOngoing ? event.category.color : AppTheme.border,
                lineWidth: event.isOngoing ? 2 : 1
            )
        )
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var pulseOpacity: Double {
        let interval = now.timeIntervalSince1970
        return 0.5 + 0.5 * sin(interval * 2)
    }

    private var statusBadge: some View {
        Group {
            if event.isOngoing {
                Text("СЕЙЧАС")
                    .font(.system(size: 8, weight: .black))
                    .tracking(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(event.category.color)
            } else if event.isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.bambooGreen)
            }
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)ч \(minutes)мин"
        }
        return "\(minutes)мин"
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let events = [
        TripEvent(
            id: UUID(), title: "Shinkansen Nozomi",
            subtitle: "Токио → Киото",
            category: .train,
            startTime: calendar.date(byAdding: .minute, value: -30, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: 1, to: now)!,
            notes: "Вагон 7, место 3A"
        ),
        TripEvent(
            id: UUID(), title: "Прилёт в Нариту",
            subtitle: "NRT → Токио",
            category: .flight,
            startTime: calendar.date(byAdding: .hour, value: 2, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: 3, to: now)!,
            notes: ""
        )
    ]

    VStack(spacing: 8) {
        ForEach(events) { event in
            EventCard(event: event)
        }
    }
    .padding()
    .background(AppTheme.background)
}
