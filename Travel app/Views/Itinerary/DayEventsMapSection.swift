import SwiftUI
import MapKit

struct DayEventsMapSection: View {
    let events: [TripEvent]

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

    /// Route coordinates in order: for transport events, departure then arrival
    private var routeCoordinates: [CLLocationCoordinate2D] {
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

                    // Dashed route line
                    if routeCoordinates.count >= 2 {
                        MapPolyline(coordinates: routeCoordinates)
                            .stroke(AppTheme.oceanBlue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

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
                    if routeCoordinates.count >= 2 {
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
        Image(systemName: isArrival ? "flag.fill" : event.category.systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
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
