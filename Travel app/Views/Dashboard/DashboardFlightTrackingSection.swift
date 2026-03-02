import SwiftUI

struct DashboardFlightTrackingSection: View {
    let trip: Trip

    private let estimatedFlightHours: Double = 10

    var body: some View {
        if trip.flightNumber != nil {
            flightCard
        }
    }

    // MARK: - Main Card

    private var flightCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.oceanBlue)
                Text("ИНФОРМАЦИЯ О РЕЙСЕ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.oceanBlue)
                Spacer()
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Divider
            Rectangle()
                .fill(AppTheme.oceanBlue.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, AppTheme.spacingM)

            // Flight number + status badge
            HStack {
                Text(trip.flightNumber ?? "")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                statusBadge
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 14)

            // Route visualization
            routeVisualization
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 16)

            // City names
            HStack {
                Text(originCity.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(trip.destination.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 4)

            // Time
            if let flight = trip.flightDate {
                HStack {
                    Text(flightTimeFormatted(flight))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 8)
            }

            Spacer().frame(height: 16)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.oceanBlue.opacity(0.4), AppTheme.oceanBlue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.oceanBlue.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(flightStatus.label)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(flightStatus.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(flightStatus.color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Route Visualization

    private var routeVisualization: some View {
        HStack(spacing: 0) {
            // Origin code
            Text(originCode)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .leading)

            // Route line with airplane
            GeometryReader { geo in
                let width = geo.size.width
                let progress = flightProgress

                ZStack(alignment: .leading) {
                    // Track line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AppTheme.oceanBlue.opacity(0.15))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)

                    // Traveled line
                    if progress > 0 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppTheme.oceanBlue)
                            .frame(width: width * progress, height: 2)
                    }

                    // Dashes on the track
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { i in
                            Spacer()
                            Circle()
                                .fill(AppTheme.oceanBlue.opacity(0.2))
                                .frame(width: 3, height: 3)
                            if i == 4 { Spacer() }
                        }
                    }

                    // Airplane icon
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .offset(x: width * progress - 7)
                }
            }
            .frame(height: 20)

            // Destination code
            Text(destinationCode)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Flight Status

    private enum FlightStatusType {
        case scheduled
        case inFlight
        case landed

        var label: String {
            switch self {
            case .scheduled: return "По расписанию"
            case .inFlight: return "В воздухе"
            case .landed: return "Прилетел"
            }
        }

        var color: Color {
            switch self {
            case .scheduled: return AppTheme.bambooGreen
            case .inFlight: return AppTheme.oceanBlue
            case .landed: return AppTheme.textSecondary
            }
        }
    }

    private var flightStatus: FlightStatusType {
        guard let flight = trip.flightDate else { return .scheduled }
        let now = Date()
        if now < flight { return .scheduled }
        let landing = flight.addingTimeInterval(estimatedFlightHours * 3600)
        if now < landing { return .inFlight }
        return .landed
    }

    private var flightProgress: Double {
        guard let flight = trip.flightDate else { return 0 }
        let now = Date()
        if now < flight { return 0 }
        let duration = estimatedFlightHours * 3600
        let elapsed = now.timeIntervalSince(flight)
        return min(max(elapsed / duration, 0), 1)
    }

    // MARK: - Helpers

    private var originCity: String {
        trip.days
            .sorted { $0.date < $1.date }
            .first?.cityName ?? "Город"
    }

    private var originCode: String {
        String(originCity.prefix(3)).uppercased()
    }

    private var destinationCode: String {
        String(trip.destination.prefix(3)).uppercased()
    }

    private func flightTimeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm, d MMM"
        return f.string(from: date)
    }
}
