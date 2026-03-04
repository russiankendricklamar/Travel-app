import SwiftUI
import SwiftData
import MapKit
import Combine

struct AddBucketItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var category: PlaceCategory = .culture
    @State private var notes = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?

    @StateObject private var searchCompleter = LocationSearchCompleter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "bookmark.fill", title: "НОВОЕ ЖЕЛАНИЕ", color: AppTheme.sakuraPink)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Эйфелева башня", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "НАПРАВЛЕНИЕ", color: AppTheme.oceanBlue) {
                        TextField("Париж, Франция", text: $destination)
                            .textFieldStyle(GlassTextFieldStyle())
                            .onChange(of: destination) { _, newValue in
                                searchCompleter.search(query: newValue)
                            }
                    }

                    if !searchCompleter.results.isEmpty && !destination.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchCompleter.results.prefix(3), id: \.self) { result in
                                Button {
                                    destination = result.title
                                    searchCompleter.results = []
                                    resolveCoordinate(for: result)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppTheme.oceanBlue)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(result.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.primary)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }

                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.templeGold) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PlaceCategory.allCases) { cat in
                                    let isSelected = category == cat
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { category = cat }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: cat.systemImage)
                                                .font(.system(size: 11, weight: .bold))
                                            Text(cat.rawValue)
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

                    GlassFormField(label: "ЗАМЕТКИ", color: .secondary) {
                        TextField("Чем привлекает?", text: $notes)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ОТМЕНА") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ДОБАВИТЬ") { save() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                        .disabled(!isValid)
                        .opacity(isValid ? 1.0 : 0.4)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let item = BucketListItem(
            name: name.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            notes: notes.trimmingCharacters(in: .whitespaces),
            latitude: selectedLatitude,
            longitude: selectedLongitude
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }

    private func resolveCoordinate(for completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            if let item = response?.mapItems.first {
                selectedLatitude = item.placemark.coordinate.latitude
                selectedLongitude = item.placemark.coordinate.longitude
            }
        }
    }
}

final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently ignore search errors
    }
}
