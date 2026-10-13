import Foundation

/// A client for Apple's [iTunes Search API](https://performance-partners.apple.com/search-api).
///
/// Search and look up songs, albums, artists, podcasts, movies, books and apps. Every endpoint is an `async throws`
/// method returning typed models, and no key or account is needed.
///
/// ```swift
/// let itunes = ITunesClient()
/// let songs = try await itunes.songs(matching: "daft punk", limit: 10)
/// let album = try await itunes.album(id: songs[0].albumID!)
/// print(album.album.name, album.tracks.map(\.name))
/// print(songs[0].artwork?.url(size: 600) as Any)   // …/600x600bb.jpg
/// ```
///
/// One client can be shared by the whole app; it is `Sendable`. Apple limits the API to roughly 20 requests a minute;
/// set ``ITunesConfiguration/requestsPerMinute`` to stay under it, and the ``RetryPolicy`` retries when Apple says to
/// slow down.
public final class ITunesClient: Sendable {
    /// A client with the default configuration (the US store).
    public static let shared = ITunesClient()

    public let configuration: ITunesConfiguration
    private let throttle: RequestThrottle?

    public init(configuration: ITunesConfiguration = ITunesConfiguration()) {
        self.configuration = configuration
        self.throttle = configuration.requestsPerMinute.map { RequestThrottle(requestsPerMinute: $0) }
    }

    /// A client using `session`, with the default settings otherwise.
    public convenience init(session: URLSession) {
        self.init(configuration: ITunesConfiguration(session: session))
    }

    /// A client for another store country, such as `"GB"` or `"TR"`.
    public convenience init(country: String) {
        self.init(configuration: ITunesConfiguration(country: country))
    }

    // MARK: - Search

    /// Searches the store (`/search`).
    public func search(_ request: SearchRequest) async throws -> ITunesResponse {
        try request.validate()
        var query = request.queryItems
        if request.country == nil, let country = configuration.country {
            query.append(URLQueryItem(name: "country", value: country.uppercased()))
        }
        if request.language == nil, let language = configuration.language {
            query.append(URLQueryItem(name: "lang", value: language.rawValue))
        }
        return try await get(configuration.searchURL, query: query)
    }

    /// Searches the store and returns the results.
    ///
    /// ```swift
    /// let items = try await itunes.search("radiohead", entity: .album, limit: 20)
    /// ```
    public func search(
        _ term: String,
        media: ITunesMedia? = nil,
        entity: ITunesEntity? = nil,
        attribute: ITunesAttribute? = nil,
        country: String? = nil,
        limit: Int? = nil
    ) async throws -> [ITunesItem] {
        let request = SearchRequest(term: term, media: media, entity: entity, attribute: attribute, country: country, limit: limit)
        return try await search(request).items
    }

    /// Songs matching `term`.
    public func songs(matching term: String, attribute: ITunesAttribute? = nil, limit: Int = 25) async throws -> [Song] {
        try await search(SearchRequest(term: term, entity: .song, attribute: attribute, limit: limit)).songs
    }

    /// Albums matching `term`.
    public func albums(matching term: String, attribute: ITunesAttribute? = nil, limit: Int = 25) async throws -> [Album] {
        try await search(SearchRequest(term: term, entity: .album, attribute: attribute, limit: limit)).albums
    }

    /// Music artists matching `term`.
    public func artists(matching term: String, limit: Int = 25) async throws -> [Artist] {
        try await search(SearchRequest(term: term, entity: .musicArtist, limit: limit)).artists
    }

    /// Podcasts matching `term`.
    public func podcasts(matching term: String, limit: Int = 25) async throws -> [Podcast] {
        try await search(SearchRequest(term: term, entity: .podcast, limit: limit)).podcasts
    }

    /// Movies matching `term`.
    public func movies(matching term: String, limit: Int = 25) async throws -> [Movie] {
        try await search(SearchRequest(term: term, entity: .movie, limit: limit)).movies
    }

    /// Books matching `term`.
    public func ebooks(matching term: String, limit: Int = 25) async throws -> [Ebook] {
        try await search(SearchRequest(term: term, entity: .ebook, limit: limit)).ebooks
    }

    /// Apps matching `term`, for iPhone (`.iOS`, the default) or the Mac.
    public func apps(matching term: String, platform: Software.Platform = .iOS, limit: Int = 25) async throws -> [Software] {
        let entity: ITunesEntity = platform == .macOS ? .macSoftware : .software
        return try await search(SearchRequest(term: term, entity: entity, limit: limit)).apps
    }

    // MARK: - Lookup

    /// Looks items up by id, UPC, ISBN or bundle identifier (`/lookup`).
    public func lookup(_ request: LookupRequest) async throws -> ITunesResponse {
        try request.validate()
        var query = request.queryItems
        if request.country == nil, let country = configuration.country {
            query.append(URLQueryItem(name: "country", value: country.uppercased()))
        }
        return try await get(configuration.lookupURL, query: query)
    }

    /// The item with this iTunes id (a `trackId`, `collectionId` or `artistId`), or `nil`.
    public func lookup(id: Int, country: String? = nil) async throws -> ITunesItem? {
        try await lookup(LookupRequest(.id([id]), country: country)).items.first
    }

    /// The items with these iTunes ids, in the API's order. Unknown ids are left out.
    public func lookup(ids: [Int], country: String? = nil) async throws -> [ITunesItem] {
        try await lookup(LookupRequest(.id(ids), country: country)).items
    }

    /// The album with this barcode (UPC or EAN), or `nil`.
    public func album(upc: String, country: String? = nil) async throws -> Album? {
        try await lookup(LookupRequest(.upc([upc]), country: country)).albums.first
    }

    /// The book with this ISBN, or `nil`.
    public func ebook(isbn: String, country: String? = nil) async throws -> Ebook? {
        try await lookup(LookupRequest(.isbn([isbn]), country: country)).ebooks.first
    }

    /// The app with this bundle identifier, such as `"com.apple.Pages"`, or `nil`.
    public func app(bundleID: String, country: String? = nil) async throws -> Software? {
        try await lookup(LookupRequest(.bundleID([bundleID]), country: country)).apps.first
    }

    /// An album and its songs (a lookup of the `collectionId` with `entity=song`).
    /// Throws ``ITunesError/notFound(_:)`` when there is no such album.
    public func album(id: Int, country: String? = nil) async throws -> AlbumDetail {
        let response = try await lookup(LookupRequest(.id([id]), entity: .song, limit: SearchRequest.maximumLimit, country: country))
        guard let album = response.albums.first(where: { $0.id == id }) ?? response.albums.first else {
            throw ITunesError.notFound("album \(id)")
        }
        return AlbumDetail(album: album, tracks: response.songs.filter { $0.albumID == nil || $0.albumID == album.id })
    }

    /// An artist and their albums (a lookup of the `artistId` with `entity=album`), newest first when `newestFirst`.
    /// Throws ``ITunesError/notFound(_:)`` when there is no such artist.
    public func artist(id: Int, albumLimit: Int = 50, newestFirst: Bool = false, country: String? = nil) async throws -> ArtistDetail {
        let request = LookupRequest(.id([id]), entity: .album, limit: albumLimit, sort: newestFirst ? .recent : nil, country: country)
        let response = try await lookup(request)
        guard let artist = response.artists.first(where: { $0.id == id }) ?? response.artists.first else {
            throw ITunesError.notFound("artist \(id)")
        }
        return ArtistDetail(artist: artist, albums: response.albums)
    }

    /// A podcast and its latest episodes (a lookup of the `collectionId` with `entity=podcastEpisode`).
    /// Throws ``ITunesError/notFound(_:)`` when there is no such podcast.
    public func podcast(id: Int, episodeLimit: Int = 20, country: String? = nil) async throws -> PodcastDetail {
        let request = LookupRequest(.id([id]), entity: .podcastEpisode, limit: episodeLimit, country: country)
        let response = try await lookup(request)
        guard let podcast = response.podcasts.first(where: { $0.id == id }) ?? response.podcasts.first else {
            throw ITunesError.notFound("podcast \(id)")
        }
        return PodcastDetail(podcast: podcast, episodes: response.podcastEpisodes)
    }

    // MARK: - Requests

    /// Builds the request for an endpoint and its parameters. Exposed for tests and debugging.
    public func request(_ url: URL, query: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ITunesError.transport(URLError(.badURL))
        }
        if !query.isEmpty {
            components.queryItems = query
            // URLComponents leaves "+" as is, but the API reads it as a space ("c++" would become "c  ").
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let finalURL = components.url else {
            throw ITunesError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: finalURL, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    /// Fetches and decodes any URL on the API host into your own `Decodable` or into ``ITunesResponse``, with the
    /// same throttling, retries and error handling as the other methods.
    public func get<T: Decodable>(_ url: URL, query: [URLQueryItem], as type: T.Type = T.self) async throws -> T {
        let urlRequest = try request(url, query: query)
        let policy = configuration.retryPolicy
        var retry = 0
        while true {
            if let throttle {
                try await throttle.acquire()
            }
            do {
                return try await send(urlRequest, as: T.self)
            } catch let error as ITunesError {
                guard retry < policy.maxRetries, let hint = Self.retryHint(for: error) else {
                    throw error
                }
                retry += 1
                let delay = policy.delay(forRetry: retry, retryAfter: hint.serverWait)
                if delay > 0 {
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
    }

    /// A retryable error, with the wait the server asked for (if any).
    private struct RetryHint {
        let serverWait: TimeInterval?
    }

    /// `nil` for errors that are not worth retrying: only rate limits and server errors are.
    private static func retryHint(for error: ITunesError) -> RetryHint? {
        switch error {
        case let .rateLimited(retryAfter):
            return RetryHint(serverWait: retryAfter)
        case let .http(statusCode, _) where statusCode >= 500:
            return RetryHint(serverWait: nil)
        default:
            return nil
        }
    }

    private func send<T: Decodable>(_ urlRequest: URLRequest, as type: T.Type) async throws -> T {
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: urlRequest)
        } catch let error as URLError {
            throw ITunesError.transport(error)
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw ITunesError.invalidResponse
        }
        let decoder = JSONDecoder()
        switch http.statusCode {
        case 200..<300:
            break
        case 403, 429:
            throw ITunesError.rateLimited(retryAfter: Self.retryAfter(http))
        default:
            if let body = try? decoder.decode(APIErrorBody.self, from: data) {
                throw ITunesError.api(message: body.errorMessage, statusCode: http.statusCode)
            }
            throw ITunesError.http(statusCode: http.statusCode, url: urlRequest.url ?? http.url ?? configuration.baseURL)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let body = try? decoder.decode(APIErrorBody.self, from: data) {
                throw ITunesError.api(message: body.errorMessage, statusCode: http.statusCode)
            }
            throw ITunesError.decoding(type: String(describing: T.self), description: String(describing: error))
        }
    }

    /// `Retry-After` in seconds, when the server sent one as a number.
    static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces),
              let seconds = TimeInterval(value), seconds >= 0
        else { return nil }
        return seconds
    }
}
