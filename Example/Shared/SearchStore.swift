import Foundation
import ITunesSearchKit
import Observation

/// The search field, the category and the results, always from the live iTunes Search API.
@MainActor
@Observable
final class SearchStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// What a search depends on; a change starts a new search.
    struct Key: Hashable {
        let query: String
        let category: SearchCategory
    }

    var query: String
    var category: SearchCategory
    private(set) var results: [ITunesItem] = []
    private(set) var phase: Phase = .idle

    let client: ITunesClient
    /// How many times a search is tried before it fails. Screenshot scenes retry, so a brief network hiccup on a CI
    /// runner does not fail the job; there is no fallback data, so a scene that cannot load never signals ready.
    let attempts: Int
    /// Leaves out results without artwork (screenshot scenes show only real artwork, never a placeholder).
    let requiresArtwork: Bool

    init(
        client: ITunesClient = .shared,
        query: String = "",
        category: SearchCategory = .songs,
        attempts: Int = 1,
        requiresArtwork: Bool = false
    ) {
        self.client = client
        self.query = query
        self.category = category
        self.attempts = max(1, attempts)
        self.requiresArtwork = requiresArtwork
    }

    /// Always the live API. A screenshot scene starts with its query and category and tries harder.
    static func make(for scene: ScreenshotScene?) -> SearchStore {
        guard let scene else { return SearchStore() }
        return SearchStore(query: scene.query, category: scene.category, attempts: 4, requiresArtwork: true)
    }

    var key: Key {
        Key(query: query.trimmingCharacters(in: .whitespacesAndNewlines), category: category)
    }

    /// Searches for ``key``, after a short pause when `debounce` is true so typing does not send a request per key.
    /// A newer search cancels this one (it runs in `task(id:)`), and stale results are never shown.
    func search(debounce: Bool) async {
        let key = self.key
        guard !key.query.isEmpty else {
            results = []
            phase = .idle
            return
        }
        if debounce {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
        }
        phase = .loading
        var lastError: (any Error)?
        for attempt in 1...attempts {
            do {
                let request = SearchRequest(term: key.query, entity: key.category.entity, limit: key.category.limit)
                var items = try await client.search(request).items
                guard !Task.isCancelled, key == self.key else { return }
                if requiresArtwork {
                    items = items.filter { $0.artwork != nil }
                }
                results = items
                phase = .loaded
                if attempts > 1 {
                    screenshotLog("Search for \"\(key.query)\" loaded \(items.count) results with artwork")
                }
                return
            } catch {
                guard !Task.isCancelled else { return }
                lastError = error
                screenshotLog("Search for \"\(key.query)\" failed (attempt \(attempt) of \(attempts)): \(error)")
                guard attempt < attempts else { break }
                try? await Task.sleep(for: .seconds(Double(attempt * 3)))
            }
        }
        phase = .failed(lastError?.localizedDescription ?? "The search failed.")
    }
}
