import Foundation
import Testing
@testable import ITunesSearchKit

@Suite("Artwork")
struct ArtworkTests {
    static let thumbnail = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e8/43/5f/e8435ffa/886443919266.jpg/100x100bb.jpg")!

    @Test func resizesSquare() {
        let artwork = Artwork(url: Self.thumbnail)
        #expect(artwork.isResizable)
        #expect(artwork.size?.width == 100)
        #expect(artwork.size?.height == 100)
        #expect(artwork.url(size: 600).absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e8/43/5f/e8435ffa/886443919266.jpg/600x600bb.jpg")
    }

    @Test func resizesToBoxAndFormat() {
        let artwork = Artwork(url: Self.thumbnail)
        #expect(artwork.url(width: 400, height: 600).lastPathComponent == "400x600bb.jpg")
        #expect(artwork.url(size: 512, format: .png).lastPathComponent == "512x512bb.png")
        #expect(artwork.url(size: 300, format: .webp).lastPathComponent == "300x300bb.webp")
        // Only the file name changes; the folder named like an image stays.
        #expect(artwork.url(size: 300).deletingLastPathComponent() == Self.thumbnail.deletingLastPathComponent())
    }

    @Test func keepsTheSuffix() throws {
        let url = try #require(URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Video/v4/aa/source/227x227cc-60.jpg"))
        #expect(Artwork.resized(url, width: 600, height: 600)?.lastPathComponent == "600x600cc-60.jpg")
    }

    @Test func leavesOtherURLsAlone() throws {
        let url = try #require(URL(string: "https://example.com/images/cover.jpg"))
        let artwork = Artwork(url: url)
        #expect(!artwork.isResizable)
        #expect(artwork.size?.width == nil)
        #expect(artwork.url(size: 600) == url)
        #expect(Artwork.resized(url, width: 600, height: 600) == nil)
        #expect(Artwork.resized(Self.thumbnail, width: 0, height: 600) == nil)

        let noSize = try #require(URL(string: "https://example.com/images/xmas.png"))
        #expect(Artwork.resized(noSize, width: 10, height: 10) == nil)
    }

    @Test func upgradesToHTTPS() throws {
        let url = try #require(URL(string: "http://is4-ssl.mzstatic.com/image/thumb/a/100x100bb.jpg"))
        #expect(Artwork(url: url).url.absoluteString == "https://is4-ssl.mzstatic.com/image/thumb/a/100x100bb.jpg")
    }
}

@Suite("Requests")
struct RequestTests {
    @Test func entityMedia() {
        #expect(ITunesEntity.song.media == .music)
        #expect(ITunesEntity.album.media == .music)
        #expect(ITunesEntity.musicVideo.media == .musicVideo)
        #expect(ITunesEntity.podcastEpisode.media == .podcast)
        #expect(ITunesEntity.macSoftware.media == .software)
        #expect(ITunesEntity.ebook.media == .ebook)
        #expect(ITunesEntity("somethingNew").media == nil)
        #expect(ITunesAttribute.artistTerm.rawValue == "artistTerm")
    }

    @Test func searchQueryOrder() {
        let request = SearchRequest(term: "jack johnson", entity: .musicVideo, limit: 5)
        let names = request.queryItems.map(\.name)
        #expect(names == ["term", "media", "entity", "limit"])
        #expect(request.queryItems[1].value == "musicVideo")
    }

    @Test func explicitMediaWins() {
        let request = SearchRequest(term: "x", media: .all, entity: .allArtist)
        #expect(request.queryItems.first(where: { $0.name == "media" })?.value == "all")
    }

    @Test func validation() {
        #expect(throws: ITunesError.self) {
            try SearchRequest(term: "").validate()
        }
        #expect(throws: ITunesError.self) {
            try SearchRequest(term: "x", limit: 0).validate()
        }
        #expect(throws: ITunesError.self) {
            try SearchRequest(term: "x", offset: -1).validate()
        }
        #expect(throws: Never.self) {
            try SearchRequest(term: "x", country: "tr", limit: 200).validate()
        }
    }

    @Test func isbn() {
        #expect(LookupRequest.normalizedISBN("0-316-06935-x") == "031606935X")
        #expect(LookupRequest.isValidISBN("031606935X"))
        #expect(LookupRequest.isValidISBN("9780316069359"))
        #expect(!LookupRequest.isValidISBN("97803160693"))
        #expect(!LookupRequest.isValidISBN("X316069359"))
    }

    @Test func lookupQuery() {
        let request = LookupRequest(.upc(["720642462928", "602547924032"]), entity: .song, limit: 3, sort: .recent, country: "de")
        let names = request.queryItems.map(\.name)
        #expect(names == ["upc", "entity", "limit", "sort", "country"])
        #expect(request.queryItems[0].value == "720642462928,602547924032")
        #expect(request.queryItems[4].value == "DE")
    }
}

@Suite("Formatting")
struct FormattingTests {
    @Test func durations() {
        #expect(ITunesFormat.duration(225) == "3:45")
        #expect(ITunesFormat.duration(59.6) == "1:00")
        #expect(ITunesFormat.duration(3723) == "1:02:03")
        #expect(ITunesFormat.duration(0) == "0:00")
        #expect(ITunesFormat.duration(-3) == "0:00")
        #expect(ITunesFormat.longDuration(1834) == "31 min")
        #expect(ITunesFormat.longDuration(3600) == "1 hr")
        #expect(ITunesFormat.longDuration(10136) == "2 hr 49 min")
        #expect(ITunesFormat.longDuration(10) == "1 min")
    }

    @Test func prices() {
        let locale = Locale(identifier: "en_US")
        #expect(Price(amount: 1.29, currency: "USD").formatted(locale: locale) == "$1.29")
        #expect(Price(amount: 0, currency: "USD").formatted(locale: locale) == "Free")
        let negative: Double? = -1
        #expect(Price(amount: negative, currency: "USD") == nil)
        let missingCurrency: String? = nil
        #expect(Price(amount: 1, currency: missingCurrency) == nil)
    }

    @Test func dates() {
        #expect(ITunesDate.parse("2013-05-17T07:00:00Z") == Fixture.date(2013, 5, 17, 7))
        #expect(ITunesDate.parse("2013-05-17T07:00:00.000Z") == Fixture.date(2013, 5, 17, 7))
        #expect(ITunesDate.parse("2013-05-17") == Fixture.date(2013, 5, 17))
        #expect(ITunesDate.parse("") == nil)
        #expect(ITunesDate.parse("yesterday") == nil)
        #expect(ITunesFormat.year(of: Fixture.date(2013, 5, 17)) == 2013)
    }

    @Test func plainText() {
        #expect(ITunesText.plainText(fromHTML: "Tom &amp; Jerry&#39;s &#x27;show&#x27;") == "Tom & Jerry's 'show'")
        #expect(ITunesText.plainText(fromHTML: "<p>One</p><p></p><p>Two</p>") == "One\n\nTwo")
        #expect(ITunesText.plainText(fromHTML: "<ul><li>A</li><li>B</li></ul>") == "• A\n• B")
        #expect(ITunesText.plainText(fromHTML: "1 < 2 and 3 > 2") == "1 < 2 and 3 > 2")
        #expect(ITunesText.plainText(fromHTML: "R&B fans &unknown; here") == "R&B fans &unknown; here")
    }
}

@Suite("Rate limiting")
struct RateLimitTests {
    @Test func slidingWindow() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var window = SlidingWindow(limit: 2, interval: 60)
        #expect(window.delay(at: start) == 0)
        window.record(start)
        window.record(start.addingTimeInterval(1))
        let wait = window.delay(at: start.addingTimeInterval(2))
        #expect(wait == 58)
        #expect(window.delay(at: start.addingTimeInterval(60)) == 0)
        window.record(start.addingTimeInterval(61))
        #expect(window.starts.count == 1)
    }

    @Test func retryDelays() {
        let policy = RetryPolicy.default
        #expect(policy.delay(forRetry: 1, retryAfter: nil) == 3)
        #expect(policy.delay(forRetry: 2, retryAfter: nil) == 6)
        #expect(policy.delay(forRetry: 5, retryAfter: nil) == 30)
        #expect(policy.delay(forRetry: 1, retryAfter: 12) == 12)
        #expect(policy.delay(forRetry: 1, retryAfter: 600) == 30)
        #expect(RetryPolicy.none.maxRetries == 0)
    }

    @Test func retryAfterHeader() throws {
        let url = try #require(URL(string: "https://itunes.apple.com/search"))
        let withHeader = try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": " 20 "]))
        #expect(ITunesClient.retryAfter(withHeader) == 20)
        let withDate = try #require(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"]))
        #expect(ITunesClient.retryAfter(withDate) == nil)
    }

    @Test func transientErrors() throws {
        let url = try #require(URL(string: "https://itunes.apple.com/search"))
        #expect(ITunesError.rateLimited(retryAfter: nil).isTransient)
        #expect(ITunesError.http(statusCode: 502, url: url).isTransient)
        #expect(!ITunesError.http(statusCode: 404, url: url).isTransient)
        #expect(ITunesError.transport(URLError(.timedOut)).isTransient)
        #expect(!ITunesError.transport(URLError(.cancelled)).isTransient)
        #expect(!ITunesError.invalidRequest("x").isTransient)
        #expect(ITunesError.rateLimited(retryAfter: 4).errorDescription?.contains("4 seconds") == true)
    }
}
