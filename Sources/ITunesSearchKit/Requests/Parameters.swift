import Foundation

/// The kind of media to search, the `media` parameter.
public enum ITunesMedia: String, Sendable, Hashable, CaseIterable {
    case movie
    case podcast
    case music
    case musicVideo
    case audiobook
    case shortFilm
    case tvShow
    case software
    case ebook
    case all
}

/// The type of results, the `entity` parameter, such as songs instead of all music.
///
/// Every value Apple documents has a constant; any other string works too: `ITunesEntity("podcastEpisode")`.
public struct ITunesEntity: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }

    // Music
    public static let musicArtist: ITunesEntity = "musicArtist"
    public static let musicTrack: ITunesEntity = "musicTrack"
    public static let song: ITunesEntity = "song"
    public static let album: ITunesEntity = "album"
    public static let musicVideo: ITunesEntity = "musicVideo"
    public static let mix: ITunesEntity = "mix"
    // Movies
    public static let movieArtist: ITunesEntity = "movieArtist"
    public static let movie: ITunesEntity = "movie"
    // Podcasts
    public static let podcastAuthor: ITunesEntity = "podcastAuthor"
    public static let podcast: ITunesEntity = "podcast"
    public static let podcastEpisode: ITunesEntity = "podcastEpisode"
    // Audiobooks and books
    public static let audiobookAuthor: ITunesEntity = "audiobookAuthor"
    public static let audiobook: ITunesEntity = "audiobook"
    public static let ebook: ITunesEntity = "ebook"
    // Short films and TV
    public static let shortFilmArtist: ITunesEntity = "shortFilmArtist"
    public static let shortFilm: ITunesEntity = "shortFilm"
    public static let tvEpisode: ITunesEntity = "tvEpisode"
    public static let tvSeason: ITunesEntity = "tvSeason"
    // Apps
    public static let software: ITunesEntity = "software"
    public static let iPadSoftware: ITunesEntity = "iPadSoftware"
    public static let macSoftware: ITunesEntity = "macSoftware"
    // Everything
    public static let allArtist: ITunesEntity = "allArtist"
    public static let allTrack: ITunesEntity = "allTrack"

    private static let mediaByEntity: [String: ITunesMedia] = [
        "musicArtist": .music, "musicTrack": .music, "song": .music, "album": .music, "mix": .music,
        "musicVideo": .musicVideo,
        "movieArtist": .movie, "movie": .movie,
        "podcastAuthor": .podcast, "podcast": .podcast, "podcastEpisode": .podcast,
        "audiobookAuthor": .audiobook, "audiobook": .audiobook,
        "ebook": .ebook,
        "shortFilmArtist": .shortFilm, "shortFilm": .shortFilm,
        "tvEpisode": .tvShow, "tvSeason": .tvShow,
        "software": .software, "iPadSoftware": .software, "macSoftware": .software,
        "allArtist": .all, "allTrack": .all,
    ]

    /// The media this entity belongs to, which a ``SearchRequest`` sends when it names no media itself.
    /// `nil` for entities this package does not know.
    public var media: ITunesMedia? {
        Self.mediaByEntity[rawValue]
    }
}

/// The field to match the term against, the `attribute` parameter, such as only artist names.
///
/// Every value Apple documents has a constant; any other string works too.
public struct ITunesAttribute: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }

    public static let actorTerm: ITunesAttribute = "actorTerm"
    public static let albumTerm: ITunesAttribute = "albumTerm"
    public static let allArtistTerm: ITunesAttribute = "allArtistTerm"
    public static let allTrackTerm: ITunesAttribute = "allTrackTerm"
    public static let artistTerm: ITunesAttribute = "artistTerm"
    public static let authorTerm: ITunesAttribute = "authorTerm"
    public static let composerTerm: ITunesAttribute = "composerTerm"
    public static let descriptionTerm: ITunesAttribute = "descriptionTerm"
    public static let directorTerm: ITunesAttribute = "directorTerm"
    public static let featureFilmTerm: ITunesAttribute = "featureFilmTerm"
    public static let genreIndex: ITunesAttribute = "genreIndex"
    public static let keywordsTerm: ITunesAttribute = "keywordsTerm"
    public static let languageTerm: ITunesAttribute = "languageTerm"
    public static let mixTerm: ITunesAttribute = "mixTerm"
    public static let movieArtistTerm: ITunesAttribute = "movieArtistTerm"
    public static let movieTerm: ITunesAttribute = "movieTerm"
    public static let producerTerm: ITunesAttribute = "producerTerm"
    public static let ratingIndex: ITunesAttribute = "ratingIndex"
    public static let ratingTerm: ITunesAttribute = "ratingTerm"
    public static let releaseYearTerm: ITunesAttribute = "releaseYearTerm"
    public static let shortFilmTerm: ITunesAttribute = "shortFilmTerm"
    public static let showTerm: ITunesAttribute = "showTerm"
    public static let songTerm: ITunesAttribute = "songTerm"
    public static let titleTerm: ITunesAttribute = "titleTerm"
    public static let tvEpisodeTerm: ITunesAttribute = "tvEpisodeTerm"
    public static let tvSeasonTerm: ITunesAttribute = "tvSeasonTerm"
}

/// The language of the results, the `lang` parameter. The API knows English and Japanese.
public enum ITunesLanguage: String, Sendable, Hashable, CaseIterable {
    case english = "en_us"
    case japanese = "ja_jp"
}

/// The order of a lookup's related results, the `sort` parameter.
public enum LookupSort: String, Sendable, Hashable {
    /// Newest first, for example an artist's latest albums.
    case recent
}

enum CountryCode {
    /// Two ASCII letters, as the API expects (`US`, `gb`).
    static func isValid(_ code: String) -> Bool {
        code.count == 2 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }
}
