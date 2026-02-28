import SwiftUI
import Combine

struct EventCard: View {
    let event: TripEvent
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            // Icon circle
            Image(systemName: event.category.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [event.category.color, event.category.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .overlay {
                    if event.isOngoing {
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                            .stroke(event.category.color, lineWidth: 2)
                            .opacity(pulseOpacity)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                // Time range + status
                HStack {
                    Text(event.formattedTimeRange)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(event.category.color)

                    Spacer()

                    Text(event.formattedDuration)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)

                    statusBadge
                }

                // Title
                Text(event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                if !event.subtitle.isEmpty {
                    Text(event.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Progress bar for ongoing events
                if event.isOngoing {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.thinMaterial)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(event.category.color)
                                .frame(width: geo.size.width * event.progress)
                        }
                    }
                    .frame(height: 4)

                    if let remaining = event.timeUntilEnd {
                        Text(formatRemaining(remaining))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
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
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(AppTheme.spacingS)
        .background(event.isOngoing ? event.category.color.opacity(0.06) : .clear)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(
                    event.isOngoing ? event.category.color.opacity(0.4) : Color.white.opacity(0.15),
                    lineWidth: event.isOngoing ? 1 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var pulseOpacity: Double {
        let interval = now.timeIntervalSince1970
        return 0.3 + 0.7 * sin(interval * 2)
    }

    private var statusBadge: some View {
        Group {
            if event.isOngoing {
                Text("СЕЙЧАС")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(.white)
                    .background(event.category.color)
                    .clipShape(Capsule())
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
