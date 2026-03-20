import SwiftUI
import MapKit

/// Информация о маршруте в bottom sheet (Apple Maps style)
struct MapRouteContent: View {
    @Bindable var vm: MapViewModel

    var body: some View {
        if let route = vm.activeRoute {
            VStack(spacing: 0) {
                // Header
                routeHeader(route: route)

                // Transport mode pills
                transportModePills(route: route)
                    .padding(.top, 12)

                // Route stats
                routeStatsRow(route: route)
                    .padding(.top, 14)

                // Transit steps
                if route.mode == .transit, !route.transitSteps.isEmpty {
                    transitStepsList(route.transitSteps)
                        .padding(.top, 12)
                }

                // Transit unavailable in region — offer Apple Maps
                if RoutingService.shared.transitUnavailableRegion {
                    transitUnavailableBanner
                        .padding(.top, 12)
                }

                // Route error
                if let error = vm.routeError, !RoutingService.shared.transitUnavailableRegion {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.toriiRed)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Start navigation button
                Button {
                    Task { await vm.startNavigation() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("НАЧАТЬ НАВИГАЦИЮ")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .fill(AppTheme.sakuraPink)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .disabled(vm.navigationSteps.isEmpty && vm.isCalculatingRoute)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Header

    private func routeHeader(route: RouteResult) -> some View {
        ZStack {
            HStack {
                Spacer()
                Button {
                    vm.clearRoute()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 3) {
                Text(destinationName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                Text(originLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 44)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Transport Mode Pills

    private func transportModePills(route: RouteResult) -> some View {
        HStack(spacing: 8) {
            ForEach(TransportMode.allCases) { mode in
                Button {
                    vm.selectedTransportMode = mode
                    recalculateRoute()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .semibold))

                        // Show ETA preview if available, otherwise label
                        if route.mode != mode,
                           let preview = RoutingService.shared.etaPreviews[mode] {
                            Text(RoutingService.formatDuration(preview.duration))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        } else {
                            Text(mode.label)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundStyle(route.mode == mode ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(route.mode == mode ? mode.color : Color.primary.opacity(0.06))
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Route Stats

    private func routeStatsRow(route: RouteResult) -> some View {
        HStack(spacing: 0) {
            if vm.isCalculatingRoute {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Расчёт...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                // Duration
                VStack(spacing: 3) {
                    Text("Время")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: route.mode.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(route.mode.color)
                        Text(RoutingService.formatDuration(route.expectedTravelTime))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(route.mode.color)
                    }
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 0.5, height: 32)

                // Distance
                VStack(spacing: 3) {
                    Text("Расстояние")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(RoutingService.formatDistance(route.distance))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Transit Steps

    private func transitStepsList(_ steps: [TransitStep]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: 10) {
                    // Icon
                    transitStepIcon(step)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        // Line name or walking instruction
                        if step.travelMode == "TRANSIT", let lineName = step.transitLineName {
                            HStack(spacing: 6) {
                                Text(lineName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(transitLineColor(step.transitLineColor))
                                    )
                                Text(RoutingService.formatDuration(step.duration))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(step.instruction)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if step.distance > 0 {
                            Text(RoutingService.formatDistance(step.distance))
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    private func transitStepIcon(_ step: TransitStep) -> some View {
        let iconName: String
        let color: Color

        switch step.travelMode {
        case "TRANSIT":
            switch step.vehicleType {
            case "SUBWAY", "METRO_RAIL": iconName = "tram.fill"
            case "BUS": iconName = "bus.fill"
            case "RAIL", "HEAVY_RAIL", "COMMUTER_TRAIN": iconName = "train.side.front.car"
            case "TRAM", "LIGHT_RAIL": iconName = "tram"
            case "FERRY": iconName = "ferry.fill"
            default: iconName = "tram.fill"
            }
            color = transitLineColor(step.transitLineColor)
        default:
            iconName = "figure.walk"
            color = .secondary
        }

        return Image(systemName: iconName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func transitLineColor(_ hex: String?) -> Color {
        guard let hex = hex, hex.hasPrefix("#"), hex.count == 7 else {
            return AppTheme.templeGold
        }
        let scanner = Scanner(string: String(hex.dropFirst()))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    // MARK: - Computed

    private var destinationName: String {
        if let place = vm.selectedPlace {
            return place.name
        } else if let item = vm.searchedItem {
            return item.name ?? "Точка на карте"
        } else if let rec = vm.selectedAIResult {
            return rec.name
        }
        return "Маршрут"
    }

    private var originLabel: String {
        // Show reverse-geocoded address if available
        if let address = vm.activeRoute?.originAddress {
            return "От: \(address)"
        }
        if vm.routeFromCurrentLocation {
            return "От текущего местоположения"
        } else if let origin = vm.routeOriginPlace {
            return "От: \(origin.name)"
        }
        return ""
    }

    // MARK: - Transit Unavailable Banner

    private var transitUnavailableBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)
                Text("Транзит недоступен через Google в этом регионе")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                openTransitInAppleMaps()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Открыть в Apple Maps")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.templeGold)
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func recalculateRoute() {
        if let place = vm.selectedPlace {
            Task { await vm.calculateDirectionRoute(to: place) }
        } else if let item = vm.searchedItem {
            Task { await vm.calculateRouteToSearchedItem(item) }
        }
    }

    private func openTransitInAppleMaps() {
        guard let origin = currentOrigin else { return }
        let destination = currentDestination
        RoutingService.openAppleMapsTransit(
            from: origin,
            to: destination,
            destinationName: destinationName
        )
    }

    private var currentOrigin: CLLocationCoordinate2D? {
        if vm.routeFromCurrentLocation {
            return LocationManager.shared.currentLocation
        }
        return vm.routeOriginPlace?.coordinate
    }

    private var currentDestination: CLLocationCoordinate2D {
        if let place = vm.selectedPlace {
            return place.coordinate
        } else if let item = vm.searchedItem {
            return item.placemark.coordinate
        } else if let rec = vm.selectedAIResult {
            return CLLocationCoordinate2D(latitude: rec.latitude, longitude: rec.longitude)
        }
        return CLLocationCoordinate2D()
    }
}
