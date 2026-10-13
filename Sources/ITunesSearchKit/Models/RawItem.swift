import Foundation

/// One entry of `results`, with every field the API uses for any kind of item, all optional.
///
/// The API's types are loose (`fileSizeBytes` is a string for apps, `genres` a list of strings or of objects), so
/// every field is read leniently: a value of an unexpected type is `nil` instead of failing the whole response.
struct RawItem: Decodable, Sendable {
    var wrapperType: String?
    var kind: String?
    var collectionType: String?
    var artistType: String?

    var artistId: Int?
    var collectionId: Int?
    var trackId: Int?
    var amgArtistId: Int?
    var artistIds: [Int]?

    var artistName: String?
    var collectionName: String?
    var trackName: String?
    var collectionCensoredName: String?
    var trackCensoredName: String?
    var collectionArtistName: String?
    var sellerName: String?

    var artistViewUrl: URL?
    var collectionViewUrl: URL?
    var trackViewUrl: URL?
    var artistLinkUrl: URL?
    var sellerUrl: URL?
    var previewUrl: URL?
    var feedUrl: URL?
    var episodeUrl: URL?

    var artworkUrl30: URL?
    var artworkUrl60: URL?
    var artworkUrl100: URL?
    var artworkUrl160: URL?
    var artworkUrl512: URL?
    var artworkUrl600: URL?
    var screenshotUrls: [URL]
    var ipadScreenshotUrls: [URL]

    var collectionPrice: Double?
    var trackPrice: Double?
    var trackRentalPrice: Double?
    var collectionHdPrice: Double?
    var trackHdPrice: Double?
    var price: Double?
    var formattedPrice: String?
    var currency: String?

    var releaseDate: Date?
    var currentVersionReleaseDate: Date?
    var collectionExplicitness: String?
    var trackExplicitness: String?
    var contentAdvisoryRating: String?
    var trackContentRating: String?

    var discCount: Int?
    var discNumber: Int?
    var trackCount: Int?
    var trackNumber: Int?
    var trackTimeMillis: Double?
    var isStreamable: Bool?

    var country: String?
    var primaryGenreName: String?
    var genres: [String]
    var copyright: String?
    var shortDescription: String?
    var longDescription: String?
    var description: String?

    var episodeFileExtension: String?
    var episodeContentType: String?
    var episodeGuid: String?

    var bundleId: String?
    var version: String?
    var releaseNotes: String?
    var averageUserRating: Double?
    var userRatingCount: Int?
    var minimumOsVersion: String?
    var fileSizeBytes: Int64?
    var supportedDevices: [String]
    var languageCodesISO2A: [String]

    enum CodingKeys: String, CodingKey {
        case wrapperType, kind, collectionType, artistType
        case artistId, collectionId, trackId, amgArtistId, artistIds
        case artistName, collectionName, trackName, collectionCensoredName, trackCensoredName, collectionArtistName
        case sellerName
        case artistViewUrl, collectionViewUrl, trackViewUrl, artistLinkUrl, sellerUrl, previewUrl, feedUrl, episodeUrl
        case artworkUrl30, artworkUrl60, artworkUrl100, artworkUrl160, artworkUrl512, artworkUrl600
        case screenshotUrls, ipadScreenshotUrls
        case collectionPrice, trackPrice, trackRentalPrice, collectionHdPrice, trackHdPrice, price, formattedPrice
        case currency
        case releaseDate, currentVersionReleaseDate
        case collectionExplicitness, trackExplicitness, contentAdvisoryRating, trackContentRating
        case discCount, discNumber, trackCount, trackNumber, trackTimeMillis, isStreamable
        case country, primaryGenreName, genres, copyright, shortDescription, longDescription, description
        case episodeFileExtension, episodeContentType, episodeGuid
        case bundleId, version, releaseNotes, averageUserRating, userRatingCount, minimumOsVersion, fileSizeBytes
        case supportedDevices, languageCodesISO2A
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wrapperType = c.lenientString(.wrapperType)
        kind = c.lenientString(.kind)
        collectionType = c.lenientString(.collectionType)
        artistType = c.lenientString(.artistType)

        artistId = c.lenientInt(.artistId)
        collectionId = c.lenientInt(.collectionId)
        trackId = c.lenientInt(.trackId)
        amgArtistId = c.lenientInt(.amgArtistId)
        artistIds = try? c.decodeIfPresent([Int].self, forKey: .artistIds)

        artistName = c.lenientString(.artistName)
        collectionName = c.lenientString(.collectionName)
        trackName = c.lenientString(.trackName)
        collectionCensoredName = c.lenientString(.collectionCensoredName)
        trackCensoredName = c.lenientString(.trackCensoredName)
        collectionArtistName = c.lenientString(.collectionArtistName)
        sellerName = c.lenientString(.sellerName)

        artistViewUrl = c.lenientURL(.artistViewUrl)
        collectionViewUrl = c.lenientURL(.collectionViewUrl)
        trackViewUrl = c.lenientURL(.trackViewUrl)
        artistLinkUrl = c.lenientURL(.artistLinkUrl)
        sellerUrl = c.lenientURL(.sellerUrl)
        previewUrl = c.lenientURL(.previewUrl)
        feedUrl = c.lenientURL(.feedUrl)
        episodeUrl = c.lenientURL(.episodeUrl)

        artworkUrl30 = c.lenientURL(.artworkUrl30)
        artworkUrl60 = c.lenientURL(.artworkUrl60)
        artworkUrl100 = c.lenientURL(.artworkUrl100)
        artworkUrl160 = c.lenientURL(.artworkUrl160)
        artworkUrl512 = c.lenientURL(.artworkUrl512)
        artworkUrl600 = c.lenientURL(.artworkUrl600)
        screenshotUrls = c.lenientURLs(.screenshotUrls)
        ipadScreenshotUrls = c.lenientURLs(.ipadScreenshotUrls)

        collectionPrice = c.lenientDouble(.collectionPrice)
        trackPrice = c.lenientDouble(.trackPrice)
        trackRentalPrice = c.lenientDouble(.trackRentalPrice)
        collectionHdPrice = c.lenientDouble(.collectionHdPrice)
        trackHdPrice = c.lenientDouble(.trackHdPrice)
        price = c.lenientDouble(.price)
        formattedPrice = c.lenientString(.formattedPrice)
        currency = c.lenientString(.currency)

        releaseDate = c.lenientString(.releaseDate).flatMap(ITunesDate.parse)
        currentVersionReleaseDate = c.lenientString(.currentVersionReleaseDate).flatMap(ITunesDate.parse)
        collectionExplicitness = c.lenientString(.collectionExplicitness)
        trackExplicitness = c.lenientString(.trackExplicitness)
        contentAdvisoryRating = c.lenientString(.contentAdvisoryRating)
        trackContentRating = c.lenientString(.trackContentRating)

        discCount = c.lenientInt(.discCount)
        discNumber = c.lenientInt(.discNumber)
        trackCount = c.lenientInt(.trackCount)
        trackNumber = c.lenientInt(.trackNumber)
        trackTimeMillis = c.lenientDouble(.trackTimeMillis)
        isStreamable = try? c.decodeIfPresent(Bool.self, forKey: .isStreamable)

        country = c.lenientString(.country)
        primaryGenreName = c.lenientString(.primaryGenreName)
        genres = c.lenientGenres(.genres)
        copyright = c.lenientString(.copyright)
        shortDescription = c.lenientString(.shortDescription)
        longDescription = c.lenientString(.longDescription)
        description = c.lenientString(.description)

        episodeFileExtension = c.lenientString(.episodeFileExtension)
        episodeContentType = c.lenientString(.episodeContentType)
        episodeGuid = c.lenientString(.episodeGuid)

        bundleId = c.lenientString(.bundleId)
        version = c.lenientString(.version)
        releaseNotes = c.lenientString(.releaseNotes)
        averageUserRating = c.lenientDouble(.averageUserRating)
        userRatingCount = c.lenientInt(.userRatingCount)
        minimumOsVersion = c.lenientString(.minimumOsVersion)
        fileSizeBytes = c.lenientDouble(.fileSizeBytes).flatMap { $0.isFinite && $0 >= 0 && $0 < 9e18 ? Int64($0) : nil }
        supportedDevices = (try? c.decodeIfPresent([String].self, forKey: .supportedDevices)) ?? []
        languageCodesISO2A = (try? c.decodeIfPresent([String].self, forKey: .languageCodesISO2A)) ?? []
    }

    // MARK: - Shared pieces of the typed models

    /// The largest artwork URL in the item.
    var artwork: Artwork? {
        Artwork.best([artworkUrl600, artworkUrl512, artworkUrl160, artworkUrl100, artworkUrl60, artworkUrl30])
    }

    var securePreviewURL: URL? {
        previewUrl.map(Artwork.secure)
    }

    var duration: TimeInterval? {
        guard let trackTimeMillis, trackTimeMillis > 0 else { return nil }
        return trackTimeMillis / 1000
    }

    func makePrice(_ amount: Double?) -> Price? {
        Price(amount: amount, currency: currency)
    }

    var trackExplicitnessValue: Explicitness? {
        trackExplicitness.flatMap(Explicitness.init(rawValue:))
    }

    var collectionExplicitnessValue: Explicitness? {
        collectionExplicitness.flatMap(Explicitness.init(rawValue:))
    }

    /// `primaryGenreName`, or the first of `genres`.
    var genre: String? {
        primaryGenreName ?? genres.first
    }

    /// `genres`, or `primaryGenreName` alone.
    var allGenres: [String] {
        if !genres.isEmpty {
            return genres
        }
        return primaryGenreName.map { [$0] } ?? []
    }
}

private struct GenreObject: Decodable {
    let name: String
}

extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            if number.isFinite, number.rounded() == number, abs(number) < 9e15 {
                return String(Int64(number))
            }
            return String(number)
        }
        return nil
    }

    func lenientInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key), double.isFinite, abs(double) < 9e15 {
            return Int(double)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Int(string.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    func lenientDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Double(string.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    func lenientURL(_ key: Key) -> URL? {
        guard let string = lenientString(key)?.trimmingCharacters(in: .whitespaces), !string.isEmpty else { return nil }
        return URL(string: string)
    }

    func lenientURLs(_ key: Key) -> [URL] {
        let strings = (try? decodeIfPresent([String].self, forKey: key)) ?? []
        return strings.compactMap { URL(string: $0) }.map(Artwork.secure)
    }

    /// `["Pop", "Music"]`, or `[{"name": "News", "id": "1489"}]` as podcast episodes send it.
    func lenientGenres(_ key: Key) -> [String] {
        if let names = try? decodeIfPresent([String].self, forKey: key) {
            return names
        }
        if let objects = try? decodeIfPresent([GenreObject].self, forKey: key) {
            return objects.map(\.name)
        }
        return []
    }
}
