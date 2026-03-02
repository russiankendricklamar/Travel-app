import SwiftUI
import CoreLocation

struct EventRouteCard: View {
    let fromEvent: TripEvent
    let toEvent: TripEvent

    private var fromCoord: CLLocation? {
        guard let coord = fromEvent.effectiveEndCoordinate else { return nil }
        return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    }

    private var toCoord: CLLocation? {
        guard let coord = toEvent.primaryCoordinate else { return nil }
        return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    }

    private var distanceMeters: Double? {
        guard let from = fromCoord, let to = toCoord else { return nil }
        return from.distance(from: to)
    }

    private var estimatedTravelMinutes: Int? {
        guard let dist = distanceMeters else { return nil }
        let km = dist / 1000.0
        // 30 km/h city, 100 km/h train (use 50 km/h average)
        let speedKmH: Double = km > 20 ? 80.0 : 30.0
        return max(Int((km / speedKmH) * 60), 1)
    }

    private var freeTimeMinutes: Int {
        Int(toEvent.startTime.timeIntervalSince(fromEvent.endTime) / 60)
    }

    private var hasEnoughTime: Bool {
        guard let travel = estimatedTravelMinutes else { return true }
        return freeTimeMinutes >= travel
    }

    var body: some View {
        guard fromCoord != nil && toCoord != nil else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: AppTheme.spacingS) {
                // Dashed line connector
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(hasEnoughTime ? AppTheme.bambooGreen.opacity(0.4) : AppTheme.toriiRed.opacity(0.4))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let dist = distanceMeters {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 9, weight: .bold))
                                Text(formatDistance(dist))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.secondary)
                        }

                        if let travel = estimatedTravelMinutes {
                            HStack(spacing: 3) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("~\(travel) мин")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .bold))
                        Text("Свободно: \(freeTimeMinutes) мин")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(hasEnoughTime ? AppTheme.bambooGreen : AppTheme.toriiRed)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, AppTheme.spacingS)
        )
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f км", meters / 1000)
        }
        return "\(Int(meters)) м"
    }
}
