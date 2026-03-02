import SwiftUI

struct DashboardTicketsSection: View {
    let trip: Trip

    private var upcomingTickets: [Ticket] {
        trip.tickets
            .filter { $0.isUpcoming }
            .sorted { $0.eventDate < $1.eventDate }
    }

    private var nextTicket: Ticket? {
        upcomingTickets.first
    }

    @State private var showAddTicket = false

    var body: some View {
        NavigationLink(destination: TicketsListView(trip: trip)) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().opacity(0.15).padding(.horizontal, AppTheme.spacingM)
                if let ticket = nextTicket {
                    ticketPreview(ticket)
                } else {
                    emptyState
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Нет билетов")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Добавьте билеты на мероприятия")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, AppTheme.spacingM)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("БИЛЕТЫ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(AppTheme.sakuraPink)
            }
            Spacer()
            if upcomingTickets.count > 1 {
                Text("\(upcomingTickets.count) шт.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingM)
    }

    // MARK: - Ticket Preview

    private func ticketPreview(_ ticket: Ticket) -> some View {
        HStack(spacing: AppTheme.spacingS) {
            // Category icon
            Image(systemName: ticket.category.systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(ticket.category.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(ticket.formattedDate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    if ticket.isToday {
                        Text("СЕГОДНЯ")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ticket.category.color)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Mini barcode
            if let image = BarcodeService.generateBarcode(
                from: ticket.barcodeContent,
                type: ticket.barcodeType,
                size: CGSize(width: 80, height: ticket.barcodeType == .qr ? 80 : 30)
            ) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .padding(4)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, AppTheme.spacingS)
        .padding(.bottom, AppTheme.spacingS)
    }
}
