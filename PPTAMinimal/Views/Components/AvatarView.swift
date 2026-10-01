//
//  AvatarView.swift
//  PPTAMinimal
//

import SwiftUI
import UIKit

/// Loads and holds one avatar image. AsyncImage never retries a failed load and drops its result
/// when the parent re-renders mid-flight (-999), which stranded the Home header on initials when
/// it was created before the network was up. This lives in @StateObject so it survives re-renders,
/// retries with backoff, and retries again when the app becomes active.
@MainActor
private final class AvatarImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let cache = NSCache<NSURL, UIImage>()
    private static let retryDelays: [UInt64] = [2, 5, 15, 30]  // seconds

    private var url: URL?
    private var task: Task<Void, Never>?

    func load(_ newURL: URL?) {
        if newURL == url, image != nil || task != nil { return }
        task?.cancel()
        task = nil
        url = newURL
        image = nil
        guard let newURL else { return }
        if let cached = Self.cache.object(forKey: newURL as NSURL) {
            image = cached
            return
        }
        start(newURL)
    }

    /// Called when the app becomes active: restart only if we gave up.
    func retryIfNeeded() {
        guard let url, image == nil, task == nil else { return }
        start(url)
    }

    private func start(_ target: URL) {
        task = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                if let img = await Self.fetch(target) {
                    guard let self, self.url == target else { return }
                    Self.cache.setObject(img, forKey: target as NSURL)
                    self.image = img
                    self.task = nil
                    return
                }
                guard attempt < Self.retryDelays.count else { break }
                try? await Task.sleep(nanoseconds: Self.retryDelays[attempt] * 1_000_000_000)
                attempt += 1
            }
            if !Task.isCancelled, let self, self.url == target { self.task = nil }
        }
    }

    /// One attempt, no retry: warms the cache so the avatar is there on first render. A miss falls
    /// back to the view's own loader, which retries.
    static func prefetch(_ url: URL) async {
        guard cache.object(forKey: url as NSURL) == nil, let img = await fetch(url) else { return }
        cache.setObject(img, forKey: url as NSURL)
    }

    private nonisolated static func fetch(_ url: URL) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
        else { return nil }
        return UIImage(data: data)
    }
}

extension InitialsProfilePicView {
    /// Downloads the avatars into the shared cache ahead of the views that show them (cold-launch
    /// facade). Never throws; an unreachable URL just leaves that avatar to load as usual.
    @MainActor
    static func prefetch(_ urls: [URL?]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in Set(urls.compactMap { $0 }) {
                group.addTask { await AvatarImageLoader.prefetch(url) }
            }
        }
    }
}

struct InitialsProfilePicView: View {
    let name: String
    let profilePicUrl: String?
    let size: CGFloat

    @StateObject private var loader = AvatarImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: profilePicUrl) { loader.load(profilePicUrl.flatMap { URL(string: $0) }) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            loader.retryIfNeeded()
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color("primaryColor").opacity(0.12))
            .overlay(
                Text(initials(from: name))
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(Color("primaryColor"))
            )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
