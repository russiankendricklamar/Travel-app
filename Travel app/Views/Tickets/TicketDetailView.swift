import SwiftUI
import SwiftData

struct TicketDetailView: View {
    let ticket: Ticket
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var previousBrightness: CGFloat = 0.5
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                // Category header
                categoryHeader

                // Barcode section (white background for scanning)
                barcodeSection

                // Details
                detailsSection

                // Notes
                if !ticket.notes.isEmpty {
                    notesSection
                }

                // Delete button
                deleteButton
            }
            .padding(AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .sakuraGradientBackground()
        .navigationTitle(ticket.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddTicketSheet(trip: ticket.trip, editing: ticket)
        }
        .confirmationDialog("Удалить билет?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                modelContext.delete(ticket)
                dismiss()
            }
        }
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        .onDisappear {
            UIScreen.main.brightness = previousBrightness
        }
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: ticket.category.systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(ticket.category.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.category.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(ticket.category.color)
                Text(ticket.formattedDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if ticket.isExpired {
                Text("ИСТЁК")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.textSecondary)
                    .clipShape(Capsule())
            } else if ticket.isToday {
                Text("СЕГОДНЯ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ticket.category.color)
                    .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(ticket.category.color.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Barcode Section

    private var barcodeSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            Text(ticket.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

            if !ticket.venue.isEmpty {
                Text(ticket.venue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }

            if !ticket.seatInfo.isEmpty {
                Text(ticket.seatInfo)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
            }

            // Large barcode
            if let image = BarcodeService.generateBarcode(
                from: ticket.barcodeContent,
                type: ticket.barcodeType,
                size: CGSize(width: 300, height: ticket.barcodeType == .qr ? 300 : 100)
            ) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: ticket.barcodeType == .qr ? 250 : .infinity)
                    .frame(height: ticket.barcodeType == .qr ? 250 : 80)
                    .padding(AppTheme.spacingM)
            }

            Text(ticket.barcodeContent)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .padding(AppTheme.spacingL)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "ДЕТАЛИ", color: ticket.category.color)

            detailRow(icon: "calendar", label: "Дата", value: ticket.formattedDate)
            detailRow(icon: "clock", label: "Время", value: ticket.formattedTime)

            if !ticket.venue.isEmpty {
                detailRow(icon: "mappin.circle", label: "Место", value: ticket.venue)
            }
            if !ticket.seatInfo.isEmpty {
                detailRow(icon: "seat.airdrop", label: "Место/Ряд", value: ticket.seatInfo)
            }
            detailRow(icon: ticket.barcodeType.systemImage, label: "Штрихкод", value: ticket.barcodeType.rawValue)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(ticket.category.color.opacity(0.7))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, 4)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "ЗАМЕТКИ", color: AppTheme.templeGold)

            Text(ticket.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(AppTheme.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                Text("УДАЛИТЬ БИЛЕТ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(AppTheme.toriiRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.toriiRed.opacity(0.1))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.toriiRed.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}
