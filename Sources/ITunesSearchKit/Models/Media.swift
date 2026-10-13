import Foundation

/// A podcast (`wrapperType` `track`, `kind` `podcast`).
public struct Podcast: Sendable, Hashable, Identifiable {
    /// The `collectionId`, which is also the `trackId`. Look up the episodes with ``ITunesClient/podcast(id:episodeLimit:country:)``.
    public let id: Int
    public let name: String
    /// The publisher, such as `"The New York Times"`.
    public let artistName: String
    public let artistID: Int?
    public let artwork: Artwork?
    /// The RSS feed.
    public let feedURL: URL?
    public let storeURL: URL?
    /// The date of the latest episode.
    public let releaseDate: Date?
    public let genre: String?
    public let genres: [String]
    /// The number of episodes in the store.
    public let episodeCount: Int?
    public let explicitness: Explicitness?
    public let contentAdvisoryRating: String?
    public let country: String?

    init?(_ raw: RawItem) {
        guard let id = raw.collectionId ?? raw.trackId, let name = raw.collectionName ?? raw.trackName else { return nil }
        self.id = id
        self.name = name
        artistName = raw.artistName ?? ""
        artistID = raw.artistId
        artwork = raw.artwork
        feedURL = raw.feedUrl
        storeURL = raw.collectionViewUrl ?? raw.trackViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
        genres = raw.allGenres.filter { $0 != "Podcasts" }
        episodeCount = raw.trackCount
        explicitness = raw.collectionExplicitnessValue ?? raw.trackExplicitnessValue
        contentAdvisoryRating = raw.contentAdvisoryRating
        country = raw.country
    }
}

/// An episode of a podcast (`wrapperType` `podcastEpisode`, `kind` `podcast-episode`).
public struct PodcastEpisode: Sendable, Hashable, Identifiable {
    /// The `trackId`.
    public let id: Int
    public let name: String
    /// The `collectionId` of the podcast.
    public let podcastID: Int?
    public let podcastName: String?
    public let artwork: Artwork?
    /// The full episode audio (or video), from the podcast's feed.
    public let episodeURL: URL?
    /// A preview, usually the same file as ``episodeURL``.
    public let previewURL: URL?
    public let storeURL: URL?
    public let releaseDate: Date?
    public let duration: TimeInterval?
    /// The episode notes, sometimes with light HTML.
    public let description: String?
    public let shortDescription: String?
    /// The file extension of ``episodeURL``, such as `"mp3"`.
    public let fileExtension: String?
    /// `"audio"` or `"video"`.
    public let contentType: String?
    public let guid: String?
    public let genres: [String]
    public let country: String?

    init?(_ raw: RawItem) {
        guard let id = raw.trackId, let name = raw.trackName else { return nil }
        self.id = id
        self.name = name
        podcastID = raw.collectionId
        podcastName = raw.collectionName
        artwork = raw.artwork
        episodeURL = raw.episodeUrl
        previewURL = raw.securePreviewURL
        storeURL = raw.trackViewUrl
        releaseDate = raw.releaseDate
        duration = raw.duration
        description = raw.description
        shortDescription = raw.shortDescription
        fileExtension = raw.episodeFileExtension
        contentType = raw.episodeContentType
        guid = raw.episodeGuid
        genres = raw.allGenres
        country = raw.country
    }

    /// ``description`` (or ``shortDescription``) without HTML.
    public var plainDescription: String? {
        (description ?? shortDescription).map(ITunesText.plainText(fromHTML:))
    }
}

/// A feature film (`wrapperType` `track`, `kind` `feature-movie`).
public struct Movie: Sendable, Hashable, Identifiable {
    /// The `trackId`.
    public let id: Int
    public let name: String
    /// The director (`artistName`).
    public let director: String?
    public let artwork: Artwork?
    /// The trailer.
    public let previewURL: URL?
    public let storeURL: URL?
    public let releaseDate: Date?
    public let genre: String?
    public let duration: TimeInterval?
    /// The rating, such as `"PG-13"`.
    public let contentRating: String?
    public let shortDescription: String?
    public let longDescription: String?
    public let price: Price?
    public let rentalPrice: Price?
    public let hdPrice: Price?
    public let country: String?

    init?(_ raw: RawItem) {
        guard let id = raw.trackId, let name = raw.trackName else { return nil }
        self.id = id
        self.name = name
        director = raw.artistName
        artwork = raw.artwork
        previewURL = raw.securePreviewURL
        storeURL = raw.trackViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
        duration = raw.duration
        contentRating = raw.contentAdvisoryRating
        shortDescription = raw.shortDescription
        longDescription = raw.longDescription
        price = raw.makePrice(raw.trackPrice ?? raw.collectionPrice)
        rentalPrice = raw.makePrice(raw.trackRentalPrice)
        hdPrice = raw.makePrice(raw.trackHdPrice ?? raw.collectionHdPrice)
        country = raw.country
    }
}

/// A book (`kind` `ebook`).
public struct Ebook: Sendable, Hashable, Identifiable {
    /// The `trackId`.
    public let id: Int
    public let name: String
    public let author: String
    public let authorID: Int?
    public let artwork: Artwork?
    public let storeURL: URL?
    public let releaseDate: Date?
    public let genres: [String]
    /// The description, with light HTML. See ``plainDescription``.
    public let description: String?
    public let averageRating: Double?
    public let ratingCount: Int?
    public let price: Price?
    /// The price as the store shows it, such as `"Free"` or `"$9.99"`.
    public let formattedPrice: String?
    public let fileSize: Int64?

    init?(_ raw: RawItem) {
        guard let id = raw.trackId, let name = raw.trackName else { return nil }
        self.id = id
        self.name = name
        author = raw.artistName ?? ""
        authorID = raw.artistId
        artwork = raw.artwork
        storeURL = raw.trackViewUrl
        releaseDate = raw.releaseDate
        genres = raw.allGenres
        description = raw.description
        averageRating = raw.averageUserRating
        ratingCount = raw.userRatingCount
        price = raw.makePrice(raw.price ?? raw.trackPrice)
        formattedPrice = raw.formattedPrice
        fileSize = raw.fileSizeBytes
    }

    /// ``description`` without HTML.
    public var plainDescription: String? {
        description.map(ITunesText.plainText(fromHTML:))
    }
}

/// An audiobook (`wrapperType` `audiobook`).
public struct Audiobook: Sendable, Hashable, Identifiable {
    /// The `collectionId`.
    public let id: Int
    public let name: String
    public let author: String
    public let authorID: Int?
    public let artwork: Artwork?
    /// An audio preview.
    public let previewURL: URL?
    public let storeURL: URL?
    public let releaseDate: Date?
    public let genre: String?
    /// The description, with light HTML. See ``plainDescription``.
    public let description: String?
    public let copyright: String?
    public let price: Price?

    init?(_ raw: RawItem) {
        guard let id = raw.collectionId ?? raw.trackId, let name = raw.collectionName ?? raw.trackName else { return nil }
        self.id = id
        self.name = name
        author = raw.artistName ?? ""
        authorID = raw.artistId
        artwork = raw.artwork
        previewURL = raw.securePreviewURL
        storeURL = raw.collectionViewUrl ?? raw.trackViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
        description = raw.description
        copyright = raw.copyright
        price = raw.makePrice(raw.collectionPrice)
    }

    /// ``description`` without HTML.
    public var plainDescription: String? {
        description.map(ITunesText.plainText(fromHTML:))
    }
}

/// An app for iPhone, iPad, Apple Watch, Apple TV or the Mac (`wrapperType` `software`).
public struct Software: Sendable, Hashable, Identifiable {
    /// Where the app runs: `kind` `software` (iPhone, iPad and other devices) or `mac-software`.
    public enum Platform: String, Sendable, Hashable {
        case iOS = "software"
        case macOS = "mac-software"
    }

    /// The `trackId`.
    public let id: Int
    public let name: String
    public let bundleID: String?
    /// The developer as the store shows it (`artistName`).
    public let developer: String
    public let developerID: Int?
    /// The legal seller (`sellerName`).
    public let seller: String?
    public let platform: Platform?
    /// The app icon, at up to 512 × 512 as returned; ask ``Artwork/url(size:format:)`` for 1024.
    public let artwork: Artwork?
    public let storeURL: URL?
    public let sellerURL: URL?
    public let version: String?
    public let releaseNotes: String?
    public let description: String?
    /// The first release.
    public let releaseDate: Date?
    /// The release of the current version.
    public let currentVersionReleaseDate: Date?
    public let genre: String?
    public let genres: [String]
    public let averageRating: Double?
    public let ratingCount: Int?
    public let price: Price?
    public let formattedPrice: String?
    /// The age rating, such as `"4+"`.
    public let contentRating: String?
    public let minimumOSVersion: String?
    public let fileSize: Int64?
    public let screenshotURLs: [URL]
    public let iPadScreenshotURLs: [URL]
    public let supportedDevices: [String]
    /// ISO 639-1 codes in upper case, such as `["EN", "TR"]`.
    public let languages: [String]

    init?(_ raw: RawItem) {
        guard let id = raw.trackId, let name = raw.trackName else { return nil }
        self.id = id
        self.name = name
        bundleID = raw.bundleId
        developer = raw.artistName ?? raw.sellerName ?? ""
        developerID = raw.artistId
        seller = raw.sellerName
        platform = raw.kind.flatMap(Platform.init(rawValue:))
        artwork = raw.artwork
        storeURL = raw.trackViewUrl
        sellerURL = raw.sellerUrl
        version = raw.version
        releaseNotes = raw.releaseNotes
        description = raw.description
        releaseDate = raw.releaseDate
        currentVersionReleaseDate = raw.currentVersionReleaseDate
        genre = raw.genre
        genres = raw.allGenres
        averageRating = raw.averageUserRating
        ratingCount = raw.userRatingCount
        price = raw.makePrice(raw.price)
        formattedPrice = raw.formattedPrice
        contentRating = raw.trackContentRating ?? raw.contentAdvisoryRating
        minimumOSVersion = raw.minimumOsVersion
        fileSize = raw.fileSizeBytes
        screenshotURLs = raw.screenshotUrls
        iPadScreenshotURLs = raw.ipadScreenshotUrls
        supportedDevices = raw.supportedDevices
        languages = raw.languageCodesISO2A
    }
}

/// An item of a kind this package has no model for, such as a TV episode or an audiobook author, with the fields
/// most kinds share.
public struct UnknownItem: Sendable, Hashable, Identifiable {
    /// `"\(wrapperType)-\(kind)-\(id)"`, unique within a response.
    public let id: String
    public let wrapperType: String?
    public let kind: String?
    /// The `trackId`, `collectionId` or `artistId`, whichever comes first.
    public let itemID: Int?
    public let name: String?
    public let artistName: String?
    public let artwork: Artwork?
    public let previewURL: URL?
    public let storeURL: URL?
    public let releaseDate: Date?
    public let genre: String?

    init(_ raw: RawItem) {
        let itemID = raw.trackId ?? raw.collectionId ?? raw.artistId
        self.itemID = itemID
        wrapperType = raw.wrapperType
        kind = raw.kind
        id = [raw.wrapperType ?? "item", raw.kind ?? "unknown", itemID.map { String($0) } ?? UUID().uuidString]
            .joined(separator: "-")
        name = raw.trackName ?? raw.collectionName ?? raw.artistName
        artistName = raw.artistName
        artwork = raw.artwork
        previewURL = raw.securePreviewURL
        storeURL = raw.trackViewUrl ?? raw.collectionViewUrl ?? raw.artistLinkUrl ?? raw.artistViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
    }
}
