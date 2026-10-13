import Foundation

/// A lookup by identifier, sent to `GET /lookup`.
///
/// ```swift
/// // An album and its songs
/// let album = try await client.lookup(LookupRequest(.id([617154241]), entity: .song))
/// // A book by ISBN, an album by UPC, an app by bundle identifier
/// let book = try await client.lookup(LookupRequest(.isbn(["9780316069359"])))
/// ```
public struct LookupRequest: Sendable, Hashable {
    /// What to look up. Each case takes one or more values, sent comma separated.
    public enum Key: Sendable, Hashable {
        /// iTunes ids: `trackId`, `collectionId` or `artistId`.
        case id([Int])
        /// AMG artist ids.
        case amgArtistID([Int])
        /// AMG album ids.
        case amgAlbumID([Int])
        /// UPC or EAN barcodes of albums.
        case upc([String])
        /// ISBN-10 or ISBN-13 of books. Hyphens and spaces are removed.
        case isbn([String])
        /// App bundle identifiers, such as `com.apple.Pages`.
        case bundleID([String])

        var parameter: String {
            switch self {
            case .id: "id"
            case .amgArtistID: "amgArtistId"
            case .amgAlbumID: "amgAlbumId"
            case .upc: "upc"
            case .isbn: "isbn"
            case .bundleID: "bundleId"
            }
        }

        var values: [String] {
            switch self {
            case let .id(ids), let .amgArtistID(ids), let .amgAlbumID(ids):
                ids.map { String($0) }
            case let .upc(codes):
                codes.map { $0.trimmingCharacters(in: .whitespaces) }
            case let .isbn(codes):
                codes.map(LookupRequest.normalizedISBN)
            case let .bundleID(identifiers):
                identifiers.map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
    }

    public var key: Key
    /// Related results to include, such as the songs of an album (`.song`) or the albums of an artist (`.album`).
    public var entity: ITunesEntity?
    /// How many related results to include.
    public var limit: Int?
    /// The order of the related results.
    public var sort: LookupSort?
    /// The two-letter store country. `nil` uses the client's ``ITunesConfiguration/country``.
    public var country: String?

    public init(
        _ key: Key,
        entity: ITunesEntity? = nil,
        limit: Int? = nil,
        sort: LookupSort? = nil,
        country: String? = nil
    ) {
        self.key = key
        self.entity = entity
        self.limit = limit
        self.sort = sort
        self.country = country
    }

    /// Throws ``ITunesError/invalidRequest(_:)`` when there is nothing to look up, a value is malformed, the limit is
    /// outside 1...200 or the country is not two letters.
    public func validate() throws {
        let values = key.values
        guard !values.isEmpty, !values.contains(where: \.isEmpty) else {
            throw ITunesError.invalidRequest("A lookup needs at least one \(key.parameter).")
        }
        switch key {
        case let .id(ids), let .amgArtistID(ids), let .amgAlbumID(ids):
            if let bad = ids.first(where: { $0 <= 0 }) {
                throw ITunesError.invalidRequest("\(bad) is not a valid \(key.parameter).")
            }
        case .upc:
            if let bad = values.first(where: { !$0.allSatisfy(\.isASCIIDigit) || !(8...14).contains($0.count) }) {
                throw ITunesError.invalidRequest("\(bad) is not a valid UPC or EAN.")
            }
        case .isbn:
            if let bad = values.first(where: { !LookupRequest.isValidISBN($0) }) {
                throw ITunesError.invalidRequest("\(bad) is not a valid ISBN-10 or ISBN-13.")
            }
        case .bundleID:
            break
        }
        if let limit, !(1...SearchRequest.maximumLimit).contains(limit) {
            throw ITunesError.invalidRequest("The limit must be between 1 and \(SearchRequest.maximumLimit), not \(limit).")
        }
        if let country, !CountryCode.isValid(country) {
            throw ITunesError.invalidRequest("The country must be a two-letter code such as US, not \(country).")
        }
    }

    /// The query items, in a fixed order. The client adds its default country when ``country`` is `nil`.
    public var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: key.parameter, value: key.values.joined(separator: ","))]
        if let entity {
            items.append(URLQueryItem(name: "entity", value: entity.rawValue))
        }
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let sort {
            items.append(URLQueryItem(name: "sort", value: sort.rawValue))
        }
        if let country {
            items.append(URLQueryItem(name: "country", value: country.uppercased()))
        }
        return items
    }

    /// The ISBN without hyphens and spaces, with a lowercase check digit `x` in capitals.
    static func normalizedISBN(_ isbn: String) -> String {
        String(isbn.filter { $0 != "-" && !$0.isWhitespace }).uppercased()
    }

    /// Ten characters (nine digits and a digit or X) or thirteen digits.
    static func isValidISBN(_ isbn: String) -> Bool {
        let characters = Array(isbn)
        switch characters.count {
        case 13:
            return characters.allSatisfy(\.isASCIIDigit)
        case 10:
            return characters.dropLast().allSatisfy(\.isASCIIDigit) && (characters[9].isASCIIDigit || characters[9] == "X")
        default:
            return false
        }
    }
}

extension Character {
    /// `0` to `9` only, unlike `isNumber`, which also accepts other scripts' digits and fractions.
    var isASCIIDigit: Bool {
        isASCII && isWholeNumber
    }
}
