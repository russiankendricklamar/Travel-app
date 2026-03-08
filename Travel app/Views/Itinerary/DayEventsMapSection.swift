import SwiftUI
import MapKit

struct DayEventsMapSection: View {
    let events: [TripEvent]

    @State private var showFullScreenMap = false

    private var eventsWithLocation: [TripEvent] {
        events
            .filter { $0.hasLocation }
            .sorted { $0.startTime < $1.startTime }
    }

    private var allCoordinates: [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        for event in eventsWithLocation {
            if let primary = event.primaryCoordinate {
                coords.append(primary)
            }
            if let arrival = event.arrivalCoordinate {
                coords.append(arrival)
            }
        }
        return coords
    }

    private var region: MKCoordinateRegion {
        guard !allCoordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let lats = allCoordinates.map(\.latitude)
        let lons = allCoordinates.map(\.longitude)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Route Segments

    private var routeSegments: [EventRouteSegment] {
        buildRouteSegments(from: eventsWithLocation)
    }

    private var straightSegments: [EventRouteSegment] {
        routeSegments.filter { !$0.isFlight }
    }

    private var flightArcs: [EventFlightArc] {
        buildFlightArcs(from: routeSegments)
    }

    private var hasRoute: Bool {
        !routeSegments.isEmpty
    }

    var body: some View {
        if eventsWithLocation.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                GlassSectionHeader(title: "КАРТА СОБЫТИЙ", color: AppTheme.oceanBlue)

                Map(initialPosition: .region(region), interactionModes: []) {
                    // Event pins
                    ForEach(eventsWithLocation) { event in
                        if let coord = event.primaryCoordinate {
                            Annotation("", coordinate: coord) {
                                eventPin(event: event, isArrival: false)
                            }
                        }
                        if let arrival = event.arrivalCoordinate {
                            Annotation("", coordinate: arrival) {
                                eventPin(event: event, isArrival: true)
                            }
                        }
                    }

                    // Non-flight route segments (straight lines)
                    ForEach(straightSegments) { seg in
                        MapPolyline(coordinates: [seg.from, seg.to])
                            .stroke(AppTheme.oceanBlue.opacity(0.6), lineWidth: 2.5)
                    }

                    // Flight arcs (curved)
                    ForEach(flightArcs) { arc in
                        MapPolyline(coordinates: arc.points)
                            .stroke(.white.opacity(0.85), lineWidth: 2)
                    }

                    // Airplane icons at arc midpoints
                    ForEach(flightArcs) { arc in
                        Annotation("", coordinate: arc.midpoint, anchor: .center) {
                            Image(systemName: "airplane")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(arc.bearing - 45))
                                .shadow(color: .black.opacity(0.5), radius: 3)
                        }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    showFullScreenMap = true
                }
                .fullScreenCover(isPresented: $showFullScreenMap) {
                    FullScreenEventsMapView(
                        events: eventsWithLocation,
                        region: region
                    )
                }

                // Legend
                HStack(spacing: AppTheme.spacingM) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.oceanBlue)
                            .frame(width: 6, height: 6)
                        Text("\(eventsWithLocation.count) СОБЫТИЙ")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                    }
                    if hasRoute {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(AppTheme.oceanBlue.opacity(0.5))
                                .frame(width: 16, height: 2)
                            Text("МАРШРУТ")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacingS)
            }
        }
    }

    private func eventPin(event: TripEvent, isArrival: Bool) -> some View {
        Self.eventPinView(event: event, isArrival: isArrival, size: 28, fontSize: 11)
    }

    static func eventPinView(event: TripEvent, isArrival: Bool, size: CGFloat, fontSize: CGFloat) -> some View {
        Image(systemName: isArrival ? "flag.fill" : event.category.systemImage)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [event.category.color, event.category.color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .shadow(color: event.category.color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Full Screen Events Map

private struct FullScreenEventsMapView: View {
    let events: [TripEvent]
    let region: MKCoordinateRegion

    @Environment(\.dismiss) private var dismiss

    private var segments: [EventRouteSegment] {
        buildRouteSegments(from: events)
    }

    private var straightSegments: [EventRouteSegment] {
        segments.filter { !$0.isFlight }
    }

    private var arcs: [EventFlightArc] {
        buildFlightArcs(from: segments)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(initialPosition: .region(region)) {
                ForEach(events) { event in
                    if let coord = event.primaryCoordinate {
                        Annotation(event.title, coordinate: coord) {
                            DayEventsMapSection.eventPinView(
                                event: event,
                                isArrival: false,
                                size: 36,
                                fontSize: 14
                            )
                        }
                    }
                    if let arrival = event.arrivalCoordinate {
                        Annotation("", coordinate: arrival) {
                            DayEventsMapSection.eventPinView(
                                event: event,
                                isArrival: true,
                                size: 36,
                                fontSize: 14
                            )
                        }
                    }
                }

                // Non-flight segments
                ForEach(straightSegments) { seg in
                    MapPolyline(coordinates: [seg.from, seg.to])
                        .stroke(AppTheme.oceanBlue.opacity(0.7), lineWidth: 3.5)
                }

                // Flight arcs
                ForEach(arcs) { arc in
                    MapPolyline(coordinates: arc.points)
                        .stroke(.white.opacity(0.85), lineWidth: 2.5)
                }

                // Airplane icons
                ForEach(arcs) { arc in
                    Annotation("", coordinate: arc.midpoint, anchor: .center) {
                        Image(systemName: "airplane")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(arc.bearing - 45))
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 56)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Route Segment Helpers

private struct EventRouteSegment: Identifiable {
    let id = UUID()
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let isFlight: Bool
}

private struct EventFlightArc: Identifiable {
    let id = UUID()
    let points: [CLLocationCoordinate2D]
    let midpoint: CLLocationCoordinate2D
    let bearing: Double
}

private func buildRouteSegments(from events: [TripEvent]) -> [EventRouteSegment] {
    let sorted = events
        .filter { $0.hasLocation }
        .sorted { $0.startTime < $1.startTime }

    var segments: [EventRouteSegment] = []
    var previous: CLLocationCoordinate2D?

    for event in sorted {
        if event.category == .flight {
            if let dep = event.primaryCoordinate {
                if let prev = previous {
                    segments.append(EventRouteSegment(from: prev, to: dep, isFlight: false))
                }
                if let arr = event.arrivalCoordinate {
                    segments.append(EventRouteSegment(from: dep, to: arr, isFlight: true))
                    previous = arr
                } else {
                    previous = dep
                }
            }
        } else if event.isTransportEvent {
            if let dep = event.primaryCoordinate {
                if let prev = previous {
                    segments.append(EventRouteSegment(from: prev, to: dep, isFlight: false))
                }
                if let arr = event.arrivalCoordinate {
                    segments.append(EventRouteSegment(from: dep, to: arr, isFlight: false))
                    previous = arr
                } else {
                    previous = dep
                }
            }
        } else {
            if let primary = event.primaryCoordinate {
                if let prev = previous {
                    segments.append(EventRouteSegment(from: prev, to: primary, isFlight: false))
                }
                previous = primary
            }
        }
    }

    return segments
}

private func buildFlightArcs(from segments: [EventRouteSegment]) -> [EventFlightArc] {
    segments.filter(\.isFlight).map { seg in
        let points = eventFlightArcPoints(from: seg.from, to: seg.to)
        let midpoint = points[points.count / 2]
        let bearing = eventFlightBearing(from: seg.from, to: seg.to)
        return EventFlightArc(points: points, midpoint: midpoint, bearing: bearing)
    }
}

private func eventFlightArcPoints(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D,
    segments: Int = 60
) -> [CLLocationCoordinate2D] {
    let dLat = end.latitude - start.latitude
    let dLon = end.longitude - start.longitude
    let dist = sqrt(dLat * dLat + dLon * dLon)
    guard dist > 0 else { return [start, end] }

    let midLat = (start.latitude + end.latitude) / 2
    let midLon = (start.longitude + end.longitude) / 2

    let perpLat = -dLon / dist
    let perpLon = dLat / dist
    let sign: Double = perpLat >= 0 ? 1 : -1
    let height = dist * 0.15

    let ctrlLat = midLat + sign * perpLat * height
    let ctrlLon = midLon + sign * perpLon * height

    return (0...segments).map { i in
        let t = Double(i) / Double(segments)
        let lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * ctrlLat + t * t * end.latitude
        let lon = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * ctrlLon + t * t * end.longitude
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

private func eventFlightBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let dLon = (to.longitude - from.longitude) * .pi / 180
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    return atan2(y, x) * 180 / .pi
}
