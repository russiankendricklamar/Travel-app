import SwiftUI
import MapKit
import CoreLocation

struct FlightDetailView: View {
    let trip: Trip
    let flightData: FlightData?

    @State private var departureCoordinate: CLLocationCoordinate2D?
    @State private var arrivalCoordinate: CLLocationCoordinate2D?
    @State private var showEditSheet = false

    private let estimatedFlightHours: Double = 10

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                flightHeader
                routeSection
                mapSection
                departureArrivalSection
                relatedTicketsSection
            }
            .padding(AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .sakuraGradientBackground()
        .navigationTitle(flightData?.flightIata ?? trip.flightNumber ?? "")
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
            await resolveCoordinates()
        }
    }

    // MARK: - Section 1: Flight Header

    private var flightHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Text(flightData?.flightIata ?? trip.flightNumber ?? "")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                statusBadge
            }

            if let data = flightData, !data.airlineName.isEmpty {
                Text(data.airlineName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let data = flightData, data.isDelayed {
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

    // MARK: - Section 2: Route

    private var routeSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack(alignment: .top, spacing: 0) {
                // Departure
                VStack(spacing: 4) {
                    Text(displayOriginCode)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let data = flightData, !data.departureAirport.isEmpty {
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
                    if let depTime = flightData?.departureEstimated ?? flightData?.departureTime {
                        Text(flightTimeFormatted(depTime))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                    } else if let flight = trip.flightDate {
                        Text(flightTimeFormatted(flight))
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
                    if let data = flightData, !data.arrivalAirport.isEmpty {
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
                    if let arrTime = flightData?.arrivalEstimated ?? flightData?.arrivalTime {
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
                isActive: flightData?.status == "active"
            )
            .frame(height: 200)
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

                if let data = flightData, !data.departureAirport.isEmpty {
                    detailRow(icon: "building.2", label: "Аэропорт", value: "\(data.departureAirport) (\(data.departureIata))")
                }
                if let terminal = flightData?.departureTerminal {
                    detailRow(icon: "door.left.hand.open", label: "Терминал", value: terminal)
                }
                if let gate = flightData?.departureGate {
                    detailRow(icon: "arrow.right.square", label: "Гейт", value: gate)
                }
                if let scheduled = flightData?.departureTime {
                    detailRow(icon: "clock", label: "По расписанию", value: flightTimeFormatted(scheduled))
                }
                if let estimated = flightData?.departureEstimated {
                    detailRow(icon: "clock.badge.exclamationmark", label: "Ожидаемое", value: flightTimeFormatted(estimated))
                }
                if let delay = flightData?.departureDelay, delay > 0 {
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

                if let data = flightData, !data.arrivalAirport.isEmpty {
                    detailRow(icon: "building.2", label: "Аэропорт", value: "\(data.arrivalAirport) (\(data.arrivalIata))")
                }
                if let terminal = flightData?.arrivalTerminal {
                    detailRow(icon: "door.left.hand.open", label: "Терминал", value: terminal)
                }
                if let gate = flightData?.arrivalGate {
                    detailRow(icon: "arrow.right.square", label: "Гейт", value: gate)
                }
                if let scheduled = flightData?.arrivalTime {
                    detailRow(icon: "clock", label: "По расписанию", value: flightTimeFormatted(scheduled))
                }
                if let estimated = flightData?.arrivalEstimated {
                    detailRow(icon: "clock.badge.exclamationmark", label: "Ожидаемое", value: flightTimeFormatted(estimated))
                }
                if let delay = flightData?.arrivalDelay, delay > 0 {
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

    // MARK: - Section 5: Related Tickets

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
            guard let flightDate = trip.flightDate else { return true }
            let dayDiff = abs(Calendar.current.dateComponents([.day], from: flightDate, to: ticket.eventDate).day ?? 0)
            return dayDiff <= 1
        }
        .sorted { $0.eventDate < $1.eventDate }
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

    // MARK: - Coordinate Resolution

    private func resolveCoordinates() async {
        let depCode = flightData?.departureIata ?? ""
        let arrCode = flightData?.arrivalIata ?? ""

        if let known = Self.airportCoordinates[depCode] {
            departureCoordinate = known
        } else {
            let depName = flightData?.departureAirport ?? originCity
            departureCoordinate = await geocode(depName)
        }

        if let known = Self.airportCoordinates[arrCode] {
            arrivalCoordinate = known
        } else {
            let arrName = flightData?.arrivalAirport ?? trip.destination
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

    // MARK: - Known Airport Coordinates

    private static let airportCoordinates: [String: CLLocationCoordinate2D] = [
        "SVO": CLLocationCoordinate2D(latitude: 55.9726, longitude: 37.4146),
        "DME": CLLocationCoordinate2D(latitude: 55.4088, longitude: 37.9063),
        "VKO": CLLocationCoordinate2D(latitude: 55.5915, longitude: 37.2615),
        "LED": CLLocationCoordinate2D(latitude: 59.8003, longitude: 30.2625),
        "NRT": CLLocationCoordinate2D(latitude: 35.7647, longitude: 140.3864),
        "HND": CLLocationCoordinate2D(latitude: 35.5494, longitude: 139.7798),
        "KIX": CLLocationCoordinate2D(latitude: 34.4347, longitude: 135.2440),
        "ICN": CLLocationCoordinate2D(latitude: 37.4602, longitude: 126.4407),
        "PEK": CLLocationCoordinate2D(latitude: 40.0799, longitude: 116.6031),
        "HKG": CLLocationCoordinate2D(latitude: 22.3080, longitude: 113.9185),
        "DXB": CLLocationCoordinate2D(latitude: 25.2532, longitude: 55.3657),
        "IST": CLLocationCoordinate2D(latitude: 41.2753, longitude: 28.7519),
        "AYT": CLLocationCoordinate2D(latitude: 36.8987, longitude: 30.8005),
        "BKK": CLLocationCoordinate2D(latitude: 13.6900, longitude: 100.7501),
        "SIN": CLLocationCoordinate2D(latitude: 1.3502, longitude: 103.9944),
        "CDG": CLLocationCoordinate2D(latitude: 49.0097, longitude: 2.5479),
        "LHR": CLLocationCoordinate2D(latitude: 51.4700, longitude: -0.4543),
        "JFK": CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781),
        "LAX": CLLocationCoordinate2D(latitude: 33.9416, longitude: -118.4085),
        "FCO": CLLocationCoordinate2D(latitude: 41.8003, longitude: 12.2389),
        "BCN": CLLocationCoordinate2D(latitude: 41.2974, longitude: 2.0833),
        "FRA": CLLocationCoordinate2D(latitude: 50.0379, longitude: 8.5622),
        "AER": CLLocationCoordinate2D(latitude: 43.4499, longitude: 39.9566),
        "KZN": CLLocationCoordinate2D(latitude: 55.6062, longitude: 49.2787),
        "SVX": CLLocationCoordinate2D(latitude: 56.7431, longitude: 60.8027),
        "OVB": CLLocationCoordinate2D(latitude: 55.0126, longitude: 82.6507),
        "KUF": CLLocationCoordinate2D(latitude: 53.5049, longitude: 50.1643),
    ]
}

// MARK: - Map Route View (UIKit MapKit wrapper)

private struct MapRouteView: UIViewRepresentable {
    let departure: CLLocationCoordinate2D
    let arrival: CLLocationCoordinate2D
    let progress: Double
    let isActive: Bool

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
            let planeCoord = interpolate(from: departure, to: arrival, fraction: progress)
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
