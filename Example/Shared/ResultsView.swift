import ITunesSearchKit
import ITunesSearchUI
import SwiftUI

/// The results of the current search as a grid of artwork, or what to do when there are none.
struct ResultsView: View {
    let store: SearchStore
    let scene: ScreenshotScene?

    var body: some View {
        Group {
            if store.results.isEmpty {
                emptyState
            } else {
                ScrollView {
                    ResultsGrid(items: store.results)
                        .padding(Layout.pagePadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .signalsScreenshotReady(
            scene == .search ? scene : nil,
            when: store.phase == .loaded && !store.results.isEmpty
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        switch store.phase {
        case .loading:
            ProgressView()
                .controlSize(.large)
        case let .failed(message):
            ContentUnavailableView {
                Label("Search Failed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await store.search(debounce: false) }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded:
            ContentUnavailableView.search(text: store.key.query)
        case .idle:
            ContentUnavailableView {
                Label("Search the iTunes Store", systemImage: "magnifyingglass")
            } description: {
                Text("Find songs, albums, podcasts, movies, books and apps, with artwork and previews.")
            }
        }
    }
}

/// Artwork tiles that open a detail page.
struct ResultsGrid: View {
    let items: [ITunesItem]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Layout.tileMinimum), spacing: Layout.tileSpacing, alignment: .top)],
            alignment: .leading,
            spacing: Layout.tileSpacing + 4
        ) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    ResultTile(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One result: its artwork, title and creator.
struct ResultTile: View {
    let item: ITunesItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkTile(item: item)
            HStack(spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if item.isExplicit {
                    ExplicitBadge()
                }
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let creator = item.creator {
            parts.append(creator)
        } else {
            parts.append(item.genre ?? item.kind.title)
        }
        switch item.kind {
        case .album, .movie, .ebook:
            if let year = item.releaseYear {
                parts.append(String(year))
            }
        default:
            break
        }
        return parts.joined(separator: " · ")
    }
}

/// Artwork in the shape of its kind (square, poster or app icon), with a soft shadow.
struct ArtworkTile: View {
    let item: ITunesItem
    var pixelSize = 600

    var body: some View {
        GeometryReader { proxy in
            ArtworkImage(item: item, pixelSize: pixelSize)
                .clipShape(RoundedRectangle(cornerRadius: proxy.size.width * item.kind.artworkCornerFraction, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: proxy.size.width * item.kind.artworkCornerFraction, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .aspectRatio(item.kind.artworkAspectRatio, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
    }
}

/// Sizes that differ between the Mac and iPhone.
enum Layout {
    #if os(macOS)
    static let pagePadding: CGFloat = 24
    static let tileMinimum: CGFloat = 158
    static let tileSpacing: CGFloat = 20
    static let headerArtwork: CGFloat = 210
    #else
    static let pagePadding: CGFloat = 16
    static let tileMinimum: CGFloat = 150
    static let tileSpacing: CGFloat = 14
    static let headerArtwork: CGFloat = 132
    #endif
}
