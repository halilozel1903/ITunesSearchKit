import Foundation
import Testing
@testable import ITunesSearchKit

@Suite("Client")
struct ClientTests {
    // MARK: - Search

    @Test func searchSendsTheQuery() async throws {
        let stub = StubbedClient(fixture: "search-daft-punk-songs")
        let songs = try await stub.client.songs(matching: "  daft punk ", limit: 25)

        #expect(songs.count == 3)
        #expect(stub.lastPath == "/search")
        #expect(stub.lastQueryValue("term") == "daft punk")
        // The media follows from the entity.
        #expect(stub.lastQueryValue("media") == "music")
        #expect(stub.lastQueryValue("entity") == "song")
        #expect(stub.lastQueryValue("limit") == "25")
        #expect(stub.lastQueryValue("country") == "US")
        #expect(stub.lastQueryValue("explicit") == nil)
        #expect(stub.requests.last?.httpMethod == "GET")
    }

    @Test func searchEncodesPlusSigns() async throws {
        let stub = StubbedClient(fixture: "lookup-empty")
        _ = try await stub.client.search("c++ swift")

        let query = try #require(stub.requests.last?.url?.query(percentEncoded: true))
        #expect(query.contains("c%2B%2B"))
        #expect(stub.lastQueryValue("term") == "c++ swift")
    }

    @Test func searchRequestOptions() async throws {
        let stub = StubbedClient(fixture: "lookup-empty")
        var request = SearchRequest(term: "nolan", media: .movie, attribute: .directorTerm)
        request.country = "gb"
        request.language = .english
        request.limit = 10
        request.offset = 20
        request.allowsExplicit = false
        _ = try await stub.client.search(request)

        #expect(stub.lastQueryValue("media") == "movie")
        #expect(stub.lastQueryValue("entity") == nil)
        #expect(stub.lastQueryValue("attribute") == "directorTerm")
        #expect(stub.lastQueryValue("lang") == "en_us")
        #expect(stub.lastQueryValue("offset") == "20")
        #expect(stub.lastQueryValue("explicit") == "No")
        // The request's country wins over the client's, and is sent once.
        #expect(stub.lastQueryValue("country") == "GB")
        #expect(stub.lastQuery.filter { $0.name == "country" }.count == 1)
    }

    @Test func clientWithoutCountrySendsNone() async throws {
        let stub = StubbedClient(country: nil) { _ in try StubResponse.json("lookup-empty") }
        _ = try await stub.client.search("anything")
        #expect(stub.lastQueryValue("country") == nil)
    }

    @Test func invalidSearchesAreNotSent() async throws {
        let stub = StubbedClient(fixture: "lookup-empty")

        await #expect(throws: ITunesError.self) {
            try await stub.client.search(SearchRequest(term: "   "))
        }
        await #expect(throws: ITunesError.self) {
            try await stub.client.search(SearchRequest(term: "a", limit: 201))
        }
        await #expect(throws: ITunesError.self) {
            try await stub.client.search(SearchRequest(term: "a", country: "USA"))
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func typedSearches() async throws {
        let stub = StubbedClient(fixture: "search-mixed")

        let apps = try await stub.client.apps(matching: "pages", platform: .macOS)
        #expect(apps.count == 1)
        #expect(stub.lastQueryValue("entity") == "macSoftware")
        #expect(stub.lastQueryValue("media") == "software")

        let books = try await stub.client.ebooks(matching: "hail mary")
        #expect(books.first?.name == "Project Hail Mary")
        #expect(stub.lastQueryValue("entity") == "ebook")

        let movies = try await stub.client.movies(matching: "interstellar", limit: 5)
        #expect(movies.first?.director == "Christopher Nolan")
        #expect(stub.lastQueryValue("media") == "movie")
    }

    // MARK: - Lookup

    @Test func albumWithTracks() async throws {
        let stub = StubbedClient(fixture: "lookup-album-random-access-memories")
        let detail = try await stub.client.album(id: 617154241)

        #expect(stub.lastPath == "/lookup")
        #expect(stub.lastQueryValue("id") == "617154241")
        #expect(stub.lastQueryValue("entity") == "song")
        #expect(stub.lastQueryValue("limit") == "200")
        #expect(detail.album.name == "Random Access Memories")
        #expect(detail.tracks.map(\.name) == ["Give Life Back to Music", "The Game of Love", "Get Lucky (feat. Pharrell Williams & Nile Rodgers)"])
    }

    @Test func artistWithAlbums() async throws {
        let stub = StubbedClient(fixture: "lookup-artist-albums")
        let detail = try await stub.client.artist(id: 5468295, albumLimit: 10, newestFirst: true)

        #expect(stub.lastQueryValue("entity") == "album")
        #expect(stub.lastQueryValue("limit") == "10")
        #expect(stub.lastQueryValue("sort") == "recent")
        #expect(detail.artist.name == "Daft Punk")
        #expect(detail.albums.map(\.name) == ["Random Access Memories", "Discovery"])
    }

    @Test func podcastWithEpisodes() async throws {
        let stub = StubbedClient(fixture: "lookup-podcast-the-daily")
        let detail = try await stub.client.podcast(id: 1200361736, episodeLimit: 2)

        #expect(stub.lastQueryValue("entity") == "podcastEpisode")
        #expect(stub.lastQueryValue("limit") == "2")
        #expect(detail.podcast.name == "The Daily")
        // Newest first.
        #expect(detail.episodes.map(\.name) == ["The Week Markets Wobbled", "Inside the Newsroom"])
    }

    @Test func lookupKeys() async throws {
        let stub = StubbedClient(fixture: "search-mixed")

        let book = try await stub.client.ebook(isbn: "978-0-593-13520-4")
        #expect(book?.name == "Project Hail Mary")
        #expect(stub.lastQueryValue("isbn") == "9780593135204")

        let app = try await stub.client.app(bundleID: "com.apple.Pages")
        #expect(app?.bundleID == "com.apple.Pages")
        #expect(stub.lastQueryValue("bundleId") == "com.apple.Pages")

        _ = try await stub.client.lookup(ids: [617154241, 697194953])
        #expect(stub.lastQueryValue("id") == "617154241,697194953")

        _ = try await stub.client.lookup(LookupRequest(.amgArtistID([168791]), entity: .album))
        #expect(stub.lastQueryValue("amgArtistId") == "168791")

        _ = try await stub.client.album(upc: "886443919266")
        #expect(stub.lastQueryValue("upc") == "886443919266")
    }

    @Test func invalidLookupsAreNotSent() async throws {
        let stub = StubbedClient(fixture: "lookup-empty")

        await #expect(throws: ITunesError.self) {
            try await stub.client.lookup(LookupRequest(.id([])))
        }
        await #expect(throws: ITunesError.self) {
            try await stub.client.lookup(LookupRequest(.isbn(["12345"])))
        }
        await #expect(throws: ITunesError.self) {
            try await stub.client.lookup(LookupRequest(.upc(["ABC123456789"])))
        }
        await #expect(throws: ITunesError.self) {
            try await stub.client.lookup(LookupRequest(.id([-4])))
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func missingItems() async throws {
        let stub = StubbedClient(fixture: "lookup-empty")

        #expect(try await stub.client.lookup(id: 1) == nil)
        await #expect(throws: ITunesError.notFound("album 1")) {
            try await stub.client.album(id: 1)
        }
        await #expect(throws: ITunesError.notFound("podcast 2")) {
            try await stub.client.podcast(id: 2)
        }
    }

    // MARK: - Errors

    @Test func apiErrorMessage() async throws {
        let stub = StubbedClient { _ in try StubResponse.json("error-invalid-media", status: 400) }
        await #expect(throws: ITunesError.api(message: "Invalid value(s) for key(s): [mediaType]", statusCode: 400)) {
            try await stub.client.search("x")
        }
    }

    @Test func rateLimit() async throws {
        let stub = StubbedClient { _ in StubResponse.status(403, headers: ["Retry-After": "7"]) }
        await #expect(throws: ITunesError.rateLimited(retryAfter: 7)) {
            try await stub.client.search("x")
        }
        #expect(stub.requests.count == 1)
    }

    @Test func rateLimitIsRetried() async throws {
        let calls = CallCounter()
        let policy = RetryPolicy(maxRetries: 2, baseDelay: 0)
        let stub = StubbedClient(retryPolicy: policy) { _ in
            if calls.next() == 1 {
                return StubResponse.status(429)
            }
            return try StubResponse.json("search-daft-punk-songs")
        }
        let songs = try await stub.client.songs(matching: "daft punk")
        #expect(songs.count == 3)
        #expect(stub.requests.count == 2)
    }

    @Test func serverErrorsAreRetriedThenThrown() async throws {
        let policy = RetryPolicy(maxRetries: 2, baseDelay: 0)
        let stub = StubbedClient(retryPolicy: policy) { _ in StubResponse.status(503) }
        let error = await #expect(throws: ITunesError.self) {
            try await stub.client.search("x")
        }
        guard case let .http(statusCode, _) = error else {
            Issue.record("Expected an HTTP error, got \(String(describing: error))")
            return
        }
        #expect(statusCode == 503)
        #expect(error?.isTransient == true)
        // The first attempt and two retries.
        #expect(stub.requests.count == 3)
    }

    @Test func clientErrorsAreNotRetried() async throws {
        let policy = RetryPolicy(maxRetries: 3, baseDelay: 0)
        let stub = StubbedClient(retryPolicy: policy) { _ in StubResponse.status(404) }
        await #expect(throws: ITunesError.self) {
            try await stub.client.search("x")
        }
        #expect(stub.requests.count == 1)
    }

    @Test func decodingError() async throws {
        let stub = StubbedClient { _ in StubResponse.status(200, body: "<html>maintenance</html>") }
        let error = await #expect(throws: ITunesError.self) {
            try await stub.client.search("x")
        }
        guard case let .decoding(type, _) = error else {
            Issue.record("Expected a decoding error, got \(String(describing: error))")
            return
        }
        #expect(type == "ITunesResponse")
    }

    @Test func transportError() async throws {
        // Not a connectivity error: on watchOS a -1009 from a URLProtocol makes the system retry the request over
        // the real network, which bypasses the stub.
        let stub = StubbedClient { _ in throw URLError(.badServerResponse) }

        let error = await #expect(throws: ITunesError.self) {
            try await stub.client.search("x")
        }
        guard case let .transport(urlError) = error else {
            Issue.record("Expected a transport error, got \(String(describing: error))")
            return
        }
        #if !os(watchOS)
        #expect(urlError.code == .badServerResponse)
        #else
        _ = urlError
        #endif
    }

    @Test func requestHeaders() throws {
        let client = ITunesClient(configuration: ITunesConfiguration(userAgent: "Tests/1.0"))
        let request = try client.request(client.configuration.searchURL, query: [URLQueryItem(name: "term", value: "a b")])
        #expect(request.url?.absoluteString == "https://itunes.apple.com/search?term=a%20b")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Tests/1.0")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(client.configuration.lookupURL.absoluteString == "https://itunes.apple.com/lookup")
    }
}
