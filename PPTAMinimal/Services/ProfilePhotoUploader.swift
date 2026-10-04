//
//  ProfilePhotoUploader.swift
//  PPTAMinimal
//
//  One upload path for profile pictures (onboarding + Settings). Two problems it fixes:
//
//  1. Slow uploads: the picked photo used to be uploaded as-is — often several MB of full-resolution
//     HEIC/JPEG — then downloaded again at full size by every avatar. It is now downscaled and
//     JPEG-compressed first (~50–150 KB).
//  2. The new photo not appearing until relaunch: every upload overwrites `profilePictures/{uid}.jpg`,
//     and Firebase keeps the same download URL (same token) on overwrite. Avatars cache by URL, so
//     they kept showing the old image until the in-memory cache died with the app. Each upload now
//     gets a fresh URL (a `v=` query item, which Storage ignores), and the new image is seeded into
//     the avatar cache so every screen shows it immediately.
//
//  The path stays `profilePictures/{uid}.jpg` because the server-side `deleteAccount` deletes exactly
//  that object.
//

import UIKit
import FirebaseStorage

enum ProfilePhotoUploader {
    /// Longest edge, in pixels. Avatars render at ≤ 130pt, so 512px stays sharp at 3x.
    private static let maxDimension: CGFloat = 512
    private static let jpegQuality: CGFloat = 0.75

    enum UploadError: Error { case unreadableImage }

    /// Downscales + compresses `data`, uploads it, and returns the cache-busted download URL to store
    /// in `profileImageURL`. The avatar cache is pre-seeded for that URL.
    static func upload(_ data: Data, uid: String) async throws -> URL {
        guard let original = UIImage(data: data),
              let resized = downscaled(original),
              let jpeg = resized.jpegData(compressionQuality: jpegQuality)
        else { throw UploadError.unreadableImage }

        let ref = Storage.storage().reference(withPath: "profilePictures/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpeg, metadata: metadata)

        let url = cacheBusted(try await ref.downloadURL())
        await InitialsProfilePicView.seedCache(resized, for: url)
        return url
    }

    /// Small, already-decoded image for showing the pick on screen the moment it's chosen. Decoding a
    /// full-resolution photo in a view body re-ran on every redraw and made the preview lag; this
    /// decodes once, off the main thread, at avatar size (≤ 130pt @3x).
    static func previewImage(from data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data) else { return nil }
            return downscaled(image, maxDimension: 400)
        }.value
    }

    /// Fits the image inside `maxDimension` × `maxDimension` (never upscales), at scale 1 so the
    /// pixel size is exact.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat = maxDimension) -> UIImage? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let factor = min(1, maxDimension / longest)
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true // JPEG has no alpha; also halves memory
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Appends `v=<unix time>` so this upload's URL differs from the previous one.
    private static func cacheBusted(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "v" }
        items.append(URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970))))
        components.queryItems = items
        return components.url ?? url
    }
}
