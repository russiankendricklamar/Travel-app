import SwiftUI
import SwiftData

struct ItineraryView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddDaySheet = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    @State private var isEditMode = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(trip.sortedDays.enumerated()), id: \.element.id) { index, day in
                    NavigationLink(value: day.id) {
                        dayCard(day, index: index)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(day)
                        } label: {
                            Label("Удалить день", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .onMove { from, to in
                    moveDays(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, isEditMode ? .constant(.active) : .constant(.inactive))
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("МАРШРУТ")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isEditMode.toggle()
                            }
                        } label: {
                            Image(systemName: isEditMode ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isEditMode ? AppTheme.bambooGreen : .secondary)
                        }
                        Button {
                            showingAddDaySheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { dayId in
                if let day = trip.days.first(where: { $0.id == dayId }) {
                    DayDetailView(trip: trip, day: day)
                }
            }
            .sheet(isPresented: $showingAddDaySheet) {
                AddDaySheet(trip: trip)
            }
        }
    }

    private func dayCard(_ day: TripDay, index: Int) -> some View {
        let isToday = day.isToday
        let isPast = day.isPast

        return HStack(spacing: 0) {
            // Day number — flush with card left edge
            VStack(spacing: 2) {
                if isToday {
                    Text("СЕЙЧАС")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                } else {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(isPast ? Color.secondary.opacity(0.5) : AppTheme.sakuraPink)
                }
                if !isToday {
                    Text("ДЕНЬ")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 56)
            .frame(maxHeight: .infinity)
            .background(isToday ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(isPast ? 0.04 : 0.08))

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(dateFormatter.string(from: day.date).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(.tertiary)

                            if isToday {
                                Text("СЕГОДНЯ")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(.white)
                                    .background(AppTheme.sakuraPink)
                                    .clipShape(Capsule())
                            }

                            if isPast {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.bambooGreen)
                            }
                        }

                        Text(day.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isPast ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(day.cityName.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(AppTheme.oceanBlue.opacity(isPast ? 0.5 : 1))
                            .clipShape(Capsule())

                        Text("\(day.visitedCount)/\(day.places.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(day.visitedCount == day.places.count && !day.places.isEmpty
                                ? AppTheme.bambooGreen
                                : .secondary)
                    }
                }

                if !day.places.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(day.places.prefix(5)) { place in
                            Image(systemName: place.category.systemImage)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(
                                    place.isVisited
                                        ? AppTheme.bambooGreen
                                        : AppTheme.categoryColor(for: place.category.rawValue)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        if day.places.count > 5 {
                            Text("+\(day.places.count - 5)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                }

                if !day.notes.isEmpty {
                    Text(day.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.thinMaterial)
                            .frame(height: 4)

                        let progress = day.places.isEmpty ? 0.0 : Double(day.visitedCount) / Double(day.places.count)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(dayAccentColor(day))
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(AppTheme.spacingM)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(
                    isToday ? AppTheme.sakuraPink.opacity(0.4) : Color.white.opacity(0.2),
                    lineWidth: isToday ? 1.5 : 0.5
                )
        )
        .shadow(color: isToday ? AppTheme.sakuraPink.opacity(0.1) : .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        var ordered = trip.sortedDays
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, day) in ordered.enumerated() {
            day.sortOrder = i
        }
        try? modelContext.save()
    }

    private func dayAccentColor(_ day: TripDay) -> Color {
        if day.isToday { return AppTheme.sakuraPink }
        guard !day.places.isEmpty else { return .secondary }
        let progress = Double(day.visitedCount) / Double(day.places.count)
        if progress >= 1.0 { return AppTheme.bambooGreen }
        if progress > 0 { return AppTheme.sakuraPink }
        return .secondary
    }
}

#if DEBUG
#Preview {
    ItineraryView(trip: .preview)
        .modelContainer(.preview)
}
#endif
