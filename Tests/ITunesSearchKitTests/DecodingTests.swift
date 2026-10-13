import Foundation
import Testing
@testable import ITunesSearchKit

@Suite("Decoding")
struct DecodingTests {
    @Test func songs() throws {
        let response = try Fixture.response("search-daft-punk-songs")
        #expect(response.resultCount == 3)
        #expect(response.songs.count == 3)
        #expect(response.skippedCount == 0)

        let song = try #require(response.songs.first)
        #expect(song.id == 617154366)
        #expect(song.name == "Get Lucky (feat. Pharrell Williams & Nile Rodgers)")
        #expect(song.artistName == "Daft Punk")
        #expect(song.artistID == 5468295)
        #expect(song.albumID == 617154241)
        #expect(song.albumName == "Random Access Memories")
        #expect(song.trackNumber == 8)
        #expect(song.trackCount == 13)
        #expect(song.discNumber == 1)
        #expect(song.genre == "Pop")
        #expect(song.explicitness == .notExplicit)
        #expect(!song.isExplicit)
        #expect(song.isStreamable == true)
        #expect(song.price == Price(amount: 1.29, currency: "USD"))
        #expect(song.albumPrice == Price(amount: 11.99, currency: "USD"))
        #expect(song.releaseDate == Fixture.date(2013, 4, 19, 12))
        let duration = try #require(song.duration)
        #expect(abs(duration - 369.629) < 0.001)
        #expect(song.previewURL?.host == "audio-ssl.itunes.apple.com")
        #expect(song.previewURL?.pathExtension == "m4a")
        #expect(song.artwork?.url.lastPathComponent == "100x100bb.jpg")
        #expect(song.artwork?.url(size: 600).lastPathComponent == "600x600bb.jpg")
    }

    @Test func httpURLsAreUpgraded() throws {
        let response = try Fixture.response("search-daft-punk-songs")
        let song = response.songs[2]
        #expect(song.previewURL?.scheme == "https")
        #expect(song.artwork?.url.scheme == "https")
        #expect(song.isExplicit)
        #expect(song.artistName == "The Weeknd & Daft Punk")
    }

    @Test func itemsAreTyped() throws {
        let response = try Fixture.response("search-mixed")
        let kinds = response.items.map(\.kind)
        let expected: [ITunesItemKind] = [.artist, .movie, .ebook, .software, .audiobook, .musicVideo, .other]
        #expect(kinds == expected)
        // "not an object" is skipped, not fatal.
        #expect(response.skippedCount == 1)
        #expect(response.resultCount == 8)
        #expect(response.artists.count == 1)
        #expect(response.movies.count == 1)
        #expect(response.ebooks.count == 1)
        #expect(response.apps.count == 1)
        #expect(response.audiobooks.count == 1)
        #expect(response.musicVideos.count == 1)
    }

    @Test func identifiersAreUniqueAcrossKinds() throws {
        let response = try Fixture.response("search-mixed")
        let ids = response.items.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.first == "artist-5468295")
        #expect(response.items.first?.itemID == 5468295)
    }

    @Test func artist() throws {
        let artist = try #require(Fixture.response("search-mixed").artists.first)
        #expect(artist.id == 5468295)
        #expect(artist.name == "Daft Punk")
        #expect(artist.artistType == "Artist")
        #expect(artist.genre == "Electronic")
        #expect(artist.amgArtistID == 168791)
        #expect(artist.storeURL?.host == "music.apple.com")
        #expect(ITunesItem.artist(artist).artwork == nil)
        #expect(ITunesItem.artist(artist).creator == nil)
    }

    @Test func movie() throws {
        let movie = try #require(Fixture.response("search-mixed").movies.first)
        #expect(movie.id == 1440768433)
        #expect(movie.name == "Interstellar")
        #expect(movie.director == "Christopher Nolan")
        #expect(movie.contentRating == "PG-13")
        #expect(movie.genre == "Sci-Fi & Fantasy")
        #expect(movie.price == Price(amount: 14.99, currency: "USD"))
        #expect(movie.rentalPrice == Price(amount: 3.99, currency: "USD"))
        #expect(movie.previewURL?.pathExtension == "m4v")
        #expect(movie.shortDescription?.hasPrefix("A team of explorers") == true)
        let duration = try #require(movie.duration)
        #expect(ITunesFormat.longDuration(duration) == "2 hr 49 min")
        #expect(ITunesItem.movie(movie).hasVideoPreview)
        #expect(ITunesItem.movie(movie).releaseYear == 2014)
    }

    @Test func ebook() throws {
        let book = try #require(Fixture.response("search-mixed").ebooks.first)
        #expect(book.id == 1525208219)
        #expect(book.name == "Project Hail Mary")
        #expect(book.author == "Andy Weir")
        #expect(book.genres.first == "Sci-Fi & Fantasy")
        #expect(book.averageRating == 4.8)
        #expect(book.ratingCount == 21543)
        #expect(book.formattedPrice == "$9.99")
        #expect(book.price == Price(amount: 9.99, currency: "USD"))
        #expect(book.fileSize == 4237568)
        let expected = "#1 New York Times bestseller\nA lone astronaut must save the earth from disaster — in this \"propulsive\" novel."
        #expect(book.plainDescription == expected)
    }

    @Test func software() throws {
        let app = try #require(Fixture.response("search-mixed").apps.first)
        #expect(app.id == 361309726)
        #expect(app.name == "Pages")
        #expect(app.bundleID == "com.apple.Pages")
        #expect(app.developer == "Apple")
        #expect(app.seller == "Apple Inc.")
        #expect(app.platform == .iOS)
        #expect(app.version == "15.0")
        #expect(app.contentRating == "4+")
        #expect(app.minimumOSVersion == "18.0")
        #expect(app.genres == ["Productivity", "Business"])
        #expect(app.languages == ["AR", "EN", "TR"])
        #expect(app.ratingCount == 118245)
        #expect(app.formattedPrice == "Free")
        #expect(app.price?.isFree == true)
        // fileSizeBytes is a string for apps.
        #expect(app.fileSize == 561278976)
        #expect(app.screenshotURLs.count == 2)
        #expect(app.iPadScreenshotURLs.isEmpty)
        #expect(app.currentVersionReleaseDate == Fixture.date(2026, 9, 15, 17, 30).addingTimeInterval(42))
        // The 512 icon is the largest artwork.
        #expect(app.artwork?.url.lastPathComponent == "512x512bb.jpg")
        #expect(app.artwork?.url(size: 1024, format: .png).lastPathComponent == "1024x1024bb.png")
    }

    @Test func audiobookAndMusicVideo() throws {
        let response = try Fixture.response("search-mixed")
        let audiobook = try #require(response.audiobooks.first)
        #expect(audiobook.id == 1525209470)
        #expect(audiobook.name == "Project Hail Mary (Unabridged)")
        #expect(audiobook.author == "Andy Weir")
        #expect(audiobook.price == Price(amount: 24.99, currency: "USD"))
        #expect(audiobook.previewURL != nil)

        let video = try #require(response.musicVideos.first)
        #expect(video.id == 693219018)
        #expect(video.artistName == "Daft Punk")
        #expect(ITunesItem.musicVideo(video).hasVideoPreview)
    }

    @Test func unknownKindsAreKept() throws {
        let item = try #require(Fixture.response("search-mixed").items.last)
        guard case let .other(unknown) = item else {
            Issue.record("Expected .other, got \(item.kind)")
            return
        }
        #expect(unknown.kind == "tv-episode")
        #expect(unknown.name == "Pilot")
        #expect(unknown.itemID == 7654330)
        #expect(unknown.id == "track-tv-episode-7654330")
        #expect(item.name == "Pilot")
        #expect(item.duration == nil)
    }

    @Test func albumLookup() throws {
        let response = try Fixture.response("lookup-album-random-access-memories")
        let album = try #require(response.albums.first)
        #expect(album.id == 617154241)
        #expect(album.name == "Random Access Memories")
        #expect(album.collectionType == "Album")
        #expect(album.trackCount == 13)
        #expect(album.copyright?.hasPrefix("℗ 2013 Daft Life") == true)
        #expect(album.releaseDate == Fixture.date(2013, 5, 17, 7))
        #expect(response.songs.count == 3)

        let detail = AlbumDetail(album: album, tracks: response.songs)
        #expect(detail.tracks.map(\.trackNumber) == [1, 2, 8])
        #expect(!detail.hasSeveralDiscs)
        #expect(abs(detail.totalDuration - 965.975) < 0.001)
    }

    @Test func podcastLookup() throws {
        let response = try Fixture.response("lookup-podcast-the-daily")
        let podcast = try #require(response.podcasts.first)
        #expect(podcast.id == 1200361736)
        #expect(podcast.name == "The Daily")
        #expect(podcast.artistName == "The New York Times")
        #expect(podcast.feedURL?.absoluteString == "https://feeds.simplecast.com/54nAGcIl")
        #expect(podcast.episodeCount == 2610)
        // "Podcasts" is the store's top level, not a genre of the show.
        #expect(podcast.genres == ["Daily News", "News"])
        #expect(podcast.explicitness == .cleaned)
        #expect(podcast.artwork?.url.lastPathComponent == "600x600bb.jpg")

        let episodes = response.podcastEpisodes
        #expect(episodes.count == 2)
        let episode = episodes[0]
        #expect(episode.name == "The Week Markets Wobbled")
        #expect(episode.podcastID == 1200361736)
        #expect(episode.fileExtension == "mp3")
        #expect(episode.contentType == "audio")
        #expect(episode.duration == 1834)
        // Episodes send genres as objects.
        #expect(episode.genres == ["Daily News"])
        #expect(episode.plainDescription == "Stocks swung all week.\nGuest: A & B. Background reading: the markets.")
        #expect(episode.releaseDate == Fixture.date(2026, 10, 8, 9, 45))
        #expect(ITunesItem.podcastEpisode(episode).previewURL != nil)
    }

    @Test func emptyResponse() throws {
        let response = try Fixture.response("lookup-empty")
        #expect(response.isEmpty)
        #expect(response.resultCount == 0)
    }
}
