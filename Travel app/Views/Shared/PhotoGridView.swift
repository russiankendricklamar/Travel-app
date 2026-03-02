import SwiftUI
import PhotosUI
import SwiftData

struct PhotoGridView: View {
    let photos: [TripPhoto]
    let onAdd: (TripPhoto) -> Void
    let onDelete: (TripPhoto) -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var fullscreenPhoto: TripPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("ФОТО")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                if !photos.isEmpty {
                    Text("\(photos.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photos) { photo in
                    photoThumbnail(photo)
                }
                addButton
            }
        }
    }

    private func photoThumbnail(_ photo: TripPhoto) -> some View {
        Group {
            if let uiImage = UIImage(data: photo.thumbnailData ?? photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onTapGesture { fullscreenPhoto = photo }
        .contextMenu {
            Button(role: .destructive) {
                onDelete(photo)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .fullScreenCover(item: $fullscreenPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }

    private var addButton: some View {
        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("Добавить")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 1)
            )
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                for item in newItems {
                    await loadPhoto(from: item)
                }
                selectedItems = []
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        let maxDim: CGFloat = 800
        let scale = min(maxDim / uiImage.size.width, maxDim / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let compressed = renderer.jpegData(withCompressionQuality: 0.7) { ctx in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        let thumbScale = min(200 / uiImage.size.width, 200 / uiImage.size.height, 1.0)
        let thumbSize = CGSize(width: uiImage.size.width * thumbScale, height: uiImage.size.height * thumbScale)
        let thumbRenderer = UIGraphicsImageRenderer(size: thumbSize)
        let thumbnail = thumbRenderer.jpegData(withCompressionQuality: 0.5) { ctx in
            uiImage.draw(in: CGRect(origin: .zero, size: thumbSize))
        }

        let photo = TripPhoto(imageData: compressed, thumbnailData: thumbnail)
        onAdd(photo)
        try? modelContext.save()
    }
}

struct PhotoDetailView: View {
    let photo: TripPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .onTapGesture { dismiss() }
    }
}
