import Foundation

/// A price in the store's currency, such as 1.29 USD.
public struct Price: Sendable, Hashable {
    public let amount: Double
    /// An ISO 4217 code such as `"USD"`.
    public let currency: String

    public init(amount: Double, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    /// `nil` when the API has no price: no amount, no currency, or a negative amount (not sold on its own).
    init?(amount: Double?, currency: String?) {
        guard let amount, amount >= 0, amount.isFinite, let currency, !currency.isEmpty else { return nil }
        self.init(amount: amount, currency: currency)
    }

    public var isFree: Bool {
        amount == 0
    }

    /// `"Free"`, or the amount in the currency, such as `"$1.29"` for `en_US`.
    public func formatted(locale: Locale = .current) -> String {
        if isFree {
            return "Free"
        }
        return amount.formatted(.currency(code: currency).locale(locale))
    }
}

/// Whether a track or collection has explicit lyrics or content.
public enum Explicitness: String, Sendable, Hashable, CaseIterable {
    /// Explicit content.
    case explicit
    /// A clean version of something explicit.
    case cleaned
    /// No explicit content.
    case notExplicit

    public var isExplicit: Bool {
        self == .explicit
    }
}

/// The kinds of items the API returns, with a title and an SF Symbol for each.
public enum ITunesItemKind: String, Sendable, Hashable, CaseIterable {
    case song
    case musicVideo
    case album
    case artist
    case podcast
    case podcastEpisode
    case movie
    case ebook
    case audiobook
    case software
    case other

    /// A singular title such as `"Song"` or `"App"`.
    public var title: String {
        switch self {
        case .song: "Song"
        case .musicVideo: "Music Video"
        case .album: "Album"
        case .artist: "Artist"
        case .podcast: "Podcast"
        case .podcastEpisode: "Episode"
        case .movie: "Movie"
        case .ebook: "Book"
        case .audiobook: "Audiobook"
        case .software: "App"
        case .other: "Item"
        }
    }

    /// An SF Symbol name for the kind.
    public var systemImage: String {
        switch self {
        case .song: "music.note"
        case .musicVideo: "music.note.tv"
        case .album: "square.stack"
        case .artist: "music.mic"
        case .podcast: "mic"
        case .podcastEpisode: "waveform"
        case .movie: "film"
        case .ebook: "book"
        case .audiobook: "headphones"
        case .software: "app"
        case .other: "questionmark.square"
        }
    }
}
