import SwiftUI
import SwiftData

struct AddTicketSheet: View {
    let trip: Trip?
    var day: TripDay?
    var editing: Ticket?
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var venue = ""
    @State private var category: TicketCategory = .other
    @State private var barcodeType: BarcodeType = .qr
    @State private var barcodeContent = ""
    @State private var eventDate = Date()
    @State private var seatInfo = ""
    @State private var notes = ""
    @State private var showScanner = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !barcodeContent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "ticket",
                        title: editing != nil ? "РЕДАКТИРОВАТЬ БИЛЕТ" : "НОВЫЙ БИЛЕТ",
                        color: AppTheme.sakuraPink
                    )

                    // Title
                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("F1 Гран-при Сузука", text: $title)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    // Venue
                    GlassFormField(label: "МЕСТО ПРОВЕДЕНИЯ", color: AppTheme.oceanBlue) {
                        TextField("Suzuka Circuit", text: $venue)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    // Category
                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.templeGold) {
                        categoryPicker
                    }

                    // Date
                    GlassFormField(label: "ДАТА И ВРЕМЯ", color: AppTheme.bambooGreen) {
                        DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                    }

                    // Seat info
                    GlassFormField(label: "МЕСТО / РЯД", color: .secondary) {
                        TextField("Трибуна B, Ряд 12, Место 45", text: $seatInfo)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    // Barcode section
                    barcodeSection

                    // Notes
                    GlassFormField(label: "ЗАМЕТКИ", color: .secondary) {
                        TextField("Дополнительная информация...", text: $notes)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ОТМЕНА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : .secondary)
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { scannedCode in
                    barcodeContent = scannedCode
                    showScanner = false
                }
            }
            .onAppear {
                if let t = editing {
                    title = t.title
                    venue = t.venue
                    category = t.category
                    barcodeType = t.barcodeType
                    barcodeContent = t.barcodeContent
                    eventDate = t.eventDate
                    seatInfo = t.seatInfo
                    notes = t.notes
                }
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(TicketCategory.allCases), id: \.self) { cat in
                    Button {
                        category = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.systemImage)
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(category == cat ? .white : .secondary)
                        .background(category == cat ? cat.color : .clear)
                        .background { if category != cat { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                category == cat ? cat.color.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Barcode Section

    private var barcodeSection: some View {
        GlassFormField(label: "ШТРИХКОД", color: AppTheme.indigoPurple) {
            VStack(spacing: AppTheme.spacingS) {
                // Barcode type picker
                HStack(spacing: 8) {
                    ForEach(BarcodeType.allCases) { type in
                        Button {
                            barcodeType = type
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 12, weight: .bold))
                                Text(type.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(barcodeType == type ? .white : .secondary)
                            .background(barcodeType == type ? AppTheme.indigoPurple : .clear)
                            .background { if barcodeType != type { Color.clear.background(.ultraThinMaterial) } }
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    barcodeType == type ? AppTheme.indigoPurple.opacity(0.5) : Color.white.opacity(0.2),
                                    lineWidth: 0.5
                                )
                            )
                        }
                    }
                    Spacer()
                }

                // Manual input
                TextField("Содержимое штрихкода...", text: $barcodeContent)
                    .textFieldStyle(GlassTextFieldStyle())

                // Scan button
                Button {
                    showScanner = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("СКАНИРОВАТЬ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.indigoPurple)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }

                // Preview
                if !barcodeContent.isEmpty {
                    if let image = BarcodeService.generateBarcode(
                        from: barcodeContent,
                        type: barcodeType,
                        size: CGSize(width: 200, height: barcodeType == .qr ? 200 : 80)
                    ) {
                        VStack(spacing: 4) {
                            Text("ПРЕВЬЮ")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.tertiary)
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(height: barcodeType == .qr ? 120 : 50)
                                .padding(AppTheme.spacingS)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        if let t = editing {
            t.title = title.trimmingCharacters(in: .whitespaces)
            t.venue = venue.trimmingCharacters(in: .whitespaces)
            t.category = category
            t.barcodeType = barcodeType
            t.barcodeContent = barcodeContent.trimmingCharacters(in: .whitespaces)
            t.eventDate = eventDate
            t.seatInfo = seatInfo.trimmingCharacters(in: .whitespaces)
            t.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let ticket = Ticket(
                title: title.trimmingCharacters(in: .whitespaces),
                venue: venue.trimmingCharacters(in: .whitespaces),
                category: category,
                barcodeType: barcodeType,
                barcodeContent: barcodeContent.trimmingCharacters(in: .whitespaces),
                eventDate: eventDate,
                seatInfo: seatInfo.trimmingCharacters(in: .whitespaces),
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            trip?.tickets.append(ticket)
            day?.tickets.append(ticket)
        }
        dismiss()
    }
}
