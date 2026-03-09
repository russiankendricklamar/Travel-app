import SwiftUI

struct DashboardTodayScheduleSection: View {
    let trip: Trip

    private var today: TripDay? {
        trip.todayDay
    }

    private var todayEvents: [TripEvent] {
        guard let today else { return [] }
        return today.sortedEvents
    }

    private var todayPlaces: [Place] {
        guard let today else { return [] }
        return today.sortedPlaces
    }

    var body: some View {
        if let today, (!todayEvents.isEmpty || !todayPlaces.isEmpty) {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 4, height: 16)
                        Text("СЕГОДНЯ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                    Spacer()
                    Text(today.cityName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }

                // Events timeline
                if !todayEvents.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(todayEvents.enumerated()), id: \.element.id) { index, event in
                            compactEventRow(event: event)

                            if index < todayEvents.count - 1 {
                                timelineConnector
                            }
                        }
                    }
                    .padding(AppTheme.spacingS)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                            .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
                    )
                }

                // Places
                if !todayPlaces.isEmpty {
                    placesCard
                }
            }
        }
    }

    // MARK: - Compact Event Row

    private func compactEventRow(event: TripEvent) -> some View {
        HStack(spacing: 10) {
            // Time column
            VStack(spacing: 2) {
                Text(formattedTime(event.startTime))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(event.isOngoing ? event.category.color : .primary)
                Text(formattedTime(event.endTime))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 44)

            // Icon
            Image(systemName: event.category.systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(
                        colors: [event.category.color, event.category.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if event.isOngoing {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(event.category.color, lineWidth: 1.5)
                    }
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !event.subtitle.isEmpty {
                    Text(event.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status
            eventStatus(event)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(event.isOngoing ? event.category.color.opacity(0.06) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func eventStatus(_ event: TripEvent) -> some View {
        if event.isOngoing {
            Text("СЕЙЧАС")
                .font(.system(size: 7, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(event.category.color)
                .clipShape(Capsule())
        } else if event.isPast {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.bambooGreen)
        } else if let until = event.timeUntilStart, until < 3600 {
            Text("через \(formatMinutes(until))")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(event.category.color)
        }
    }

    // MARK: - Timeline Connector

    private var timelineConnector: some View {
        HStack {
            Spacer().frame(width: 44)
            Rectangle()
                .fill(AppTheme.sakuraPink.opacity(0.15))
                .frame(width: 1.5, height: 12)
                .padding(.leading, 14)
            Spacer()
        }
    }

    // MARK: - Places Card

    private var placesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
                Text("МЕСТА НА СЕГОДНЯ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(todayPlaces.filter(\.isVisited).count)/\(todayPlaces.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
            }

            ForEach(todayPlaces) { place in
                compactPlaceRow(place: place)
            }
        }
        .padding(AppTheme.spacingS)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func compactPlaceRow(place: Place) -> some View {
        HStack(spacing: 10) {
            Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(place.isVisited ? AppTheme.bambooGreen : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(place.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(place.isVisited ? .secondary : .primary)
                    .strikethrough(place.isVisited)
                    .lineLimit(1)
                if !place.timeToSpend.isEmpty {
                    Text(place.timeToSpend)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: place.category.systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.categoryColor(for: place.category.rawValue).opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Formatting

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins > 0 ? "\(hours)ч \(mins)мин" : "\(hours)ч"
        }
        return "\(totalMinutes)мин"
    }
}
