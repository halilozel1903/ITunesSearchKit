import CoreGraphics
import ITunesSearchKit

/// What the app searches for: one entity of the iTunes Search API each.
enum SearchCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case songs
    case albums
    case artists
    case podcasts
    case movies
    case books
    case apps

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .songs: "Songs"
        case .albums: "Albums"
        case .artists: "Artists"
        case .podcasts: "Podcasts"
        case .movies: "Movies"
        case .books: "Books"
        case .apps: "Apps"
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note"
        case .albums: "square.stack"
        case .artists: "music.mic"
        case .podcasts: "mic"
        case .movies: "film"
        case .books: "book"
        case .apps: "app.badge"
        }
    }

    var entity: ITunesEntity {
        switch self {
        case .songs: return .song
        case .albums: return .album
        case .artists: return .musicArtist
        case .podcasts: return .podcast
        case .movies: return .movie
        case .books: return .ebook
        case .apps:
            #if os(macOS)
            return .macSoftware
            #else
            return .software
            #endif
        }
    }

    var prompt: String {
        switch self {
        case .songs: "Songs, artists or albums"
        case .albums: "Albums or artists"
        case .artists: "Artists"
        case .podcasts: "Podcasts or publishers"
        case .movies: "Movies, directors or actors"
        case .books: "Books or authors"
        case .apps: "Apps or developers"
        }
    }

    /// Posters and book covers are portrait; everything else is square.
    var artworkAspectRatio: CGFloat {
        switch self {
        case .movies, .books: 2.0 / 3.0
        default: 1
        }
    }

    /// How many results a search asks for.
    var limit: Int {
        self == .artists ? 25 : 40
    }
}

extension ITunesItemKind {
    /// Posters and book covers are portrait; everything else is square.
    var artworkAspectRatio: CGFloat {
        switch self {
        case .movie, .ebook: 2.0 / 3.0
        default: 1
        }
    }

    /// App icons get the rounded square of an icon; covers get a small radius.
    var artworkCornerFraction: CGFloat {
        self == .software ? 0.225 : 0.04
    }
}
