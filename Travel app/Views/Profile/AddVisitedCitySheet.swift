import SwiftUI
import MapKit
import Combine

struct AddVisitedCitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = CitySearchModel()
    @State private var searchText = ""

    let onAdd: (VisitedCity) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Поиск города...", text: $searchText)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
                .onChange(of: searchText) { _, newValue in
                    searchModel.update(query: newValue)
                }

                // Results
                if searchModel.results.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Ничего не найдено")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchModel.results, id: \.self) { completion in
                                Button {
                                    selectCity(completion)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(AppTheme.bambooGreen)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.primary)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, AppTheme.spacingM)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                        .padding(.top, AppTheme.spacingS)
                    }
                }
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ДОБАВИТЬ ГОРОД")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.bambooGreen)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func selectCity(_ completion: MKLocalSearchCompletion) {
        Task {
            let request = MKLocalSearch.Request(completion: completion)
            request.resultTypes = .address
            let search = MKLocalSearch(request: request)
            guard let response = try? await search.start(),
                  let item = response.mapItems.first else { return }

            let city = VisitedCity(
                name: completion.title,
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )

            await MainActor.run {
                onAdd(city)
                dismiss()
            }
        }
    }
}

// MARK: - City Search Model

private final class CitySearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
