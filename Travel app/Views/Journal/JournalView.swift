import SwiftUI
import SwiftData

struct JournalView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false

    private var sortedEntries: [JournalEntry] {
        trip.journalEntries.sorted { $0.date > $1.date }
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMM"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                if sortedEntries.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: AppTheme.spacingM) {
                        ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                            journalCard(entry, index: index)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        modelContext.delete(entry)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.bottom, AppTheme.spacingXL)
                }
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Rectangle().fill(AppTheme.sakuraPink).frame(width: 12, height: 3)
                        Text("ДНЕВНИК")
                            .font(.system(size: 14, weight: .black))
                            .tracking(4)
                            .foregroundStyle(AppTheme.textPrimary)
                        Rectangle().fill(AppTheme.sakuraPink).frame(width: 12, height: 3)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddJournalEntrySheet(trip: trip)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            ZStack {
                Rectangle().fill(AppTheme.sakuraPink.opacity(0.15)).frame(width: 90, height: 90).offset(x: 4, y: 4)
                VStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                .frame(width: 90, height: 90)
                .background(AppTheme.card)
                .overlay(Rectangle().stroke(AppTheme.sakuraPink, lineWidth: 3))
            }
            Spacer(minLength: 24)
            Text("ПОКА НЕТ ЗАПИСЕЙ")
                .font(.system(size: 14, weight: .black)).tracking(4).foregroundStyle(AppTheme.textPrimary)
            Text("Начните писать о путешествии по Японии")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(AppTheme.textMuted).padding(.top, 6)
            Spacer(minLength: 24)
            Button { showingAddSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line").font(.system(size: 14, weight: .bold))
                    Text("ПЕРВАЯ ЗАПИСЬ").font(.system(size: 12, weight: .black)).tracking(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(AppTheme.sakuraPink)
            }
            Spacer(minLength: 100)
        }
    }

    private func journalCard(_ entry: JournalEntry, index: Int) -> some View {
        let moodColor = AppTheme.moodColor(for: entry.mood)
        return VStack(spacing: 0) {
            Rectangle().fill(moodColor).frame(height: 4)
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: entry.mood.systemImage).font(.system(size: 16, weight: .bold)).foregroundStyle(moodColor)
                        Text(entry.mood.rawValue.uppercased()).font(.system(size: 10, weight: .black)).tracking(1).foregroundStyle(moodColor)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(moodColor.opacity(0.1))
                    .overlay(Rectangle().stroke(moodColor.opacity(0.3), lineWidth: 1))
                    Spacer()
                    Text(String(format: "#%02d", index + 1))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.textMuted.opacity(0.4))
                }
                Text(dateFormatter.string(from: entry.date).uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(AppTheme.textMuted)
                Text(entry.title).font(.system(size: 17, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
                Text(entry.content).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary).lineLimit(4).lineSpacing(4)
            }
            .padding(AppTheme.spacingM)
        }
        .background(AppTheme.card)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
    }
}

#if DEBUG
#Preview {
    JournalView(trip: .preview).modelContainer(.preview)
}
#endif
