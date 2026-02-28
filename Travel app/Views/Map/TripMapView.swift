import SwiftUI
import MapKit

struct TripMapView: View {
    let store: TripStore

    @State private var selectedPlace: Place?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
    )

    private var allPlaces: [Place] {
        store.allPlaces
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
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant])))

                if let place = selectedPlace {
                    selectedPlaceCard(place)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: selectedPlace?.id)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                        Text("КАРТА")
                            .font(.system(size: 14, weight: .black))
                            .tracking(4)
                            .foregroundStyle(AppTheme.textPrimary)
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            zoomToAll()
                        } label: {
                            Label("Показать все", systemImage: "map")
                        }

                        Button {
                            zoomToCity("Токио")
                        } label: {
                            Label("Токио", systemImage: "building.2")
                        }

                        Button {
                            zoomToCity("Киото")
                        } label: {
                            Label("Киото", systemImage: "building.columns")
                        }

                        Button {
                            zoomToCity("Осака")
                        } label: {
                            Label("Осака", systemImage: "fork.knife")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
        }
    }

    // MARK: - Pin

    private func placePin(_ place: Place) -> some View {
        let pinColor = place.isVisited
            ? AppTheme.bambooGreen
            : AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(spacing: 0) {
            ZStack {
                Image(systemName: place.category.systemImage)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(pinColor)
                    .overlay(
                        Rectangle()
                            .stroke(.white, lineWidth: 2)
                    )
                    .shadow(color: pinColor.opacity(0.4), radius: 4, y: 2)
            }

            Rectangle()
                .fill(pinColor)
                .frame(width: 4, height: 8)
        }
        .onTapGesture {
            selectedPlace = place
        }
    }

    // MARK: - Selected Place Card

    private func selectedPlaceCard(_ place: Place) -> some View {
        let categoryColor = AppTheme.categoryColor(for: place.category.rawValue)

        return VStack(spacing: 0) {
            Rectangle()
                .fill(place.isVisited ? AppTheme.bambooGreen : categoryColor)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(place.nameJapanese)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    Spacer()

                    Button {
                        selectedPlace = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.surface)
                            .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))
                    }
                }

                HStack(spacing: AppTheme.spacingS) {
                    CategoryBadge(category: place.category)

                    if place.isVisited {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("ПОСЕЩЕНО")
                                .font(.system(size: 9, weight: .black))
                                .tracking(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(AppTheme.bambooGreen)
                        .background(AppTheme.bambooGreen.opacity(0.1))
                        .overlay(Rectangle().stroke(AppTheme.bambooGreen.opacity(0.3), lineWidth: 1))
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
                    .foregroundStyle(AppTheme.textSecondary)
                }

                if !place.notes.isEmpty {
                    Text(place.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(AppTheme.spacingM)
        }
        .background(AppTheme.card)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    // MARK: - Camera Helpers

    private func zoomToAll() {
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 35.0, longitude: 136.0),
                    span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 6.0)
                )
            )
        }
    }

    private func zoomToCity(_ city: String) {
        let cityPlaces = store.days
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

// MARK: - Place Equatable for selection

extension Place: Hashable {
    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    TripMapView(store: TripStore())
}
