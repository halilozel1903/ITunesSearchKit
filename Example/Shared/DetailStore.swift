import Foundation
import ITunesSearchKit
import Observation

/// Everything a detail page shows for one result: an album with its songs, a podcast with its episodes, an artist
/// with albums, or the item itself. Loaded with a lookup from the live API.
@MainActor
@Observable
final class DetailStore {
    enum Content {
        /// An album, opened from the album or from one of its songs (then highlighted).
        case album(AlbumDetail, highlightedSongID: Int?)
        /// A podcast, opened from the podcast or from one of its episodes (then highlighted).
        case podcast(PodcastDetail, highlightedEpisodeID: Int?)
        case artist(ArtistDetail)
        /// Movies, books, apps, audiobooks and music videos need no lookup: the search result has it all.
        case media(ITunesItem)
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let item: ITunesItem
    private(set) var content: Content?
    private(set) var phase: Phase = .idle

    let client: ITunesClient
    let attempts: Int

    init(item: ITunesItem, client: ITunesClient, attempts: Int = 1) {
        self.item = item
        self.client = client
        self.attempts = max(1, attempts)
    }

    /// Whether the page has what makes it worth showing: the songs of an album, the episodes of a podcast.
    var hasContent: Bool {
        switch content {
        case let .album(detail, _)?: !detail.tracks.isEmpty
        case let .podcast(detail, _)?: !detail.episodes.isEmpty
        case .artist?, .media?: true
        case nil: false
        }
    }

    func load() async {
        phase = .loading
        var lastError: (any Error)?
        for attempt in 1...attempts {
            do {
                let loaded = try await fetch()
                guard !Task.isCancelled else { return }
                content = loaded
                phase = .loaded
                return
            } catch {
                guard !Task.isCancelled else { return }
                lastError = error
                print("Loading \(item.name) failed (attempt \(attempt) of \(attempts)): \(error)")
                guard attempt < attempts else { break }
                try? await Task.sleep(for: .seconds(Double(attempt * 3)))
            }
        }
        phase = .failed(lastError?.localizedDescription ?? "This page could not be loaded.")
    }

    private func fetch() async throws -> Content {
        switch item {
        case let .album(album):
            let detail = try await client.album(id: album.id)
            return .album(detail, highlightedSongID: nil)
        case let .song(song):
            guard let albumID = song.albumID else { return .media(item) }
            let detail = try await client.album(id: albumID)
            return .album(detail, highlightedSongID: song.id)
        case let .podcast(podcast):
            let detail = try await client.podcast(id: podcast.id, episodeLimit: 15)
            return .podcast(detail, highlightedEpisodeID: nil)
        case let .podcastEpisode(episode):
            guard let podcastID = episode.podcastID else { return .media(item) }
            let detail = try await client.podcast(id: podcastID, episodeLimit: 15)
            return .podcast(detail, highlightedEpisodeID: episode.id)
        case let .artist(artist):
            let detail = try await client.artist(id: artist.id, albumLimit: 40)
            return .artist(detail)
        default:
            return .media(item)
        }
    }
}
