import Foundation

/// A search, sent to `GET /search`.
///
/// ```swift
/// var request = SearchRequest(term: "daft punk", entity: .song)
/// request.attribute = .artistTerm   // match artist names only
/// request.country = "GB"            // the UK store
/// request.limit = 25
/// let response = try await ITunesClient.shared.search(request)
/// ```
public struct SearchRequest: Sendable, Hashable {
    /// The text to search for. Spaces and symbols are encoded for you.
    public var term: String
    /// The kind of media. When `nil`, the media of ``entity`` is sent, or none at all (which means everything).
    public var media: ITunesMedia?
    /// The type of results, such as ``ITunesEntity/song`` or ``ITunesEntity/album``.
    public var entity: ITunesEntity?
    /// The field the term must match, such as ``ITunesAttribute/artistTerm``.
    public var attribute: ITunesAttribute?
    /// The two-letter store country. `nil` uses the client's ``ITunesConfiguration/country``.
    public var country: String?
    /// The language of the results. `nil` uses the client's ``ITunesConfiguration/language``.
    public var language: ITunesLanguage?
    /// How many results to return, 1 to 200. The API returns 50 when `nil`.
    public var limit: Int?
    /// Results to skip, for paging. The API does not document it, but honours it for most media.
    public var offset: Int?
    /// Whether explicit content is included. `true` by default, as in the API.
    public var allowsExplicit: Bool

    /// The most results one search can return.
    public static let maximumLimit = 200

    public init(
        term: String,
        media: ITunesMedia? = nil,
        entity: ITunesEntity? = nil,
        attribute: ITunesAttribute? = nil,
        country: String? = nil,
        language: ITunesLanguage? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        allowsExplicit: Bool = true
    ) {
        self.term = term
        self.media = media
        self.entity = entity
        self.attribute = attribute
        self.country = country
        self.language = language
        self.limit = limit
        self.offset = offset
        self.allowsExplicit = allowsExplicit
    }

    /// The term without surrounding white space.
    public var trimmedTerm: String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Throws ``ITunesError/invalidRequest(_:)`` for an empty term, a limit outside 1...200, a negative offset or a
    /// country that is not two letters.
    public func validate() throws {
        guard !trimmedTerm.isEmpty else {
            throw ITunesError.invalidRequest("The search term is empty.")
        }
        if let limit, !(1...Self.maximumLimit).contains(limit) {
            throw ITunesError.invalidRequest("The limit must be between 1 and \(Self.maximumLimit), not \(limit).")
        }
        if let offset, offset < 0 {
            throw ITunesError.invalidRequest("The offset must not be negative, not \(offset).")
        }
        if let country, !CountryCode.isValid(country) {
            throw ITunesError.invalidRequest("The country must be a two-letter code such as US, not \(country).")
        }
    }

    /// The query items, in a fixed order. The client adds its default country and language when these are `nil`.
    public var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "term", value: trimmedTerm)]
        if let media = media ?? entity?.media {
            items.append(URLQueryItem(name: "media", value: media.rawValue))
        }
        if let entity {
            items.append(URLQueryItem(name: "entity", value: entity.rawValue))
        }
        if let attribute {
            items.append(URLQueryItem(name: "attribute", value: attribute.rawValue))
        }
        if let country {
            items.append(URLQueryItem(name: "country", value: country.uppercased()))
        }
        if let language {
            items.append(URLQueryItem(name: "lang", value: language.rawValue))
        }
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset, offset > 0 {
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if !allowsExplicit {
            items.append(URLQueryItem(name: "explicit", value: "No"))
        }
        return items
    }
}
