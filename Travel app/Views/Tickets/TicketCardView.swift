import SwiftUI

struct TicketCardView: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            // Header: category icon + date
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: ticket.category.systemImage)
                        .font(.system(size: 12, weight: .bold))
                    Text(ticket.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(ticket.isExpired ? .secondary : ticket.category.color)

                Spacer()

                Text(ticket.formattedDate)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Title + venue
            Text(ticket.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ticket.isExpired ? .secondary : .primary)
                .lineLimit(1)

            if !ticket.venue.isEmpty {
                Text(ticket.venue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Seat info
            if !ticket.seatInfo.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "seat.airdrop")
                        .font(.system(size: 10))
                    Text(ticket.seatInfo)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(ticket.category.color.opacity(0.8))
            }

            // Compact barcode preview
            HStack {
                Spacer()
                if let image = BarcodeService.generateBarcode(
                    from: ticket.barcodeContent,
                    type: ticket.barcodeType,
                    size: CGSize(width: 120, height: ticket.barcodeType == .qr ? 120 : 50)
                ) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(height: ticket.barcodeType == .qr ? 60 : 30)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
            }

            // Expiration badge
            if ticket.isExpired {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 9))
                    Text("ИСТЁК")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.textSecondary)
                .clipShape(Capsule())
            } else if ticket.isToday {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                    Text("СЕГОДНЯ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ticket.category.color)
                .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacingM)
        .opacity(ticket.isExpired ? 0.6 : 1.0)
        .accentBarCard(ticket.category.color)
    }
}
