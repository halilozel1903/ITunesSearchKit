import Foundation

/// The answer of `/search` and `/lookup`: `{"resultCount": 2, "results": [...]}`, with every result typed.
///
/// A result that is not a JSON object is skipped instead of failing the response; ``skippedCount`` says how many.
public struct ITunesResponse: Sendable, Hashable, Decodable {
    /// The `resultCount` the API reported.
    public let resultCount: Int
    /// The results, in the API's order.
    public let items: [ITunesItem]
    /// Results that could not be read at all.
    public let skippedCount: Int

    public init(items: [ITunesItem]) {
        self.resultCount = items.count
        self.items = items
        self.skippedCount = 0
    }

    private enum CodingKeys: String, CodingKey {
        case resultCount
        case results
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let boxes = try container.decodeIfPresent([LossyItem].self, forKey: .results) ?? []
        let items = boxes.compactMap(\.raw).map(ITunesItem.init)
        self.items = items
        skippedCount = boxes.count - items.count
        resultCount = (try? container.decodeIfPresent(Int.self, forKey: .resultCount)) ?? boxes.count
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public var songs: [Song] { items.compactMap(\.asSong) }
    public var musicVideos: [MusicVideo] { items.compactMap(\.asMusicVideo) }
    public var albums: [Album] { items.compactMap(\.asAlbum) }
    public var artists: [Artist] { items.compactMap(\.asArtist) }
    public var podcasts: [Podcast] { items.compactMap(\.asPodcast) }
    public var podcastEpisodes: [PodcastEpisode] { items.compactMap(\.asPodcastEpisode) }
    public var movies: [Movie] { items.compactMap(\.asMovie) }
    public var ebooks: [Ebook] { items.compactMap(\.asEbook) }
    public var audiobooks: [Audiobook] { items.compactMap(\.asAudiobook) }
    public var apps: [Software] { items.compactMap(\.asSoftware) }
}

/// One entry of `results`, or `nil` when it is not an object.
private struct LossyItem: Decodable {
    let raw: RawItem?

    init(from decoder: any Decoder) throws {
        raw = try? RawItem(from: decoder)
    }
}

/// An album with its songs, from ``ITunesClient/album(id:country:)``.
public struct AlbumDetail: Sendable, Hashable {
    public let album: Album
    /// The songs in disc and track order.
    public let tracks: [Song]

    public init(album: Album, tracks: [Song]) {
        self.album = album
        self.tracks = tracks.sorted { lhs, rhs in
            (lhs.discNumber ?? 1, lhs.trackNumber ?? Int.max) < (rhs.discNumber ?? 1, rhs.trackNumber ?? Int.max)
        }
    }

    /// The sum of the songs' running times, in seconds.
    public var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    /// Whether the album spans more than one disc.
    public var hasSeveralDiscs: Bool {
        Set(tracks.map { $0.discNumber ?? 1 }).count > 1
    }
}

/// An artist with albums, from ``ITunesClient/artist(id:albumLimit:newestFirst:country:)``.
public struct ArtistDetail: Sendable, Hashable {
    public let artist: Artist
    public let albums: [Album]

    public init(artist: Artist, albums: [Album]) {
        self.artist = artist
        self.albums = albums
    }
}

/// A podcast with its latest episodes, from ``ITunesClient/podcast(id:episodeLimit:country:)``.
public struct PodcastDetail: Sendable, Hashable {
    public let podcast: Podcast
    /// The episodes, newest first.
    public let episodes: [PodcastEpisode]

    public init(podcast: Podcast, episodes: [PodcastEpisode]) {
        self.podcast = podcast
        self.episodes = episodes.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }
}
