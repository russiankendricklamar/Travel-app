import Foundation
import SwiftData
import Supabase

/// Handles upload/download of photos to/from Supabase Storage
@MainActor
final class PhotoSyncService {
    static let shared = PhotoSyncService()
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let bucket = "trip-photos"
    private init() {}

    // MARK: - Upload Trip Photo

    func uploadPhoto(_ photo: TripPhoto) async throws {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        guard photo.storagePath == nil else { return } // already uploaded

        let path = "\(userID.uuidString)/\(photo.id.uuidString).jpg"

        try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: photo.imageData,
                options: .init(contentType: "image/jpeg", upsert: true)
            )

        photo.storagePath = path

        // Upload thumbnail if available
        if let thumbData = photo.thumbnailData {
            let thumbPath = "\(userID.uuidString)/\(photo.id.uuidString)_thumb.jpg"
            try await client.storage
                .from(bucket)
                .upload(
                    path: thumbPath,
                    file: thumbData,
                    options: .init(contentType: "image/jpeg", upsert: true)
                )
            photo.thumbnailPath = thumbPath
        }

        photo.markUpdated()
    }

    // MARK: - Download Trip Photo

    func downloadPhoto(_ photo: TripPhoto) async throws {
        guard let storagePath = photo.storagePath else { return }

        let data = try await client.storage
            .from(bucket)
            .download(path: storagePath)
        photo.imageData = data

        // Download thumbnail
        if let thumbPath = photo.thumbnailPath {
            let thumbData = try await client.storage
                .from(bucket)
                .download(path: thumbPath)
            photo.thumbnailData = thumbData
        }
    }

    // MARK: - Upload Bucket List Photo

    func uploadBucketPhoto(_ item: BucketListItem) async throws {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        guard let photoData = item.photoData else { return }
        guard item.photoStoragePath == nil else { return }

        let path = "\(userID.uuidString)/bucket_\(item.id.uuidString).jpg"

        try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: photoData,
                options: .init(contentType: "image/jpeg", upsert: true)
            )

        item.photoStoragePath = path
        item.markUpdated()
    }

    // MARK: - Download Bucket List Photo

    func downloadBucketPhoto(_ item: BucketListItem) async throws {
        guard let storagePath = item.photoStoragePath else { return }
        guard item.photoData == nil else { return }

        let data = try await client.storage
            .from(bucket)
            .download(path: storagePath)
        item.photoData = data
    }

    // MARK: - Sync All Photos (push pending uploads, pull missing downloads)

    func syncPhotos(context: ModelContext) async {
        guard SupabaseManager.shared.currentUserID != nil else { return }

        // Upload unsynced trip photos
        let photoDescriptor = FetchDescriptor<TripPhoto>()
        if let photos = try? context.fetch(photoDescriptor) {
            for photo in photos where photo.storagePath == nil && !photo.isDeleted {
                try? await uploadPhoto(photo)
            }
            // Download missing photo data
            for photo in photos where photo.storagePath != nil && photo.imageData.isEmpty {
                try? await downloadPhoto(photo)
            }
        }

        // Upload unsynced bucket list photos
        let bucketDescriptor = FetchDescriptor<BucketListItem>()
        if let items = try? context.fetch(bucketDescriptor) {
            for item in items where item.photoData != nil && item.photoStoragePath == nil && !item.isDeleted {
                try? await uploadBucketPhoto(item)
            }
            // Download missing
            for item in items where item.photoStoragePath != nil && item.photoData == nil {
                try? await downloadBucketPhoto(item)
            }
        }

        try? context.save()
    }
}
