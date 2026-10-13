import ITunesSearchKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the bytes of an artwork URL. ``ArtworkImage`` loads through the loader in the environment, so you can swap
/// in your own cache, or count and retry loads.
///
/// ```swift
/// ContentView()
///     .artworkLoader(ArtworkLoader { url in
///         try await MyImageCache.shared.data(for: url)
///     })
/// ```
public struct ArtworkLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    public func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads over `URLSession.shared` (or from disk for file URLs), keeping recent images in memory.
    public static let urlSession = ArtworkLoader { url in
        try await ArtworkLoader.fetch(url)
    }

    /// One plain download over `URLSession.shared`, with the in-memory cache. Throws for an unsuccessful HTTP status.
    public static func fetch(_ url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cached = await ArtworkDataCache.shared.data(for: url) {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        await ArtworkDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes, so scrolling back does not hit the network again.
actor ArtworkDataCache {
    static let shared = ArtworkDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 300

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so artwork that scrolls back into view appears at once.
@MainActor
final class DecodedArtworkCache {
    static let shared = DecodedArtworkCache()

    private var images: [URL: Image] = [:]
    private var order: [URL] = []
    private let limit = 300

    func image(for url: URL) -> Image? {
        images[url]
    }

    func insert(_ image: Image, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }
}

/// Decodes image bytes into a SwiftUI `Image`.
public enum ArtworkDecoder {
    /// Whether the bytes are an image this platform can show.
    public static func canDecode(_ data: Data) -> Bool {
        #if canImport(UIKit)
        return UIImage(data: data) != nil
        #elseif canImport(AppKit)
        return NSImage(data: data) != nil
        #else
        return false
        #endif
    }

    @MainActor
    static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct ArtworkLoaderKey: EnvironmentKey {
    static let defaultValue: ArtworkLoader = .urlSession
}

extension EnvironmentValues {
    /// The loader ``ArtworkImage`` uses. Defaults to ``ArtworkLoader/urlSession``.
    public var artworkLoader: ArtworkLoader {
        get { self[ArtworkLoaderKey.self] }
        set { self[ArtworkLoaderKey.self] = newValue }
    }
}

extension View {
    /// Loads every ``ArtworkImage`` below this view with `loader`.
    public func artworkLoader(_ loader: ArtworkLoader) -> some View {
        environment(\.artworkLoader, loader)
    }
}

/// Artwork from the iTunes Search API at the pixel size you need, with a placeholder while it loads.
///
/// The API's thumbnails are 100 × 100; ``ArtworkImage`` asks Apple's image server for `pixelSize` instead
/// (see ``Artwork/url(size:format:)``). Give it a frame or an aspect ratio; the image fills it and is clipped.
///
/// ```swift
/// ArtworkImage(song.artwork, pixelSize: 600)
///     .frame(width: 160, height: 160)
///     .clipShape(.rect(cornerRadius: 8))
/// ```
public struct ArtworkImage<Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @Environment(\.artworkLoader) private var loader
    @State private var loaded: LoadedArtwork?

    /// Artwork resized to `pixelSize` × `pixelSize` (fitted, so posters keep their shape).
    public init(_ artwork: Artwork?, pixelSize: Int = 600, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.init(url: artwork?.url(size: pixelSize), contentMode: contentMode, placeholder: placeholder)
    }

    /// Artwork resized to fit `pixelWidth` × `pixelHeight`.
    public init(_ artwork: Artwork?, pixelWidth: Int, pixelHeight: Int, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.init(url: artwork?.url(width: pixelWidth, height: pixelHeight), contentMode: contentMode, placeholder: placeholder)
    }

    /// Any image URL, as is.
    public init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let image = currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
    }

    private var currentImage: Image? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return DecodedArtworkCache.shared.image(for: url)
    }

    private func load() async {
        guard let url, DecodedArtworkCache.shared.image(for: url) == nil else { return }
        guard let data = try? await loader.data(for: url), !Task.isCancelled else { return }
        guard let image = ArtworkDecoder.image(from: data) else { return }
        DecodedArtworkCache.shared.insert(image, for: url)
        withAnimation(.easeOut(duration: 0.2)) {
            loaded = LoadedArtwork(url: url, image: image)
        }
    }
}

private struct LoadedArtwork {
    let url: URL
    let image: Image
}

extension ArtworkImage where Placeholder == ArtworkPlaceholder {
    /// Artwork with a generated placeholder for `kind` while it loads, or when there is none.
    public init(_ artwork: Artwork?, kind: ITunesItemKind, pixelSize: Int = 600, contentMode: ContentMode = .fill) {
        self.init(artwork, pixelSize: pixelSize, contentMode: contentMode) {
            ArtworkPlaceholder(kind: kind)
        }
    }

    /// The artwork of `item`, with a placeholder for its kind.
    public init(item: ITunesItem, pixelSize: Int = 600, contentMode: ContentMode = .fill) {
        self.init(item.artwork, kind: item.kind, pixelSize: pixelSize, contentMode: contentMode)
    }
}

/// A soft gradient with the symbol of a kind of item, shown while artwork loads or for artists, who have none.
public struct ArtworkPlaceholder: View {
    private let kind: ITunesItemKind

    public init(kind: ITunesItemKind) {
        self.kind = kind
    }

    public var body: some View {
        LinearGradient(
            colors: [Color.secondary.opacity(0.28), Color.secondary.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: kind.systemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}
