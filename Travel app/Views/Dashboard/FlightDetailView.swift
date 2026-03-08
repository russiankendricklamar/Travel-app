import SwiftUI
import MapKit
import CoreLocation

struct FlightDetailView: View {
    let trip: Trip
    let flight: TripFlight
    let flightData: FlightData?

    @State private var departureCoordinate: CLLocationCoordinate2D?
    @State private var arrivalCoordinate: CLLocationCoordinate2D?
    @State private var showEditSheet = false

    @State private var refreshedFlightData: FlightData?
    @State private var livePosition: LivePosition?
    @State private var transportRecommendation: AirportTransportRecommendation?
    @State private var isLoadingTransport = false
    @State private var resolvedOrigin: TransportOrigin?

    /// Origin for AI transport recommendation
    private enum TransportOrigin {
        case hotel(place: Place)
        case gps(address: String, coordinate: CLLocationCoordinate2D)

        var name: String {
            switch self {
            case .hotel(let place): return place.name
            case .gps: return "Текущее местоположение"
            }
        }
        var address: String {
            switch self {
            case .hotel(let place): return place.address
            case .gps(let addr, _): return addr
            }
        }
        var coordinate: CLLocationCoordinate2D? {
            switch self {
            case .hotel(let place): return place.coordinate
            case .gps(_, let coord): return coord
            }
        }
        var isGPS: Bool {
            if case .gps = self { return true }
            return false
        }
    }

    private var activeFlightData: FlightData? {
        refreshedFlightData ?? flightData
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                flightHeader
                routeSection
                mapSection
                liveInfoSection
                departureArrivalSection
                airportTransportSection
                relatedTicketsSection
            }
            .padding(AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .sakuraGradientBackground()
        .navigationTitle(activeFlightData?.flightIata ?? flight.number)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditFlightSheet(trip: trip)
        }
        .task {
            refreshedFlightData = await AirLabsService.shared.fetchFlight(
                number: flight.number, date: flight.date
            )
            await resolveCoordinates()

            // Fetch live position for active flights
            if let data = activeFlightData, data.status == "active" {
                livePosition = await AirLabsService.shared.fetchLivePosition(flightIata: data.flightIata)
            }

            // Resolve origin (hotel or GPS) then load AI transport
            resolvedOrigin = await resolveTransportOrigin()
            await loadTransportRecommendation()
        }
    }

    // MARK: - Section 1: Flight Header

    private var flightHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Text(activeFlightData?.flightIata ?? flight.number)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                statusBadge
            }

            if let data = activeFlightData {
                let displayName = data.airlineDisplayName
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Codeshare info
            if let csFlightIata = activeFlightData?.codeshareFlightIata, !csFlightIata.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text("Также как: \(csFlightIata)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            }

            // Aircraft type
            if let typeName = activeFlightData?.aircraftTypeName {
                HStack(spacing: 4) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 10))
                    Text(typeName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            } else if let typeCode = activeFlightData?.aircraftType ?? flight.aircraftType {
                HStack(spacing: 4) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 10))
                    Text(FlightData.aircraftTypeNames[typeCode] ?? typeCode)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            }

            if let data = activeFlightData, data.isDelayed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    if let dep = data.departureDelay, dep > 0 {
                        Text("Вылет +\(dep) мин")
                            .font(.system(size: 11, weight: .bold))
                    }
                    if let arr = data.arrivalDelay, arr > 0 {
                        Text("Прилёт +\(arr) мин")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .foregroundStyle(AppTheme.toriiRed)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
        )
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
        if let data = activeFlightData {
            return data.statusLocalized
        }
        return flightStatus.label
    }

    private var currentStatusColor: Color {
        if let data = activeFlightData {
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

    // MARK: - Section 2: Route

    private var routeSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack(alignment: .top, spacing: 0) {
                // Departure
                VStack(spacing: 4) {
                    Text(displayOriginCode)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let fullName = activeFlightData?.departureAirportFullName {
                        Text(fullName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    } else if let data = activeFlightData, !data.departureAirport.isEmpty {
                        Text(data.departureAirport)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    Text(displayOriginCity.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    if let depTime = activeFlightData?.departureEstimated ?? activeFlightData?.departureTime {
                        Text(flightTimeFormatted(depTime))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                    } else if let flightDate = flight.date {
                        Text(flightTimeFormatted(flightDate))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                }
                .frame(width: 80)

                // Route line with airplane
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
                                    .frame(width: 4, height: 4)
                                if i == 4 { Spacer() }
                            }
                        }

                        Image(systemName: "airplane")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.oceanBlue)
                            .offset(x: width * progress - 8)
                    }
                    .frame(height: 20)
                    .offset(y: 5)
                }
                .frame(height: 30)

                // Arrival
                VStack(spacing: 4) {
                    Text(displayDestinationCode)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let fullName = activeFlightData?.arrivalAirportFullName {
                        Text(fullName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    } else if let data = activeFlightData, !data.arrivalAirport.isEmpty {
                        Text(data.arrivalAirport)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    Text(displayDestinationCity.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    if let arrTime = activeFlightData?.arrivalEstimated ?? activeFlightData?.arrivalTime {
                        Text(flightTimeFormatted(arrTime))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                }
                .frame(width: 80)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Section 3: Map

    @ViewBuilder
    private var mapSection: some View {
        if let dep = departureCoordinate, let arr = arrivalCoordinate {
            MapRouteView(
                departure: dep,
                arrival: arr,
                progress: flightProgress,
                isActive: activeFlightData?.status == "active",
                liveCoordinate: livePosition?.coordinate
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Section 3.5: Live Info (active flights only)

    @ViewBuilder
    private var liveInfoSection: some View {
        if activeFlightData?.status == "active", let live = livePosition {
            HStack(spacing: 16) {
                if let alt = live.altitudeFeet {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.to.line")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.oceanBlue)
                        Text("\(alt) ft")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("ВЫСОТА")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let speed = live.speedKmh {
                    VStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.oceanBlue)
                        Text("\(speed) км/ч")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("СКОРОСТЬ")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let dir = live.direction {
                    VStack(spacing: 4) {
                        Image(systemName: "safari")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.oceanBlue)
                        Text("\(Int(dir))°")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("КУРС")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Section 4: Departure / Arrival Details

    private var departureArrivalSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Departure block
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                GlassSectionHeader(title: "ВЫЛЕТ", color: AppTheme.oceanBlue)

                if let fullName = activeFlightData?.departureAirportFullName {
                    detailRow(icon: "building.2", label: "Аэропорт", value: "\(fullName) (\(activeFlightData?.departureIata ?? ""))")
                } else if let data = activeFlightData, !data.departureAirport.isEmpty {
                    detailRow(icon: "building.2", label: "Аэропорт", value: "\(data.departureAirport) (\(data.departureIata))")
                }
                if let terminal = activeFlightData?.departureTerminal {
                    detailRow(icon: "door.left.hand.open", label: "Терминал", value: terminal)
                }
                if let gate = activeFlightData?.departureGate {
                    detailRow(icon: "arrow.right.square", label: "Гейт", value: gate)
                }
                if let scheduled = activeFlightData?.departureTime {
                    detailRow(icon: "clock", label: "По расписанию", value: flightTimeFormatted(scheduled))
                }
                if let estimated = activeFlightData?.departureEstimated {
                    detailRow(icon: "clock.badge.exclamationmark", label: "Ожидаемое", value: flightTimeFormatted(estimated))
                }
                if let delay = activeFlightData?.departureDelay, delay > 0 {
                    detailRow(icon: "exclamationmark.triangle", label: "Задержка", value: "+\(delay) мин")
                }
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )

            // Arrival block
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                GlassSectionHeader(title: "ПРИЛЁТ", color: AppTheme.oceanBlue)

                if let fullName = activeFlightData?.arrivalAirportFullName {
                    detailRow(icon: "building.2", label: "Аэропорт", value: "\(fullName) (\(activeFlightData?.arrivalIata ?? ""))")
                } else if let data = activeFlightData, !data.arrivalAirport.isEmpty {
                    detailRow(icon: "building.2", label: "Аэропорт", value: "\(data.arrivalAirport) (\(data.arrivalIata))")
                }
                if let terminal = activeFlightData?.arrivalTerminal {
                    detailRow(icon: "door.left.hand.open", label: "Терминал", value: terminal)
                }
                if let gate = activeFlightData?.arrivalGate {
                    detailRow(icon: "arrow.right.square", label: "Гейт", value: gate)
                }
                if let baggage = activeFlightData?.arrivalBaggage {
                    detailRow(icon: "suitcase.fill", label: "Багажная лента", value: baggage)
                }
                if let scheduled = activeFlightData?.arrivalTime {
                    detailRow(icon: "clock", label: "По расписанию", value: flightTimeFormatted(scheduled))
                }
                if let estimated = activeFlightData?.arrivalEstimated {
                    detailRow(icon: "clock.badge.exclamationmark", label: "Ожидаемое", value: flightTimeFormatted(estimated))
                }
                if let delay = activeFlightData?.arrivalDelay, delay > 0 {
                    detailRow(icon: "exclamationmark.triangle", label: "Задержка", value: "+\(delay) мин")
                }
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.oceanBlue.opacity(0.7))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, 4)
    }

    // MARK: - Section 5: Airport Transport (AI)

    @ViewBuilder
    private var airportTransportSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                GlassSectionHeader(title: "КАК ДОБРАТЬСЯ ДО АЭРОПОРТА", color: AppTheme.bambooGreen)
                Spacer()
                if transportRecommendation != nil {
                    Button {
                        Task {
                            FlightAIService.shared.clearCache(for: flight.id)
                            transportRecommendation = nil
                            resolvedOrigin = await resolveTransportOrigin()
                            await loadTransportRecommendation()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.bambooGreen.opacity(0.7))
                    }
                }
            }

            // Origin badge
            if let origin = resolvedOrigin {
                HStack(spacing: 6) {
                    Image(systemName: origin.isGPS ? "location.fill" : "bed.double.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(origin.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(AppTheme.bambooGreen.opacity(0.8))
                .padding(.horizontal, AppTheme.spacingS)
            }

            if isLoadingTransport {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Генерируем рекомендации...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppTheme.spacingS)
            } else if let rec = transportRecommendation {
                ForEach(Array(rec.options.enumerated()), id: \.element.id) { idx, option in
                    transportOptionRow(option, isRecommended: idx == rec.recommended)
                }

                if !rec.tip.isEmpty {
                    Rectangle()
                        .fill(AppTheme.bambooGreen.opacity(0.12))
                        .frame(height: 0.5)
                        .padding(.vertical, 4)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.templeGold)
                        Text(rec.tip)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppTheme.spacingS)
                }
            } else if resolvedOrigin == nil && !isLoadingTransport {
                HStack(spacing: 10) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нет подходящей отправной точки")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(noOriginExplanation)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingS)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.bambooGreen.opacity(0.15), lineWidth: 0.5)
        )
    }

    /// Объяснение почему нет рекомендаций — контекстное
    private var noOriginExplanation: String {
        let depIata = activeFlightData?.departureIata ?? flight.departureIata ?? ""
        let city = activeFlightData?.departureCityName ?? FlightData.airportCities[depIata] ?? ""
        let hasAccommodation = trip.days.flatMap(\.places).contains { $0.category == .accommodation }
        let hasLocation = LocationManager.shared.currentLocation != nil

        if !hasAccommodation && !hasLocation {
            return "Добавьте жильё в маршрут или включите геолокацию"
        } else if hasAccommodation && !city.isEmpty {
            return "Жильё в маршруте не в городе вылета (\(city))"
        } else if hasLocation && !city.isEmpty {
            return "Вы дальше 200 км от аэропорта (\(city))"
        }
        return "Добавьте жильё в город вылета"
    }

    private func transportOptionRow(_ option: TransportOption, isRecommended: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: option.type.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(isRecommended ? AppTheme.bambooGreen : AppTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.type.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text("ЛУЧШИЙ")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.bambooGreen)
                                .clipShape(Capsule())
                        }
                    }
                    Text(option.departureTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(option.duration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(option.priceRange)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.bambooGreen)
                }
            }

            // Route
            if !option.route.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.oceanBlue.opacity(0.6))
                        .padding(.top, 2)
                    Text(option.route)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 40)
            }

            // Steps
            if !option.steps.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(option.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(idx + 1).")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14, alignment: .trailing)
                            Text(step)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 40)
            }
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, 8)
        .background(isRecommended ? AppTheme.bambooGreen.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    }

    // MARK: - Section 6: Related Tickets

    private var relatedTicketsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "СВЯЗАННЫЕ БИЛЕТЫ", color: AppTheme.sakuraPink)

            if relatedTickets.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "ticket")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нет связанных билетов")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Добавьте посадочный талон")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingS)
            } else {
                ForEach(relatedTickets) { ticket in
                    NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                        ticketRow(ticket)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func ticketRow(_ ticket: Ticket) -> some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: ticket.category.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(ticket.category.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(ticket.formattedDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, 6)
    }

    private var relatedTickets: [Ticket] {
        trip.tickets.filter { ticket in
            guard ticket.category == .transport else { return false }
            guard let flightDate = flight.date else { return true }
            let dayDiff = abs(Calendar.current.dateComponents([.day], from: flightDate, to: ticket.eventDate).day ?? 0)
            return dayDiff <= 1
        }
        .sorted { $0.eventDate < $1.eventDate }
    }

    // MARK: - Transport Origin Resolution

    /// Определяет откуда пользователь поедет в аэропорт (строгая иерархия):
    /// 1. Жильё из маршрута в городе вылета с валидацией по времени заселения
    /// 2. GPS-позиция, но ТОЛЬКО если в том же городе что и аэропорт вылета
    /// 3. Ничего — не показываем рекомендации (лучше ничего, чем бред)
    private func resolveTransportOrigin() async -> TransportOrigin? {
        let depIata = activeFlightData?.departureIata ?? flight.departureIata ?? ""
        let departureCityName = (activeFlightData?.departureCityName
            ?? FlightData.airportCities[depIata] ?? "").lowercased()
        guard !departureCityName.isEmpty else { return nil }

        // 1. Жильё из маршрута — строго в городе вылета, с проверкой заселения
        if let hotel = findValidAccommodation(departureCityName: departureCityName) {
            return .hotel(place: hotel)
        }

        // 2. GPS — только если в радиусе 200 км от аэропорта вылета
        if let coord = await LocationManager.shared.requestCurrentLocation(),
           let airportCoord = FlightData.coordinate(forIata: depIata) {
            let userLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let airportLocation = CLLocation(latitude: airportCoord.latitude, longitude: airportCoord.longitude)
            let distanceKm = userLocation.distance(from: airportLocation) / 1000.0

            if distanceKm <= 200 {
                let geo = await reverseGeocodeWithCity(coord)
                let address = geo?.address ?? String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                return .gps(address: address, coordinate: coord)
            }
            // GPS > 200 км от аэропорта → НЕ даём рекомендации
        }

        return nil
    }

    /// Ищет жильё в городе вылета. Валидирует:
    /// - Place.category == .accommodation на дне вылета / накануне
    /// - День в городе вылета (cityName)
    /// - Если есть TripEvent(.checkin) — проверяет что заселение ДО вылета
    private func findValidAccommodation(departureCityName: String) -> Place? {
        guard let flightDate = flight.date ?? activeFlightData?.departureTime else { return nil }

        // Дни вылета (0) и накануне (1), сортировка: ближе к вылету = выше
        let candidates = trip.days
            .filter { day in
                let diff = Calendar.current.dateComponents([.day], from: day.date, to: flightDate).day ?? 999
                return diff >= 0 && diff <= 1
            }
            .filter { isSameCity($0.cityName, departureCityName) }
            .sorted { a, b in
                abs(Calendar.current.dateComponents([.day], from: a.date, to: flightDate).day ?? 999)
                < abs(Calendar.current.dateComponents([.day], from: b.date, to: flightDate).day ?? 999)
            }

        for day in candidates {
            guard let hotel = day.places.first(where: { $0.category == .accommodation }) else { continue }

            // Ищем событие заселения на этом дне
            let checkinEvent = day.events.first { $0.category == .checkin }

            if let checkin = checkinEvent {
                // Заселение должно быть ДО вылета
                if checkin.startTime <= flightDate {
                    return hotel
                }
                // Заселение ПОСЛЕ вылета — значит пользователь ещё не заехал, пропускаем
                continue
            }

            // Нет события заселения, но жильё отмечено — допускаем
            return hotel
        }

        return nil
    }

    /// Сравнение городов (нечёткое: "Москва" ⊂ "Москва и область")
    private func isSameCity(_ a: String, _ b: String) -> Bool {
        let aLower = a.lowercased().trimmingCharacters(in: .whitespaces)
        let bLower = b.lowercased().trimmingCharacters(in: .whitespaces)
        guard !aLower.isEmpty, !bLower.isEmpty else { return false }
        return aLower.contains(bLower) || bLower.contains(aLower)
    }

    private func reverseGeocodeWithCity(_ coordinate: CLLocationCoordinate2D) async -> (address: String, city: String)? {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ) { placemarks, _ in
                guard let pm = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let addressParts = [pm.thoroughfare, pm.subThoroughfare, pm.locality].compactMap { $0 }
                let address = addressParts.joined(separator: ", ")
                let city = pm.locality ?? pm.administrativeArea ?? ""
                continuation.resume(returning: (address: address, city: city))
            }
        }
    }

    private func loadTransportRecommendation() async {
        guard let origin = resolvedOrigin else { return }
        guard let depIata = activeFlightData?.departureIata ?? flight.departureIata,
              !depIata.isEmpty else { return }
        guard let depTime = activeFlightData?.departureTime ?? flight.date else { return }

        let airportName = activeFlightData?.departureAirportFullName
            ?? FlightData.airportFullNames[depIata]
            ?? depIata
        let cityName = activeFlightData?.departureCityName
            ?? FlightData.airportCities[depIata]
            ?? ""

        isLoadingTransport = true
        defer { isLoadingTransport = false }

        transportRecommendation = await FlightAIService.shared.generateRecommendation(
            originName: origin.name,
            originAddress: origin.address,
            originCoordinate: origin.coordinate,
            airportName: airportName,
            airportIata: depIata,
            departureTime: depTime,
            cityName: cityName,
            flightID: flight.id
        )
    }

    // MARK: - Flight Status (fallback)

    private enum FlightStatusType {
        case scheduled, inFlight, landed

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
        if let data = activeFlightData {
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
        if let data = activeFlightData, !data.departureIata.isEmpty {
            return data.departureIata
        }
        return "···"
    }

    private var displayDestinationCode: String {
        if let data = activeFlightData, !data.arrivalIata.isEmpty {
            return data.arrivalIata
        }
        return "···"
    }

    private var displayOriginCity: String {
        activeFlightData?.departureCityName ?? ""
    }

    private var displayDestinationCity: String {
        activeFlightData?.arrivalCityName ?? ""
    }

    private func flightTimeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm, d MMM"
        return f.string(from: date)
    }

    // MARK: - Coordinate Resolution

    private func resolveCoordinates() async {
        let depCode = activeFlightData?.departureIata ?? ""
        let arrCode = activeFlightData?.arrivalIata ?? ""

        if let known = FlightData.coordinate(forIata: depCode) {
            departureCoordinate = known
        } else {
            let depName = activeFlightData?.departureAirport ?? ""
            departureCoordinate = await geocode(depName)
        }

        if let known = FlightData.coordinate(forIata: arrCode) {
            arrivalCoordinate = known
        } else {
            let arrName = activeFlightData?.arrivalAirport ?? ""
            arrivalCoordinate = await geocode(arrName)
        }
    }

    private func geocode(_ name: String) async -> CLLocationCoordinate2D? {
        guard !name.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(name) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }
}

// MARK: - Map Route View (UIKit MapKit wrapper)

private struct MapRouteView: UIViewRepresentable {
    let departure: CLLocationCoordinate2D
    let arrival: CLLocationCoordinate2D
    let progress: Double
    let isActive: Bool
    var liveCoordinate: CLLocationCoordinate2D? = nil

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Departure annotation
        let depAnnotation = MKPointAnnotation()
        depAnnotation.coordinate = departure
        depAnnotation.title = "Вылет"
        mapView.addAnnotation(depAnnotation)

        // Arrival annotation
        let arrAnnotation = MKPointAnnotation()
        arrAnnotation.coordinate = arrival
        arrAnnotation.title = "Прилёт"
        mapView.addAnnotation(arrAnnotation)

        // Geodesic polyline
        let coords = [departure, arrival]
        let geodesic = MKGeodesicPolyline(coordinates: coords, count: 2)
        mapView.addOverlay(geodesic)

        // Plane position if active
        if isActive && progress > 0 && progress < 1 {
            let planeCoord: CLLocationCoordinate2D
            if let live = liveCoordinate {
                planeCoord = live
            } else {
                planeCoord = interpolate(from: departure, to: arrival, fraction: progress)
            }
            let planeAnnotation = MKPointAnnotation()
            planeAnnotation.coordinate = planeCoord
            planeAnnotation.title = "plane"
            mapView.addAnnotation(planeAnnotation)
        }

        // Fit region
        let midLat = (departure.latitude + arrival.latitude) / 2
        let midLon = (departure.longitude + arrival.longitude) / 2
        let latDelta = abs(departure.latitude - arrival.latitude) * 1.5 + 5
        let lonDelta = abs(departure.longitude - arrival.longitude) * 1.5 + 5
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
        mapView.setRegion(region, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func interpolate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        fraction: Double
    ) -> CLLocationCoordinate2D {
        let lat = from.latitude + (to.latitude - from.latitude) * fraction
        let lon = from.longitude + (to.longitude - from.longitude) * fraction
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(AppTheme.oceanBlue)
                renderer.lineWidth = 2
                renderer.lineDashPattern = [6, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation.title == "plane" {
                let id = "plane"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false

                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
                view.image = UIImage(systemName: "airplane.circle.fill", withConfiguration: config)?
                    .withTintColor(UIColor(AppTheme.oceanBlue), renderingMode: .alwaysOriginal)
                return view
            }

            if annotation is MKPointAnnotation {
                let id = "airport"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                if let markerView = view as? MKMarkerAnnotationView {
                    markerView.markerTintColor = UIColor(AppTheme.oceanBlue)
                    markerView.glyphImage = UIImage(systemName: "airplane")
                }
                view.annotation = annotation
                return view
            }

            return nil
        }
    }
}
