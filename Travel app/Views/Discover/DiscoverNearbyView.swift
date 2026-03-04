import SwiftUI
import SwiftData
import CoreLocation

struct DiscoverNearbyView: View {
    var day: TripDay?
    var coordinate: CLLocationCoordinate2D?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: GooglePOICategory = .restaurant
    @State private var results: [POIResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDayPicker = false
    @State private var addingResult: POIResult?

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
                                POIResultCard(result: result) {
                                    addToItinerary(result)
                                }
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
                ForEach(GooglePOICategory.allCases) { cat in
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
            errorMessage = "Нет координат для поиска"
            return
        }
        guard GooglePlacesService.shared.hasApiKey else {
            errorMessage = "Добавьте Google Places API-ключ в настройках"
            return
        }
        isLoading = true
        errorMessage = nil
        results = await GooglePlacesService.shared.searchNearby(coordinate: coord, category: selectedCategory)
        if results.isEmpty && GooglePlacesService.shared.errorMessage != nil {
            errorMessage = GooglePlacesService.shared.errorMessage
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

    private func placeCategory(for poiCat: GooglePOICategory) -> PlaceCategory {
        switch poiCat {
        case .restaurant, .cafe: return .food
        case .museum: return .culture
        case .shopping: return .shopping
        case .attraction: return .culture
        }
    }
}
