import SwiftUI
import SwiftData

struct JournalView: View {
    let trip: Trip
    @State private var showingAddEntry = false

    private var daysWithEntries: [TripDay] {
        trip.sortedDays.filter { !$0.journalEntries.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorPalette.current.backgroundColors.first?.ignoresSafeArea()

                LinearGradient(
                    colors: ColorPalette.current.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        if daysWithEntries.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: AppTheme.spacingL) {
                                ForEach(daysWithEntries) { day in
                                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                        JournalDaySection(day: day)
                                        ForEach(day.journalEntries.sorted(by: { $0.timestamp < $1.timestamp })) { entry in
                                            JournalEntryCard(entry: entry)
                                        }
                                    }
                                }
                            }
                            .padding(.top, AppTheme.spacingS)
                            .padding(.bottom, AppTheme.spacingXL)
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ДНЕВНИК")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.indigoPurple)
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                if let today = trip.todayDay ?? trip.sortedDays.last {
                    AddJournalEntrySheet(day: today)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Записей пока нет")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Отмечайте места посещёнными\nчтобы создавать записи")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
}
