import ITunesSearchKit
import ITunesSearchUI
import SwiftUI

/// The page of one result: an album with its songs, a podcast with its episodes, an artist with albums, or a
/// movie, book or app with its description.
struct ItemDetailView: View {
    let player: PreviewPlayer
    let scene: ScreenshotScene?
    @State private var store: DetailStore

    init(item: ITunesItem, client: ITunesClient, player: PreviewPlayer, scene: ScreenshotScene?) {
        self.player = player
        self.scene = scene
        _store = State(initialValue: DetailStore(item: item, client: client, attempts: scene == nil ? 1 : 4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch store.content {
                case let .album(detail, highlightedSongID)?:
                    AlbumPage(detail: detail, highlightedSongID: highlightedSongID, player: player)
                case let .podcast(detail, highlightedEpisodeID)?:
                    PodcastPage(detail: detail, highlightedEpisodeID: highlightedEpisodeID, player: player)
                case let .artist(detail)?:
                    ArtistPage(detail: detail)
                case let .media(item)?:
                    MediaPage(item: item, player: player)
                case nil:
                    DetailHeader(item: store.item, player: player)
                    statusView
                }
            }
            .padding(Layout.pagePadding)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(store.item.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .task {
            if store.phase == .idle {
                await store.load()
            }
        }
        .signalsScreenshotReady(scene, when: store.phase == .loaded && store.hasContent)
    }

    @ViewBuilder
    private var statusView: some View {
        if case let .failed(message) = store.phase {
            ContentUnavailableView {
                Label("Not Available", systemImage: "exclamationmark.icloud")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await store.load() }
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }
}

// MARK: - Header

/// Artwork next to the title, the creator, a line of facts and the store link.
struct DetailHeader: View {
    let item: ITunesItem
    let player: PreviewPlayer
    var facts: [String] = []

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            ArtworkTile(item: item)
                .frame(width: artworkWidth)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.kind.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name)
                        .font(titleFont)
                        .lineLimit(3)
                    if item.isExplicit {
                        ExplicitBadge()
                    }
                }
                if let creator = item.creator {
                    Text(creator)
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .lineLimit(2)
                }
                let line = (defaultFacts + facts).joined(separator: " · ")
                if !line.isEmpty {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    if let preview = item.previewURL, !item.hasVideoPreview {
                        Button {
                            player.toggle(preview)
                        } label: {
                            Label(
                                player.isPlaying(preview) ? "Pause" : "Preview",
                                systemImage: player.isPlaying(preview) ? "pause.fill" : "play.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if let store = item.storeURL {
                        Link(destination: store) {
                            Label("Open in Store", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .controlSize(controlSize)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var artworkWidth: CGFloat {
        let width = Layout.headerArtwork
        return item.kind.artworkAspectRatio < 1 ? width * 0.8 : width
    }

    private var titleFont: Font {
        #if os(macOS)
        return .largeTitle.weight(.bold)
        #else
        return .title3.weight(.bold)
        #endif
    }

    private var controlSize: ControlSize {
        #if os(macOS)
        return .large
        #else
        return .small
        #endif
    }

    private var defaultFacts: [String] {
        var facts: [String] = []
        if let genre = item.genre {
            facts.append(genre)
        }
        if let year = item.releaseYear {
            facts.append(String(year))
        }
        return facts
    }
}

// MARK: - Album

struct AlbumPage: View {
    let detail: AlbumDetail
    let highlightedSongID: Int?
    let player: PreviewPlayer

    var body: some View {
        DetailHeader(item: .album(detail.album), player: player, facts: facts)
        VStack(spacing: 0) {
            ForEach(Array(detail.tracks.enumerated()), id: \.element.id) { index, song in
                TrackRow(
                    song: song,
                    albumArtist: detail.album.artistName,
                    isHighlighted: song.id == highlightedSongID,
                    player: player
                )
                if index < detail.tracks.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        if let copyright = detail.album.copyright {
            Text(copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var facts: [String] {
        var facts: [String] = []
        let count = detail.tracks.count
        facts.append(count == 1 ? "1 song" : "\(count) songs")
        if detail.totalDuration > 0 {
            facts.append(ITunesFormat.longDuration(detail.totalDuration))
        }
        return facts
    }
}

/// A song in an album's track list: its number, name, duration and preview button.
struct TrackRow: View {
    let song: Song
    let albumArtist: String
    let isHighlighted: Bool
    let player: PreviewPlayer

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if player.isPlaying(song.previewURL) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.tint)
                } else {
                    Text(song.trackNumber.map { String($0) } ?? "")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout.monospacedDigit())
            .frame(width: 28, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(song.name)
                        .fontWeight(isHighlighted ? .semibold : .regular)
                        .lineLimit(1)
                    if song.isExplicit {
                        ExplicitBadge()
                    }
                }
                if song.artistName != albumArtist, !song.artistName.isEmpty {
                    Text(song.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let duration = song.duration {
                Text(ITunesFormat.duration(duration))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            PreviewButton(url: song.previewURL, player: player, size: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

// MARK: - Podcast

struct PodcastPage: View {
    let detail: PodcastDetail
    let highlightedEpisodeID: Int?
    let player: PreviewPlayer

    var body: some View {
        DetailHeader(item: .podcast(detail.podcast), player: player, facts: facts)
        Text("Latest Episodes")
            .font(.title3.weight(.semibold))
        VStack(spacing: 0) {
            ForEach(Array(detail.episodes.enumerated()), id: \.element.id) { index, episode in
                EpisodeRow(episode: episode, isHighlighted: episode.id == highlightedEpisodeID, player: player)
                if index < detail.episodes.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var facts: [String] {
        guard let count = detail.podcast.episodeCount else { return [] }
        return [count.formatted() + " episodes"]
    }
}

/// An episode: its date, title, notes and length, with a play button.
struct EpisodeRow: View {
    let episode: PodcastEpisode
    let isHighlighted: Bool
    let player: PreviewPlayer

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let date = episode.releaseDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(episode.name)
                    .font(.headline)
                    .lineLimit(2)
                if let notes = episode.plainDescription, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let duration = episode.duration {
                    Text(ITunesFormat.longDuration(duration))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
            Spacer(minLength: 8)
            PreviewButton(url: episode.previewURL ?? episode.episodeURL, player: player, size: 30)
                .padding(.top, 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

// MARK: - Artist

struct ArtistPage: View {
    let detail: ArtistDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ARTIST")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(detail.artist.name)
                .font(.largeTitle.weight(.bold))
            if let genre = detail.artist.genre {
                Text(genre)
                    .foregroundStyle(.secondary)
            }
            if let store = detail.artist.storeURL {
                Link(destination: store) {
                    Label("Open in Store", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }
        }
        if detail.albums.isEmpty {
            Text("No albums in this store.")
                .foregroundStyle(.secondary)
        } else {
            Text("Albums")
                .font(.title3.weight(.semibold))
            ResultsGrid(items: detail.albums.map(ITunesItem.album))
        }
    }
}

// MARK: - Movies, books, apps and the rest

struct MediaPage: View {
    let item: ITunesItem
    let player: PreviewPlayer

    var body: some View {
        DetailHeader(item: item, player: player, facts: facts)
        if let rating = rating {
            RatingStars(rating.average, count: rating.count)
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
        if let trailer = item.previewURL, item.hasVideoPreview {
            Link(destination: trailer) {
                Label(item.kind == .movie ? "Watch the Trailer" : "Watch the Preview", systemImage: "play.rectangle")
            }
        }
        if let screenshots = item.asSoftware?.screenshotURLs, !screenshots.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(screenshots, id: \.self) { url in
                        ArtworkImage(url: url, contentMode: .fit) {
                            Color.secondary.opacity(0.1)
                        }
                        .frame(width: 180, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        if let text = descriptionText, !text.isEmpty {
            Text(text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        if !details.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(details, id: \.label) { row in
                    GridRow {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Text(row.value)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private struct Row {
        let label: String
        let value: String
    }

    private var facts: [String] {
        switch item {
        case let .movie(movie):
            return [movie.contentRating, movie.duration.map(ITunesFormat.longDuration)].compactMap { $0 }
        case let .software(app):
            return [app.contentRating, app.formattedPrice].compactMap { $0 }
        case let .ebook(book):
            return [book.formattedPrice].compactMap { $0 }
        default:
            return item.duration.map { [ITunesFormat.duration($0)] } ?? []
        }
    }

    private var rating: (average: Double, count: Int?)? {
        switch item {
        case let .software(app):
            guard let average = app.averageRating else { return nil }
            return (average, app.ratingCount)
        case let .ebook(book):
            guard let average = book.averageRating else { return nil }
            return (average, book.ratingCount)
        default:
            return nil
        }
    }

    private var descriptionText: String? {
        switch item {
        case let .movie(movie): movie.longDescription ?? movie.shortDescription
        case let .ebook(book): book.plainDescription
        case let .audiobook(book): book.plainDescription
        case let .software(app): app.description.map(ITunesText.plainText(fromHTML:))
        case let .podcastEpisode(episode): episode.plainDescription
        default: nil
        }
    }

    private var details: [Row] {
        var rows: [Row] = []
        let price: Price?
        switch item {
        case let .movie(movie):
            price = movie.price
            if let rental = movie.rentalPrice {
                rows.append(Row(label: "Rent", value: rental.formatted()))
            }
        case let .software(app):
            price = nil
            if let version = app.version {
                rows.append(Row(label: "Version", value: version))
            }
            if let size = app.fileSize {
                rows.append(Row(label: "Size", value: ITunesFormat.fileSize(size)))
            }
            if let minimum = app.minimumOSVersion {
                rows.append(Row(label: "Requires", value: minimum + " or later"))
            }
            if let seller = app.seller {
                rows.append(Row(label: "Seller", value: seller))
            }
        case let .audiobook(book):
            price = book.price
        case let .musicVideo(video):
            price = video.price
        default:
            price = nil
        }
        if let price {
            rows.insert(Row(label: "Buy", value: price.formatted()), at: 0)
        }
        if let date = item.releaseDate {
            rows.append(Row(label: "Released", value: date.formatted(date: .long, time: .omitted)))
        }
        return rows
    }
}
