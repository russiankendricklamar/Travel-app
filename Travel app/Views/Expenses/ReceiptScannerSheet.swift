import SwiftUI
import PhotosUI

struct ReceiptScannerSheet: View {
    let onResult: (ScannedExpense) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var state: ScanState = .idle
    @State private var results: [ScannedExpense] = []
    @State private var errorMessage: String?

    private enum ScanState {
        case idle, processing, results, error
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "doc.text.viewfinder",
                        title: "СКАНИРОВАТЬ ЧЕК",
                        color: AppTheme.templeGold
                    )

                    switch state {
                    case .idle:
                        inputModes
                    case .processing:
                        processingView
                    case .results:
                        resultsView
                    case .error:
                        errorView
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ЗАКРЫТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { await loadAndProcess(item: item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    if let image { Task { await processImage(image) } }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Input Modes

    private var inputModes: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                inputCard(
                    icon: "photo.on.rectangle",
                    title: "ГАЛЕРЕЯ",
                    subtitle: "Выбрать фото чека",
                    color: AppTheme.sakuraPink
                )
            }

            Button { showCamera = true } label: {
                inputCard(
                    icon: "camera.fill",
                    title: "КАМЕРА",
                    subtitle: "Сфотографировать чек",
                    color: AppTheme.oceanBlue
                )
            }
        }
    }

    private func inputCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Распознаём чек...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 12) {
            ForEach(results.indices, id: \.self) { idx in
                resultCard(results[idx], index: idx)
            }

            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text("Расходы не найдены на чеке")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 30)
            }

            Button {
                state = .idle
                results = []
                selectedItem = nil
            } label: {
                Text("СКАНИРОВАТЬ ЕЩЁ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.templeGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.templeGold.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
        }
    }

    private func resultCard(_ expense: ScannedExpense, index: Int) -> some View {
        let color = AppTheme.expenseColor(for: expense.category)
        return Button {
            onResult(expense)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: expense.category.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(expense.category.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(color)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyService.shared.format(expense.amount, currency: expense.currency))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(expense.date, style: .date)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.sakuraPink)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.toriiRed)
            Text(errorMessage ?? "Ошибка сканирования")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                state = .idle
                selectedItem = nil
            } label: {
                Text("ПОПРОБОВАТЬ СНОВА")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.sakuraPink)
            }
        }
        .padding(.vertical, 30)
    }

    // MARK: - Processing Logic

    private func loadAndProcess(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Не удалось загрузить изображение"
            state = .error
            return
        }
        await processImage(image)
    }

    private func processImage(_ image: UIImage) async {
        state = .processing
        do {
            results = try await ReceiptScanService.shared.scanImage(image)
            state = .results
        } catch {
            errorMessage = error.localizedDescription
            state = .error
        }
    }
}

// MARK: - Camera Picker

private struct CameraPickerView: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { self.onImage(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onImage(nil) }
        }
    }
}
