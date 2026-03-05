import SwiftUI

struct DashboardFlightTrackingSection: View {
    let trip: Trip

    @State private var flightData: FlightData?
    private let flightService = AviationStackService.shared
    private let estimatedFlightHours: Double = 10

    var body: some View {
        if trip.flightNumber != nil {
            NavigationLink(destination: FlightDetailView(trip: trip, flightData: flightData)) {
                flightCard
            }
            .buttonStyle(.plain)
            .task {
                if let num = trip.flightNumber {
                    flightData = await flightService.fetchFlight(number: num)
                }
            }
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

                if flightService.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
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
                Text(flightData?.flightIata ?? trip.flightNumber ?? "")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if let data = flightData, !data.airlineName.isEmpty {
                    Text(data.airlineName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
                statusBadge
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 14)

            // Delay badge
            if let data = flightData, data.isDelayed {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    if let dep = data.departureDelay, dep > 0 {
                        Text("Вылет +\(dep) мин")
                            .font(.system(size: 10, weight: .bold))
                    }
                    if let arr = data.arrivalDelay, arr > 0 {
                        Text("Прилёт +\(arr) мин")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Spacer()
                }
                .foregroundStyle(AppTheme.toriiRed)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 6)
            }

            // Route visualization
            routeVisualization
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 16)

            // City / airport names
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayOriginCity.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    if let data = flightData, !data.departureAirport.isEmpty {
                        Text(data.departureAirport)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayDestinationCity.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    if let data = flightData, !data.arrivalAirport.isEmpty {
                        Text(data.arrivalAirport)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 4)

            // Gate / Terminal info
            if let data = flightData {
                let hasGateInfo = data.departureGate != nil || data.departureTerminal != nil || data.arrivalGate != nil || data.arrivalTerminal != nil
                if hasGateInfo {
                    Rectangle()
                        .fill(AppTheme.oceanBlue.opacity(0.12))
                        .frame(height: 0.5)
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.top, 10)

                    HStack(spacing: 16) {
                        if let terminal = data.departureTerminal {
                            infoChip(label: "Терминал", value: terminal)
                        }
                        if let gate = data.departureGate {
                            infoChip(label: "Гейт", value: gate)
                        }
                        if let arrTerminal = data.arrivalTerminal {
                            infoChip(label: "Терм. приб.", value: arrTerminal)
                        }
                        if let arrGate = data.arrivalGate {
                            infoChip(label: "Гейт приб.", value: arrGate)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.top, 8)
                }
            }

            // Time
            if let depTime = flightData?.departureEstimated ?? flightData?.departureTime {
                HStack(spacing: 12) {
                    Text(flightTimeFormatted(depTime))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                    if let arrTime = flightData?.arrivalEstimated ?? flightData?.arrivalTime {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                        Text(flightTimeFormatted(arrTime))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 8)
            } else if let flight = trip.flightDate {
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

    // MARK: - Info Chip

    private func infoChip(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(currentStatusLabel)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(currentStatusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(currentStatusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var currentStatusLabel: String {
        if let data = flightData {
            return data.statusLocalized
        }
        return flightStatus.label
    }

    private var currentStatusColor: Color {
        if let data = flightData {
            switch data.status {
            case "active": return AppTheme.oceanBlue
            case "landed": return AppTheme.textSecondary
            case "cancelled": return AppTheme.toriiRed
            case "diverted": return AppTheme.templeGold
            default: return AppTheme.bambooGreen
            }
        }
        return flightStatus.color
    }

    // MARK: - Route Visualization

    private var routeVisualization: some View {
        HStack(spacing: 0) {
            Text(displayOriginCode)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                let width = geo.size.width
                let progress = flightProgress

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AppTheme.oceanBlue.opacity(0.15))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)

                    if progress > 0 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppTheme.oceanBlue)
                            .frame(width: width * progress, height: 2)
                    }

                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { i in
                            Spacer()
                            Circle()
                                .fill(AppTheme.oceanBlue.opacity(0.2))
                                .frame(width: 3, height: 3)
                            if i == 4 { Spacer() }
                        }
                    }

                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .offset(x: width * progress - 7)
                }
            }
            .frame(height: 20)

            Text(displayDestinationCode)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Flight Status (fallback)

    private enum FlightStatusType {
        case scheduled
        case inFlight
        case landed

        var label: String {
            switch self {
            case .scheduled: return String(localized: "По расписанию")
            case .inFlight: return String(localized: "В воздухе")
            case .landed: return String(localized: "Прилетел")
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
        if let data = flightData {
            switch data.status {
            case "landed": return 1.0
            case "active":
                if let dep = data.departureEstimated ?? data.departureTime,
                   let arr = data.arrivalEstimated ?? data.arrivalTime {
                    let total = arr.timeIntervalSince(dep)
                    let elapsed = Date().timeIntervalSince(dep)
                    guard total > 0 else { return 0.5 }
                    return min(max(elapsed / total, 0.05), 0.95)
                }
                return 0.5
            default: return 0
            }
        }
        guard let flight = trip.flightDate else { return 0 }
        let now = Date()
        if now < flight { return 0 }
        let duration = estimatedFlightHours * 3600
        let elapsed = now.timeIntervalSince(flight)
        return min(max(elapsed / duration, 0), 1)
    }

    // MARK: - Display Helpers

    private var displayOriginCode: String {
        if let data = flightData, !data.departureIata.isEmpty {
            return data.departureIata
        }
        return String(originCity.prefix(3)).uppercased()
    }

    private var displayDestinationCode: String {
        if let data = flightData, !data.arrivalIata.isEmpty {
            return data.arrivalIata
        }
        return String(trip.destination.prefix(3)).uppercased()
    }

    private var displayOriginCity: String {
        if let data = flightData, !data.departureIata.isEmpty {
            return data.departureIata
        }
        return originCity
    }

    private var displayDestinationCity: String {
        if let data = flightData, !data.arrivalIata.isEmpty {
            return data.arrivalIata
        }
        return trip.destination
    }

    private var originCity: String {
        trip.days
            .sorted { $0.date < $1.date }
            .first?.cityName ?? String(localized: "Город")
    }

    private func flightTimeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm, d MMM"
        return f.string(from: date)
    }
}
