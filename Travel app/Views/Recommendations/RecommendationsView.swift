import SwiftUI

struct RecommendationsView: View {
    let trip: Trip

    @State private var service = RecommendationService.shared
    @State private var selectedCategories: Set<String> = []
    @State private var selectedRecommendation: PlaceRecommendation?
    @State private var showDayPicker = false

    private let allCategories = [
        "Еда", "Культура", "Природа", "Шопинг", "Храм", "Святилище",
        "Музей", "Галерея", "Дворец", "Парк", "Сад", "Озеро", "Горы",
        "Спорт", "Стадион", "Смотровая"
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.spacingM) {
                // Category filter chips
                categoryFilters

                // Content
                if service.isLoading {
                    loadingState
                } else if let error = service.lastError {
                    errorState(error)
                } else if service.recommendations.isEmpty {
                    emptyState
                } else {
                    recommendationsList
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, AppTheme.spacingM)
        }
        .sakuraGradientBackground()
        .navigationTitle("Рекомендации")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchIfNeeded()
        }
        .onChange(of: selectedCategories) { _, _ in
            Task { await fetchIfNeeded() }
        }
        .sheet(isPresented: $showDayPicker) {
            if let rec = selectedRecommendation {
                DayPickerSheet(trip: trip, recommendation: rec)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allCategories, id: \.self) { category in
                    let isSelected = selectedCategories.contains(category)
                    Button {
                        if isSelected {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: iconFor(category))
                                .font(.system(size: 11, weight: .bold))
                            Text(category)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? AppTheme.sakuraPink.opacity(0.2)
                                : Color.white.opacity(0.001)
                        )
                        .background(isSelected ? AnyShapeStyle(.clear) : AnyShapeStyle(.ultraThinMaterial))
                        .foregroundStyle(isSelected ? AppTheme.sakuraPink : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Recommendations List

    private var recommendationsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(service.recommendations) { rec in
                RecommendationCard(recommendation: rec) {
                    selectedRecommendation = rec
                    showDayPicker = true
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.sakuraPink)
            Text("ИИ подбирает места...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.templeGold)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await fetchIfNeeded() }
            } label: {
                Text("Повторить")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.sakuraPink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
            Text("Нажмите для загрузки рекомендаций")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func fetchIfNeeded() async {
        let city = trip.days.first?.cityName ?? trip.countriesDisplay
        await service.fetchRecommendations(
            city: city,
            categories: selectedCategories.isEmpty ? Set(allCategories) : selectedCategories
        )
    }

    private func iconFor(_ category: String) -> String {
        switch category {
        case "Еда": return "fork.knife"
        case "Культура": return "theatermasks"
        case "Природа": return "leaf"
        case "Шопинг": return "bag"
        case "Храм": return "building.columns"
        case "Святилище": return "sparkles"
        case "Музей": return "building.columns.fill"
        case "Галерея": return "photo.artframe"
        case "Дворец": return "crown.fill"
        case "Парк": return "tree.fill"
        case "Сад": return "camera.macro"
        case "Озеро": return "water.waves"
        case "Горы": return "mountain.2.fill"
        case "Спорт": return "figure.run"
        case "Стадион": return "sportscourt.fill"
        case "Смотровая": return "binoculars.fill"
        default: return "mappin"
        }
    }
}
