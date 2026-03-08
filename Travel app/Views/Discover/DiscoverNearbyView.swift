import SwiftUI
import SwiftData
import CoreLocation
import MapKit

enum POICategory: String, CaseIterable, Identifiable {
    case restaurant
    case attraction
    case museum
    case shopping
    case cafe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .restaurant: return String(localized: "Рестораны")
        case .attraction: return String(localized: "Достопримечательности")
        case .museum: return String(localized: "Музеи")
        case .shopping: return String(localized: "Шопинг")
        case .cafe: return String(localized: "Кафе")
        }
    }

    var systemImage: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .attraction: return "star.fill"
        case .museum: return "building.columns"
        case .shopping: return "bag.fill"
        case .cafe: return "cup.and.saucer.fill"
        }
    }

    var searchQuery: String {
        switch self {
        case .restaurant: return "restaurant"
        case .attraction: return "tourist attraction"
        case .museum: return "museum"
        case .shopping: return "shopping"
        case .cafe: return "cafe"
        }
    }
}

struct POIResult: Identifiable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: MKPointOfInterestCategory?
    let distanceMeters: Double?
}

struct DiscoverNearbyView: View {
    var day: TripDay?
    var coordinate: CLLocationCoordinate2D?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: POICategory = .restaurant
    @State private var results: [POIResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var searchCoordinate: CLLocationCoordinate2D? {
        if let coordinate { return coordinate }
        if let day, let firstPlace = day.places.first {
            return firstPlace.coordinate
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    categoryChips

                    if isLoading {
                        ProgressView()
                            .padding(AppTheme.spacingXL)
                    } else if let error = errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.toriiRed.opacity(0.5))
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(AppTheme.spacingXL)
                    } else if results.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 28))
                                .foregroundStyle(.tertiary)
                            Text("Ничего не найдено")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(AppTheme.spacingXL)
                    } else {
                        LazyVStack(spacing: AppTheme.spacingS) {
                            ForEach(results) { result in
                                POIResultCard(result: result, categoryIcon: selectedCategory.systemImage, onAdd: day != nil ? { addToItinerary(result) } : nil)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("РЯДОМ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task { await search() }
            .onChange(of: selectedCategory) { _, _ in
                Task { await search() }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(POICategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedCategory = cat }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.systemImage)
                                .font(.system(size: 11, weight: .bold))
                            Text(cat.label)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .background(isSelected ? AppTheme.sakuraPink : Color.clear)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                    }
                }
            }
        }
    }

    private func search() async {
        guard let coord = searchCoordinate else {
            errorMessage = String(localized: "Нет координат для поиска")
            return
        }
        isLoading = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = selectedCategory.searchQuery
        request.region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let origin = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

            results = response.mapItems.prefix(20).map { item in
                let loc = item.placemark.location
                let distance = loc.map { origin.distance(from: $0) }
                return POIResult(
                    id: UUID().uuidString,
                    name: item.name ?? "",
                    address: [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality]
                        .compactMap { $0 }.joined(separator: ", "),
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude,
                    category: item.pointOfInterestCategory,
                    distanceMeters: distance
                )
            }.sorted { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }

            if results.isEmpty {
                errorMessage = "Ничего не найдено поблизости"
            }
        } catch {
            errorMessage = "Не удалось выполнить поиск"
        }

        isLoading = false
    }

    private func addToItinerary(_ result: POIResult) {
        guard let targetDay = day else { return }
        let place = Place(
            name: result.name,
            nameLocal: "",
            category: placeCategory(for: selectedCategory),
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude
        )
        targetDay.places.append(place)
        try? modelContext.save()
    }

    private func placeCategory(for poiCat: POICategory) -> PlaceCategory {
        switch poiCat {
        case .restaurant, .cafe: return .food
        case .museum: return .culture
        case .shopping: return .shopping
        case .attraction: return .culture
        }
    }
}
