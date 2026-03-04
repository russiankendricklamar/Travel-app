import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    let trip: Trip

    @State private var selectedPlace: Place?
    @State private var showRoutes = true
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showDiscoverNearby = false
    #if !targetEnvironment(simulator)
    @State private var arPlace: Place?
    #endif

    private var allPlaces: [Place] {
        trip.allPlaces
    }

    private var daysWithRoutes: [TripDay] {
        trip.sortedDays.filter { !$0.routePoints.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, selection: $selectedPlace) {
                    ForEach(allPlaces) { place in
                        Annotation(
                            place.name,
                            coordinate: place.coordinate,
                            anchor: .bottom
                        ) {
                            placePin(place)
                        }
                        .tag(place)
                    }

                    if showRoutes {
                        ForEach(daysWithRoutes) { day in
                            let sortedPoints = day.routePoints.sorted { $0.timestamp < $1.timestamp }
                            let coords = sortedPoints.map(\.coordinate)
                            if coords.count >= 2 {
                                MapPolyline(coordinates: coords)
                                    .stroke(routeColor(for: day), lineWidth: 3)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant])))

                VStack(spacing: 0) {
                    if !daysWithRoutes.isEmpty {
                        routeStatsBar
                    }

                    if let place = selectedPlace {
                        selectedPlaceCard(place)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: selectedPlace?.id)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("КАРТА")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            zoomToAll()
                        } label: {
                            Label("Показать все", systemImage: "map")
                        }

                        Divider()

                        ForEach(uniqueCities, id: \.self) { city in
                            Button {
                                zoomToCity(city)
                            } label: {
                                Label(city, systemImage: "building.2")
                            }
                        }

                        if !daysWithRoutes.isEmpty {
                            Divider()
                            Button {
                                showRoutes.toggle()
                            } label: {
                                Label(
                                    showRoutes ? "Скрыть маршруты" : "Показать маршруты",
                                    systemImage: showRoutes ? "eye.slash" : "eye"
                                )
                            }
                        }

                        Divider()
                        Button {
                            showDiscoverNearby = true
                        } label: {
                            Label("Обзор", systemImage: "location.magnifyingglass")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            #if !targetEnvironment(simulator)
            .fullScreenCover(item: $arPlace) { place in
                ARNavigationView(place: place)
            }
            #endif
            .sheet(isPresented: $showDiscoverNearby) {
                if let coord = allPlaces.first?.coordinate {
                    DiscoverNearbyView(coordinate: coord)
                }
            }
        }
    }

    private var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName))).sorted()
    }

    // MARK: - Route Stats Bar

    private var routeStatsBar: some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: "figure.walk")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.bambooGreen)

            Text("\(daysWithRoutes.count) " + routeDaysWord(daysWithRoutes.count))
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(.primary)

            Capsule()
                .fill(.tertiary)
                .frame(width: 1, height: 16)

            Text(formatDistance(totalRouteDistance))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.bambooGreen)

            Spacer()

            Text("\(totalRoutePoints) ТОЧЕК")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.bambooGreen.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingXS)
    }

    private var totalRoutePoints: Int {
        daysWithRoutes.reduce(0) { $0 + $1.routePoints.count }
    }

    private var totalRouteDistance: Double {
        daysWithRoutes.reduce(0.0) { total, day in
            total + calculateDistance(for: day)
        }
    }

    private func calculateDistance(for day: TripDay) -> Double {
        let sorted = day.routePoints.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 2 else { return 0 }
        var distance: Double = 0
        for i in 1..<sorted.count {
            let prev = CLLocation(latitude: sorted[i-1].latitude, longitude: sorted[i-1].longitude)
            let curr = CLLocation(latitude: sorted[i].latitude, longitude: sorted[i].longitude)
            distance += curr.distance(from: prev)
        }
        return distance
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f KM", meters / 1000)
        }
        return "\(Int(meters)) M"
    }

    private func routeDaysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return "ТРЕКОВ" }
        if mod10 == 1 { return "ТРЕК" }
        if mod10 >= 2 && mod10 <= 4 { return "ТРЕКА" }
        return "ТРЕКОВ"
    }

    private func routeColor(for day: TripDay) -> Color {
        let dayColors: [Color] = [
            AppTheme.sakuraPink,
            AppTheme.oceanBlue,
            AppTheme.bambooGreen,
            AppTheme.templeGold,
            AppTheme.toriiRed,
        ]
        guard let index = trip.sortedDays.firstIndex(where: { $0.id == day.id }) else {
            return AppTheme.sakuraPink
        }
        return dayColors[index % dayColors.count]
    }

    // MARK: - Pin

    private func placePin(_ place: Place) -> some View {
        let pinColor = place.isVisited
            ? AppTheme.bambooGreen
            : AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(spacing: 2) {
            Image(systemName: place.category.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(pinColor)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .stroke(.white, lineWidth: 2)
                )
                .shadow(color: pinColor.opacity(0.4), radius: 4, y: 2)

            Circle()
                .fill(pinColor)
                .frame(width: 6, height: 6)
        }
        .onTapGesture {
            selectedPlace = place
        }
    }

    // MARK: - Selected Place Card

    private func selectedPlaceCard(_ place: Place) -> some View {
        let categoryColor = AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(place.nameLocal)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    selectedPlace = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
            }

            HStack(spacing: AppTheme.spacingS) {
                CategoryBadge(category: place.category)

                if place.isVisited {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("ПОСЕЩЕНО")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(AppTheme.bambooGreen)
                    .background(AppTheme.bambooGreen.opacity(0.1))
                    .clipShape(Capsule())
                }

                if let rating = place.rating {
                    StarRatingView(rating: rating)
                }
            }

            if !place.address.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(place.address)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }

            #if !targetEnvironment(simulator)
            Button {
                arPlace = place
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arkit")
                        .font(.system(size: 12, weight: .bold))
                    Text("AR НАВИГАЦИЯ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.indigoPurple)
                .clipShape(Capsule())
            }
            #endif

            if !place.notes.isEmpty {
                Text(place.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(
                    place.isVisited ? AppTheme.bambooGreen.opacity(0.3) : categoryColor.opacity(0.2),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    // MARK: - Camera Helpers

    private func zoomToAll() {
        let lats = allPlaces.map(\.latitude)
        let lons = allPlaces.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.5, 0.05)
        let spanLon = max((maxLon - minLon) * 1.5, 0.05)
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                )
            )
        }
    }

    private func zoomToCity(_ city: String) {
        let cityPlaces = trip.days
            .filter { $0.cityName == city }
            .flatMap(\.places)

        guard let first = cityPlaces.first else { return }

        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: first.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
    }
}

#if DEBUG
#Preview {
    TripMapView(trip: .preview)
        .modelContainer(.preview)
}
#endif
