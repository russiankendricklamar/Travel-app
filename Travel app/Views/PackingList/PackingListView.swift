import SwiftUI
import SwiftData

struct PackingListView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext

    @State private var showAddSheet = false
    @State private var isGenerating = false

    private var sortedItems: [PackingItem] {
        trip.packingItems.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var groupedItems: [(category: PackingCategory, items: [PackingItem])] {
        PackingCategory.allCases.compactMap { cat in
            let items = sortedItems.filter { $0.category == cat.rawValue }
            guard !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    private var progressColor: Color {
        let progress = trip.packingProgress
        if progress >= 1.0 { return AppTheme.bambooGreen }
        if progress >= 0.5 { return AppTheme.templeGold }
        return AppTheme.toriiRed
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    progressHeader

                    if trip.packingItems.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedItems, id: \.category) { group in
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                GlassSectionHeader(
                                    title: group.category.label.uppercased(),
                                    color: AppTheme.sakuraPink
                                )
                                ForEach(group.items) { item in
                                    PackingItemRow(
                                        item: item,
                                        onToggle: {
                                            item.isPacked.toggle()
                                            try? modelContext.save()
                                        },
                                        onDelete: {
                                            modelContext.delete(item)
                                            try? modelContext.save()
                                        }
                                    )
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
                    Text("СПИСОК ВЕЩЕЙ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // Handled by parent dismiss
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            generateAISuggestions()
                        } label: {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.indigoPurple)
                            }
                        }
                        .disabled(isGenerating)

                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddPackingItemSheet(trip: trip)
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: AppTheme.spacingM) {
            ZStack {
                Circle()
                    .stroke(progressColor.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: trip.packingProgress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(trip.totalPacked)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(progressColor)
                    Text("/\(trip.packingItems.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("УПАКОВАНО")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)

                Text(packingStatusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(progressColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var packingStatusText: String {
        let progress = trip.packingProgress
        if trip.packingItems.isEmpty { return "Список пуст" }
        if progress >= 1.0 { return "Все собрано!" }
        if progress >= 0.7 { return "Почти готово" }
        if progress >= 0.3 { return "Собираем вещи..." }
        return "Начните собираться"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer(minLength: 40)

            Image(systemName: "bag.circle")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))

            Text("СПИСОК ПУСТ")
                .font(.system(size: 14, weight: .bold))
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("Добавьте вещи или сгенерируйте ИИ")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                Button {
                    showAddSheet = true
                } label: {
                    Text("ДОБАВИТЬ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppTheme.sakuraPink)
                        .clipShape(Capsule())
                }

                Button {
                    generateAISuggestions()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("ИИ")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.indigoPurple)
                    .clipShape(Capsule())
                }
            }

            Spacer(minLength: 40)
        }
    }

    // MARK: - AI Generation

    private func generateAISuggestions() {
        guard !isGenerating else { return }
        isGenerating = true
        Task {
            let suggestions = await PackingListAIService.shared.generateSuggestions(for: trip)
            for (index, suggestion) in suggestions.enumerated() {
                let existing = trip.packingItems.contains { $0.name.lowercased() == suggestion.name.lowercased() }
                guard !existing else { continue }
                let item = PackingItem(
                    name: suggestion.name,
                    category: suggestion.category.rawValue,
                    isAISuggested: true,
                    sortOrder: trip.packingItems.count + index
                )
                item.trip = trip
                modelContext.insert(item)
            }
            try? modelContext.save()
            isGenerating = false
        }
    }
}
