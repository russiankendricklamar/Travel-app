import SwiftUI

struct DashboardFlightTrackingSection: View {
    let trip: Trip
    var flights: [TripFlight]?

    private var displayFlights: [TripFlight] {
        flights ?? trip.flights
    }

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        if displayFlights.count == 1 {
            DashboardFlightCard(trip: trip, flight: displayFlights[0])
        } else if displayFlights.count > 1 {
            VStack(spacing: 10) {
                ZStack {
                    ForEach(Array(displayFlights.enumerated().reversed()), id: \.element.id) { index, flight in
                        let relativeIndex = index - currentIndex
                        if relativeIndex >= 0 && relativeIndex <= 2 {
                            DashboardFlightCard(trip: trip, flight: flight)
                                .scaleEffect(cardScale(for: relativeIndex))
                                .offset(y: cardOffset(for: relativeIndex))
                                .offset(x: relativeIndex == 0 ? dragOffset : 0)
                                .opacity(cardOpacity(for: relativeIndex))
                                .rotationEffect(.degrees(relativeIndex == 0 ? Double(dragOffset) / 20 : 0))
                                .zIndex(Double(displayFlights.count - relativeIndex))
                                .allowsHitTesting(relativeIndex == 0)
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                if value.translation.width < -threshold, currentIndex < displayFlights.count - 1 {
                                    currentIndex += 1
                                } else if value.translation.width > threshold, currentIndex > 0 {
                                    currentIndex -= 1
                                }
                                dragOffset = 0
                            }
                        }
                )

                // Page dots
                HStack(spacing: 6) {
                    ForEach(0..<displayFlights.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? AppTheme.oceanBlue : AppTheme.oceanBlue.opacity(0.25))
                            .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    }
                }
            }
        }
    }

    // MARK: - Card Stack Transforms

    private func cardScale(for relativeIndex: Int) -> CGFloat {
        1.0 - CGFloat(relativeIndex) * 0.05
    }

    private func cardOffset(for relativeIndex: Int) -> CGFloat {
        CGFloat(relativeIndex) * 10
    }

    private func cardOpacity(for relativeIndex: Int) -> Double {
        1.0 - Double(relativeIndex) * 0.2
    }
}

// MARK: - Single Flight Card

private struct DashboardFlightCard: View {
    let trip: Trip
    let flight: TripFlight

    @State private var flightData: FlightData?
    private let flightService = AirLabsService.shared

    var body: some View {
        NavigationLink(destination: FlightDetailView(trip: trip, flight: flight, flightData: flightData)) {
            flightCard
        }
        .buttonStyle(.plain)
        .task {
            let data = await flightService.fetchFlight(number: flight.number, date: flight.date)
            flightData = data
            if let data, flight.departureIata == nil {
                trip.updateFlightIata(flightID: flight.id, data: data)
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
                Text(flightData?.flightIata ?? flight.number)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if let data = flightData {
                    let displayName = data.airlineDisplayName
                    if !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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
                    if let duration = flightData?.durationFormatted {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .semibold))
                            Text(duration)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 8)
            } else if let flightDate = flight.date {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.oceanBlue.opacity(0.7))
                    Text(flightTimeFormatted(flightDate))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 8)
            }

            Spacer().frame(height: 16)
        }
        .frame(minHeight: 240)
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
        .shadow(color: AppTheme.oceanBlue.opacity(0.12), radius: 12, x: 0, y: 6)
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
        guard let flightDate = flight.date else { return .scheduled }
        let now = Date()
        if now < flightDate { return .scheduled }
        let landing = flightDate.addingTimeInterval(24 * 3600)
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
        return 0
    }

    // MARK: - Display Helpers

    private var displayOriginCode: String {
        if let data = flightData, !data.departureIata.isEmpty {
            return data.departureIata
        }
        return "···"
    }

    private var displayDestinationCode: String {
        if let data = flightData, !data.arrivalIata.isEmpty {
            return data.arrivalIata
        }
        return "···"
    }

    private var displayOriginCity: String {
        flightData?.departureCityName ?? ""
    }

    private var displayDestinationCity: String {
        flightData?.arrivalCityName ?? ""
    }

    private func flightTimeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm, d MMM"
        return f.string(from: date)
    }
}
