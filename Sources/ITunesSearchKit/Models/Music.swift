import Foundation

/// A song (`wrapperType` `track`, `kind` `song`).
public struct Song: Sendable, Hashable, Identifiable {
    /// The `trackId`.
    public let id: Int
    public let name: String
    public let censoredName: String?
    public let artistID: Int?
    public let artistName: String
    /// The `collectionId` of the album the song is on.
    public let albumID: Int?
    public let albumName: String?
    public let artwork: Artwork?
    /// A 30-second (or so) AAC preview.
    public let previewURL: URL?
    /// The song's page in the store.
    public let storeURL: URL?
    public let artistURL: URL?
    public let albumURL: URL?
    public let releaseDate: Date?
    public let genre: String?
    /// The running time in seconds.
    public let duration: TimeInterval?
    public let trackNumber: Int?
    public let trackCount: Int?
    public let discNumber: Int?
    public let discCount: Int?
    public let explicitness: Explicitness?
    public let price: Price?
    public let albumPrice: Price?
    public let isStreamable: Bool?
    public let country: String?

    init?(_ raw: RawItem) {
        guard let id = raw.trackId, let name = raw.trackName else { return nil }
        self.id = id
        self.name = name
        censoredName = raw.trackCensoredName
        artistID = raw.artistId
        artistName = raw.artistName ?? ""
        albumID = raw.collectionId
        albumName = raw.collectionName
        artwork = raw.artwork
        previewURL = raw.securePreviewURL
        storeURL = raw.trackViewUrl
        artistURL = raw.artistViewUrl
        albumURL = raw.collectionViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
        duration = raw.duration
        trackNumber = raw.trackNumber
        trackCount = raw.trackCount
        discNumber = raw.discNumber
        discCount = raw.discCount
        explicitness = raw.trackExplicitnessValue
        price = raw.makePrice(raw.trackPrice)
        albumPrice = raw.makePrice(raw.collectionPrice)
        isStreamable = raw.isStreamable
        country = raw.country
    }

    public var isExplicit: Bool {
        explicitness?.isExplicit ?? false
    }
}

/// A music video (`wrapperType` `track`, `kind` `music-video`).
public struct MusicVideo: Sendable, Hashable, Identifiable {
    /// The `trackId`.
    public let id: Int
    public let name: String
    public let artistID: Int?
    public let artistName: String
    public let artwork: Artwork?
    /// A video preview.
    public let previewURL: URL?
    public let storeURL: URL?
    public let releaseDate: Date?
    public let genre: String?
    public let duration: TimeInterval?
    public let explicitness: Explicitness?
    public let price: Price?

    init?(_ raw: RawItem) {
        guard let id = raw.trackId, let name = raw.trackName else { return nil }
        self.id = id
        self.name = name
        artistID = raw.artistId
        artistName = raw.artistName ?? ""
        artwork = raw.artwork
        previewURL = raw.securePreviewURL
        storeURL = raw.trackViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
        duration = raw.duration
        explicitness = raw.trackExplicitnessValue
        price = raw.makePrice(raw.trackPrice)
    }
}

/// An album or compilation (`wrapperType` `collection`).
public struct Album: Sendable, Hashable, Identifiable {
    /// The `collectionId`.
    public let id: Int
    public let name: String
    public let censoredName: String?
    public let artistID: Int?
    public let artistName: String
    public let artwork: Artwork?
    public let storeURL: URL?
    public let artistURL: URL?
    public let releaseDate: Date?
    public let genre: String?
    public let trackCount: Int?
    public let explicitness: Explicitness?
    public let contentAdvisoryRating: String?
    public let copyright: String?
    public let price: Price?
    /// The `collectionType`, usually `"Album"` or `"Compilation"`.
    public let collectionType: String?
    public let country: String?

    init?(_ raw: RawItem) {
        guard let id = raw.collectionId, let name = raw.collectionName else { return nil }
        self.id = id
        self.name = name
        censoredName = raw.collectionCensoredName
        artistID = raw.artistId
        artistName = raw.artistName ?? raw.collectionArtistName ?? ""
        artwork = raw.artwork
        storeURL = raw.collectionViewUrl
        artistURL = raw.artistViewUrl
        releaseDate = raw.releaseDate
        genre = raw.genre
        trackCount = raw.trackCount
        explicitness = raw.collectionExplicitnessValue
        contentAdvisoryRating = raw.contentAdvisoryRating
        copyright = raw.copyright
        price = raw.makePrice(raw.collectionPrice)
        collectionType = raw.collectionType
        country = raw.country
    }

    public var isExplicit: Bool {
        explicitness?.isExplicit ?? false
    }
}

/// An artist or author (`wrapperType` `artist`). The API has no pictures of artists.
public struct Artist: Sendable, Hashable, Identifiable {
    /// The `artistId`.
    public let id: Int
    public let name: String
    /// The `artistType`, such as `"Artist"`, `"Author"` or `"Software Artist"`.
    public let artistType: String?
    public let storeURL: URL?
    public let genre: String?
    public let amgArtistID: Int?

    init?(_ raw: RawItem) {
        guard let id = raw.artistId, let name = raw.artistName else { return nil }
        self.id = id
        self.name = name
        artistType = raw.artistType
        storeURL = raw.artistLinkUrl ?? raw.artistViewUrl
        genre = raw.genre
        amgArtistID = raw.amgArtistId
    }
}
