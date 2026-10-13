import Foundation

/// One result of a search or lookup, typed by what it is.
///
/// The API returns songs, albums, artists, podcasts, movies, books and apps in one `results` array, told apart by
/// `wrapperType` and `kind`. Switch over the cases, or use the shared properties for a mixed list:
///
/// ```swift
/// for item in response.items {
///     switch item {
///     case let .song(song): print(song.name, song.albumName ?? "")
///     case let .album(album): print(album.name, album.trackCount ?? 0)
///     case let .podcast(podcast): print(podcast.name, podcast.feedURL?.absoluteString ?? "")
///     default: print(item.kind.title, item.name)
///     }
/// }
/// ```
public enum ITunesItem: Sendable, Hashable, Identifiable {
    case song(Song)
    case musicVideo(MusicVideo)
    case album(Album)
    case artist(Artist)
    case podcast(Podcast)
    case podcastEpisode(PodcastEpisode)
    case movie(Movie)
    case ebook(Ebook)
    case audiobook(Audiobook)
    case software(Software)
    /// A kind this package has no model for, such as a TV episode.
    case other(UnknownItem)

    init(_ raw: RawItem) {
        self = ITunesItem.typed(raw) ?? .other(UnknownItem(raw))
    }

    private static func typed(_ raw: RawItem) -> ITunesItem? {
        let wrapper = raw.wrapperType?.lowercased()
        let kind = raw.kind?.lowercased()
        switch wrapper {
        case "artist":
            return Artist(raw).map(ITunesItem.artist)
        case "collection":
            // TV seasons are collections too.
            if let type = raw.collectionType?.lowercased(), type.contains("tv") {
                return nil
            }
            return Album(raw).map(ITunesItem.album)
        case "audiobook":
            return Audiobook(raw).map(ITunesItem.audiobook)
        case "podcastepisode":
            return PodcastEpisode(raw).map(ITunesItem.podcastEpisode)
        case "software":
            return Software(raw).map(ITunesItem.software)
        default:
            break
        }
        switch kind {
        case "song":
            return Song(raw).map(ITunesItem.song)
        case "music-video":
            return MusicVideo(raw).map(ITunesItem.musicVideo)
        case "podcast":
            return Podcast(raw).map(ITunesItem.podcast)
        case "podcast-episode":
            return PodcastEpisode(raw).map(ITunesItem.podcastEpisode)
        case "feature-movie":
            return Movie(raw).map(ITunesItem.movie)
        case "ebook":
            return Ebook(raw).map(ITunesItem.ebook)
        case "software", "mac-software":
            return Software(raw).map(ITunesItem.software)
        default:
            return nil
        }
    }

    // MARK: - Shared properties

    /// Unique across kinds, such as `"song-617154366"`; ids of different kinds can collide in the API.
    public var id: String {
        switch self {
        case let .song(item): "song-\(item.id)"
        case let .musicVideo(item): "musicVideo-\(item.id)"
        case let .album(item): "album-\(item.id)"
        case let .artist(item): "artist-\(item.id)"
        case let .podcast(item): "podcast-\(item.id)"
        case let .podcastEpisode(item): "podcastEpisode-\(item.id)"
        case let .movie(item): "movie-\(item.id)"
        case let .ebook(item): "ebook-\(item.id)"
        case let .audiobook(item): "audiobook-\(item.id)"
        case let .software(item): "software-\(item.id)"
        case let .other(item): "other-\(item.id)"
        }
    }

    /// The iTunes id of the item itself: a `trackId`, `collectionId` or `artistId`.
    public var itemID: Int? {
        switch self {
        case let .song(item): item.id
        case let .musicVideo(item): item.id
        case let .album(item): item.id
        case let .artist(item): item.id
        case let .podcast(item): item.id
        case let .podcastEpisode(item): item.id
        case let .movie(item): item.id
        case let .ebook(item): item.id
        case let .audiobook(item): item.id
        case let .software(item): item.id
        case let .other(item): item.itemID
        }
    }

    public var kind: ITunesItemKind {
        switch self {
        case .song: .song
        case .musicVideo: .musicVideo
        case .album: .album
        case .artist: .artist
        case .podcast: .podcast
        case .podcastEpisode: .podcastEpisode
        case .movie: .movie
        case .ebook: .ebook
        case .audiobook: .audiobook
        case .software: .software
        case .other: .other
        }
    }

    /// The title: a song, album, podcast, movie, book or app name, or an artist's name.
    public var name: String {
        switch self {
        case let .song(item): item.name
        case let .musicVideo(item): item.name
        case let .album(item): item.name
        case let .artist(item): item.name
        case let .podcast(item): item.name
        case let .podcastEpisode(item): item.name
        case let .movie(item): item.name
        case let .ebook(item): item.name
        case let .audiobook(item): item.name
        case let .software(item): item.name
        case let .other(item): item.name ?? ""
        }
    }

    /// Who made it: the artist, publisher, director, author or developer. `nil` for artists.
    public var creator: String? {
        let value: String? = switch self {
        case let .song(item): item.artistName
        case let .musicVideo(item): item.artistName
        case let .album(item): item.artistName
        case .artist: nil
        case let .podcast(item): item.artistName
        case let .podcastEpisode(item): item.podcastName
        case let .movie(item): item.director
        case let .ebook(item): item.author
        case let .audiobook(item): item.author
        case let .software(item): item.developer
        case let .other(item): item.artistName
        }
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// The artwork. Artists have none.
    public var artwork: Artwork? {
        switch self {
        case let .song(item): item.artwork
        case let .musicVideo(item): item.artwork
        case let .album(item): item.artwork
        case .artist: nil
        case let .podcast(item): item.artwork
        case let .podcastEpisode(item): item.artwork
        case let .movie(item): item.artwork
        case let .ebook(item): item.artwork
        case let .audiobook(item): item.artwork
        case let .software(item): item.artwork
        case let .other(item): item.artwork
        }
    }

    /// A playable preview: audio for songs, audiobooks and episodes, video for music videos and movie trailers.
    public var previewURL: URL? {
        switch self {
        case let .song(item): item.previewURL
        case let .musicVideo(item): item.previewURL
        case let .podcastEpisode(item): item.previewURL ?? item.episodeURL
        case let .movie(item): item.previewURL
        case let .audiobook(item): item.previewURL
        case let .other(item): item.previewURL
        case .album, .artist, .podcast, .ebook, .software: nil
        }
    }

    /// Whether ``previewURL`` is a video.
    public var hasVideoPreview: Bool {
        switch self {
        case .musicVideo, .movie: true
        case let .podcastEpisode(item): item.contentType == "video"
        default: false
        }
    }

    /// The item's page in the store.
    public var storeURL: URL? {
        switch self {
        case let .song(item): item.storeURL
        case let .musicVideo(item): item.storeURL
        case let .album(item): item.storeURL
        case let .artist(item): item.storeURL
        case let .podcast(item): item.storeURL
        case let .podcastEpisode(item): item.storeURL
        case let .movie(item): item.storeURL
        case let .ebook(item): item.storeURL
        case let .audiobook(item): item.storeURL
        case let .software(item): item.storeURL
        case let .other(item): item.storeURL
        }
    }

    public var releaseDate: Date? {
        switch self {
        case let .song(item): item.releaseDate
        case let .musicVideo(item): item.releaseDate
        case let .album(item): item.releaseDate
        case .artist: nil
        case let .podcast(item): item.releaseDate
        case let .podcastEpisode(item): item.releaseDate
        case let .movie(item): item.releaseDate
        case let .ebook(item): item.releaseDate
        case let .audiobook(item): item.releaseDate
        case let .software(item): item.releaseDate
        case let .other(item): item.releaseDate
        }
    }

    /// The year of ``releaseDate``.
    public var releaseYear: Int? {
        releaseDate.map(ITunesFormat.year(of:))
    }

    public var genre: String? {
        switch self {
        case let .song(item): item.genre
        case let .musicVideo(item): item.genre
        case let .album(item): item.genre
        case let .artist(item): item.genre
        case let .podcast(item): item.genre
        case let .podcastEpisode(item): item.genres.first
        case let .movie(item): item.genre
        case let .ebook(item): item.genres.first
        case let .audiobook(item): item.genre
        case let .software(item): item.genre
        case let .other(item): item.genre
        }
    }

    /// The running time in seconds, for songs, music videos, episodes and movies.
    public var duration: TimeInterval? {
        switch self {
        case let .song(item): item.duration
        case let .musicVideo(item): item.duration
        case let .podcastEpisode(item): item.duration
        case let .movie(item): item.duration
        default: nil
        }
    }

    /// Whether the item is marked explicit.
    public var isExplicit: Bool {
        switch self {
        case let .song(item): item.explicitness == .explicit
        case let .musicVideo(item): item.explicitness == .explicit
        case let .album(item): item.explicitness == .explicit
        case let .podcast(item): item.explicitness == .explicit
        default: false
        }
    }

    // MARK: - Typed access

    // Named `asSong` and so on, because a property cannot share its name with a case.

    public var asSong: Song? {
        if case let .song(item) = self { item } else { nil }
    }

    public var asMusicVideo: MusicVideo? {
        if case let .musicVideo(item) = self { item } else { nil }
    }

    public var asAlbum: Album? {
        if case let .album(item) = self { item } else { nil }
    }

    public var asArtist: Artist? {
        if case let .artist(item) = self { item } else { nil }
    }

    public var asPodcast: Podcast? {
        if case let .podcast(item) = self { item } else { nil }
    }

    public var asPodcastEpisode: PodcastEpisode? {
        if case let .podcastEpisode(item) = self { item } else { nil }
    }

    public var asMovie: Movie? {
        if case let .movie(item) = self { item } else { nil }
    }

    public var asEbook: Ebook? {
        if case let .ebook(item) = self { item } else { nil }
    }

    public var asAudiobook: Audiobook? {
        if case let .audiobook(item) = self { item } else { nil }
    }

    public var asSoftware: Software? {
        if case let .software(item) = self { item } else { nil }
    }
}
