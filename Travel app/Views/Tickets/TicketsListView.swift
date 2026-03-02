import SwiftUI
import SwiftData

struct TicketsListView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext

    @State private var showAddTicket = false
    @State private var filter: TicketFilter = .upcoming

    private var filteredTickets: [Ticket] {
        let sorted = trip.tickets.sorted { $0.eventDate < $1.eventDate }
        switch filter {
        case .upcoming:
            return sorted.filter { $0.isUpcoming }
        case .past:
            return sorted.filter { !$0.isUpcoming }
        case .all:
            return sorted
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                // Filter pills
                filterBar

                if filteredTickets.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredTickets) { ticket in
                        NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                            TicketCardView(ticket: ticket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .sakuraGradientBackground()
        .navigationTitle("Билеты")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTicket = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
        .sheet(isPresented: $showAddTicket) {
            AddTicketSheet(trip: trip)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(TicketFilter.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filter = option
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(filter == option ? .white : .secondary)
                        .background(filter == option ? AppTheme.sakuraPink : .clear)
                        .background { if filter != option { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                filter == option ? AppTheme.sakuraPink.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                }
            }
            Spacer()
        }
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Image(systemName: "ticket")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("НЕТ БИЛЕТОВ")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("Добавьте билеты на мероприятия,\nтранспорт или экскурсии")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingXL * 2)
    }
}

// MARK: - Ticket Filter

enum TicketFilter: CaseIterable {
    case upcoming, past, all

    var label: String {
        switch self {
        case .upcoming: return "ПРЕДСТОЯЩИЕ"
        case .past: return "ПРОШЕДШИЕ"
        case .all: return "ВСЕ"
        }
    }
}
