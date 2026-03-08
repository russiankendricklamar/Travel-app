import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct BookingScannerSheet: View {
    let onFlightsAdded: ([ScannedFlight]) -> Void
    var onBookingsAdded: (([ScannedBooking]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var state: ScanState = .idle
    @State private var inputMode: InputMode = .photo
    @State private var pasteText = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPDFPicker = false
    @State private var scannedFlights: [ScannedFlight] = []
    @State private var selectedFlightIDs: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var emailService = EmailScannerService.shared
    @State private var selectedBookingIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "doc.text.viewfinder",
                        title: "СКАНИРОВАТЬ БРОНЬ",
                        color: AppTheme.sakuraPink
                    )

                    switch state {
                    case .idle:
                        inputSection
                    case .processing:
                        processingSection
                    case .results:
                        resultsSection
                    case .error:
                        errorSection
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ЗАКРЫТЬ") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
            .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url):
                    Task { await processPDF(url) }
                case .failure:
                    errorMessage = "Не удалось открыть файл"
                    withAnimation { state = .error }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    if let image {
                        Task { await processImage(image) }
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAndProcess(item: newItem) }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Mode picker
            modePicker

            switch inputMode {
            case .photo:
                photoInput
            case .camera:
                cameraInput
            case .text:
                textInput
            case .pdf:
                pdfInput
            case .email:
                emailSection
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { inputMode = mode }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18))
                        Text(mode.label)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(inputMode == mode ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        inputMode == mode
                            ? AnyShapeStyle(AppTheme.sakuraPink)
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var photoInput: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("ВЫБРАТЬ ФОТО")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("Скриншот подтверждения бронирования")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private var cameraInput: some View {
        Button {
            showCamera = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("СФОТОГРАФИРОВАТЬ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("Наведите камеру на подтверждение")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private var textInput: some View {
        VStack(spacing: AppTheme.spacingS) {
            TextEditor(text: $pasteText)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if pasteText.isEmpty {
                        Text("Вставьте текст подтверждения бронирования...")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                Task { await processText() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                    Text("РАСПОЗНАТЬ РЕЙСЫ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(pasteText.isEmpty ? AppTheme.sakuraPink.opacity(0.4) : AppTheme.sakuraPink)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(pasteText.isEmpty)
        }
    }

    private var pdfInput: some View {
        Button {
            showPDFPicker = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("ВЫБРАТЬ PDF")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("PDF-подтверждение от авиакомпании")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Email Section

    private var emailSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            switch emailService.state {
            case .idle:
                emailProviderPicker
            case .authorizing:
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(AppTheme.sakuraPink)
                    Text("Авторизация...").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 60)
            case .searching:
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(AppTheme.sakuraPink)
                    Text("Ищем бронирования в почте...").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 60)
            case .selectEmails:
                emailSelectionList
            case .parsing:
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(AppTheme.sakuraPink)
                    Text("Распознаю бронирования...").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 60)
            case .results:
                bookingResultsList
            case .error(let msg):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 36, weight: .light)).foregroundStyle(AppTheme.toriiRed)
                    Text(msg).font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        emailService.reset()
                    } label: {
                        Text("ПОПРОБОВАТЬ СНОВА").font(.system(size: 11, weight: .bold)).tracking(1)
                            .foregroundStyle(AppTheme.sakuraPink).padding(.vertical, 12).padding(.horizontal, 24)
                            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }.buttonStyle(.plain)
                }.frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
    }

    private var emailProviderPicker: some View {
        VStack(spacing: AppTheme.spacingS) {
            ForEach(EmailScannerService.Provider.allCases, id: \.self) { provider in
                Button {
                    Task { await emailService.scan(provider: provider) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: provider.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(provider.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.label)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Поиск бронирований за 3 месяца")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(AppTheme.spacingM)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusMedium).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }.buttonStyle(.plain)
            }
        }
    }

    private var emailSelectionList: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack {
                Text("НАЙДЕННЫЕ ПИСЬМА").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                Text("\(emailService.foundEmails.count)").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.sakuraPink)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(AppTheme.sakuraPink.opacity(0.15)).clipShape(Capsule())
            }

            ForEach(emailService.foundEmails.indices, id: \.self) { index in
                let email = emailService.foundEmails[index]
                Button {
                    emailService.foundEmails[index].isSelected.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: email.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(email.isSelected ? AnyShapeStyle(AppTheme.sakuraPink) : AnyShapeStyle(.tertiary))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(email.subject).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary).lineLimit(2)
                            HStack(spacing: 8) {
                                Text(email.from.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespaces) ?? email.from)
                                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                Text(email.date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(AppTheme.spacingM).background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(email.isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.clear, lineWidth: 1))
                }.buttonStyle(.plain)
            }

            let selectedCount = emailService.foundEmails.filter(\.isSelected).count
            HStack(spacing: 12) {
                Button { emailService.reset() } label: {
                    Text("ОТМЕНА").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }.buttonStyle(.plain)

                Button { Task { await emailService.parseSelectedEmails() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 14))
                        Text("РАСПОЗНАТЬ (\(selectedCount))").font(.system(size: 11, weight: .bold)).tracking(1)
                    }.foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(selectedCount > 0 ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }.buttonStyle(.plain).disabled(selectedCount == 0)
            }
        }
    }

    private var bookingResultsList: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack {
                Text("БРОНИРОВАНИЯ").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                Text("\(emailService.scannedBookings.count)").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.sakuraPink)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(AppTheme.sakuraPink.opacity(0.15)).clipShape(Capsule())
            }

            ForEach(emailService.scannedBookings) { booking in
                let isSelected = selectedBookingIDs.contains(booking.id)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isSelected { selectedBookingIDs.remove(booking.id) } else { selectedBookingIDs.insert(booking.id) }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? AnyShapeStyle(AppTheme.sakuraPink) : AnyShapeStyle(.tertiary))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: booking.type.icon).font(.system(size: 12)).foregroundStyle(AppTheme.sakuraPink)
                                Text(booking.title).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.primary)
                            }
                            if let subtitle = booking.subtitle {
                                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                Text(booking.type.label).font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(AppTheme.sakuraPink.opacity(0.15))
                                    .clipShape(Capsule()).foregroundStyle(AppTheme.sakuraPink)
                                if let date = booking.date {
                                    Text(date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                                }
                                if let price = booking.price, let curr = booking.currency {
                                    Text("\(Int(price)) \(curr)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(AppTheme.spacingM).background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.clear, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            .onAppear { selectedBookingIDs = Set(emailService.scannedBookings.map(\.id)) }

            HStack(spacing: 12) {
                Button { emailService.reset(); selectedBookingIDs = [] } label: {
                    Text("ЗАНОВО").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14).background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }.buttonStyle(.plain)

                Button {
                    let selected = emailService.scannedBookings.filter { selectedBookingIDs.contains($0.id) }
                    let toAdd = selected.isEmpty ? emailService.scannedBookings : selected
                    let flights = toAdd.compactMap { $0.toScannedFlight() }
                    let others = toAdd.filter { $0.type != .flight }
                    if !flights.isEmpty { onFlightsAdded(flights) }
                    if !others.isEmpty { onBookingsAdded?(others) }
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 14))
                        Text(selectedBookingIDs.isEmpty ? "ДОБАВИТЬ ВСЕ" : "ДОБАВИТЬ (\(selectedBookingIDs.count))")
                            .font(.system(size: 11, weight: .bold)).tracking(1)
                    }.foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppTheme.sakuraPink).clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Processing

    private var processingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.sakuraPink)
            Text("Распознаю рейсы...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack {
                Text("НАЙДЕННЫЕ РЕЙСЫ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                Text("\(scannedFlights.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.sakuraPink.opacity(0.15))
                    .clipShape(Capsule())
            }

            ForEach(scannedFlights) { flight in
                flightResultCard(flight)
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation { state = .idle }
                    scannedFlights = []
                    selectedFlightIDs = []
                    selectedItem = nil
                    pasteText = ""
                } label: {
                    Text("ЗАНОВО")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }
                .buttonStyle(.plain)

                Button {
                    let selected = scannedFlights.filter { selectedFlightIDs.contains($0.id) }
                    onFlightsAdded(selected.isEmpty ? scannedFlights : selected)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text(addButtonTitle)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.sakuraPink)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addButtonTitle: String {
        if selectedFlightIDs.isEmpty {
            return "ДОБАВИТЬ ВСЕ"
        }
        return "ДОБАВИТЬ (\(selectedFlightIDs.count))"
    }

    private func flightResultCard(_ flight: ScannedFlight) -> some View {
        let isSelected = selectedFlightIDs.contains(flight.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedFlightIDs.remove(flight.id)
                } else {
                    selectedFlightIDs.insert(flight.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AnyShapeStyle(AppTheme.sakuraPink) : AnyShapeStyle(.tertiary))

                VStack(alignment: .leading, spacing: 4) {
                    // Flight number
                    Text(flight.number)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        // Route
                        if let from = flight.departureIata, let to = flight.arrivalIata {
                            HStack(spacing: 4) {
                                Text(from)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(to)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(.secondary)
                        }

                        // Date
                        if let date = flight.date {
                            Text(date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "airplane")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error

    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.toriiRed)

            Text(errorMessage ?? "Произошла ошибка")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation { state = .idle }
                errorMessage = nil
            } label: {
                Text("ПОПРОБОВАТЬ СНОВА")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.sakuraPink)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Processing Logic

    private func loadAndProcess(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Не удалось загрузить фото"
            withAnimation { state = .error }
            return
        }
        await processImage(image)
    }

    private func processImage(_ image: UIImage) async {
        withAnimation { state = .processing }
        do {
            let flights = try await BookingScanService.shared.scanImage(image)
            handleResult(flights)
        } catch {
            errorMessage = error.localizedDescription
            withAnimation { state = .error }
        }
    }

    private func processPDF(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        withAnimation { state = .processing }
        do {
            let flights = try await BookingScanService.shared.scanPDF(url)
            handleResult(flights)
        } catch {
            errorMessage = error.localizedDescription
            withAnimation { state = .error }
        }
    }

    private func processText() async {
        withAnimation { state = .processing }
        do {
            let flights = try await BookingScanService.shared.scanText(pasteText)
            handleResult(flights)
        } catch {
            errorMessage = error.localizedDescription
            withAnimation { state = .error }
        }
    }

    private func handleResult(_ flights: [ScannedFlight]) {
        if flights.isEmpty {
            errorMessage = "Рейсы не найдены. Попробуйте другой источник"
            withAnimation { state = .error }
        } else {
            scannedFlights = flights
            selectedFlightIDs = Set(flights.map(\.id))
            withAnimation { state = .results }
        }
    }
}

// MARK: - State & Input Mode

private enum ScanState {
    case idle, processing, results, error
}

private enum InputMode: CaseIterable {
    case photo, camera, pdf, text, email

    var label: String {
        switch self {
        case .photo: return "ФОТО"
        case .camera: return "КАМЕРА"
        case .pdf: return "PDF"
        case .text: return "ТЕКСТ"
        case .email: return "ПОЧТА"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo"
        case .camera: return "camera"
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        case .email: return "envelope.fill"
        }
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCapture(nil)
        }
    }
}
