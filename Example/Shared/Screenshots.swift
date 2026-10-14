import Foundation
import ITunesSearchKit
import ITunesSearchUI
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene searches the live iTunes Search API and shows real results with their real artwork. Search and
/// lookups are retried, and so is every image (4 attempts each). There is no fallback data, no drawn artwork and no
/// placeholder: when anything fails to load, the scene never signals ready and the screenshot job fails instead of
/// committing a capture that is not real.
enum ScreenshotScene: String {
    /// The results grid: songs for "daft punk" on the Mac, albums for "taylor swift" on iPhone.
    case search
    /// Mac: the first album found for "daft punk random access memories", with its songs.
    case album
    /// Mac: the first podcast found for "the daily new york times", with its latest episodes.
    case podcast
    /// iPhone: the first app found for "procreate", with its App Store screenshots.
    case detail

    /// The scene this launch asked for. A `mac-` or `iphone-` prefix is accepted too.
    static var current: ScreenshotScene? {
        guard var name = argument(after: "-screenshot") else { return nil }
        for prefix in ["mac-", "iphone-"] where name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        return ScreenshotScene(rawValue: name)
    }

    /// Where the ready marker goes: `-screenshot-marker <path>` (the Mac script passes one), or
    /// `tmp/screenshot-ready` in the app's container (what the iPhone script watches).
    static var markerURL: URL {
        if let path = argument(after: "-screenshot-marker") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
    }

    /// Mac only: `-render-screenshot <file>` asks the app to draw its window into a PNG itself once ready, the
    /// fallback when `screencapture` cannot capture the window.
    static var renderPath: String? {
        argument(after: "-render-screenshot")
    }

    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// The category the scene searches.
    var category: SearchCategory {
        switch self {
        case .search:
            #if os(macOS)
            return .songs
            #else
            return .albums
            #endif
        case .album: return .albums
        case .podcast: return .podcasts
        case .detail: return .apps
        }
    }

    /// The text in the search field. Picked to return plenty of results with artwork in the US store.
    var query: String {
        switch self {
        case .search:
            #if os(macOS)
            return "daft punk"
            #else
            return "taylor swift"
            #endif
        case .album: return "daft punk random access memories"
        case .podcast: return "the daily new york times"
        case .detail: return "procreate"
        }
    }

    /// Whether the scene opens the first result, as if it were clicked.
    var opensFirstResult: Bool {
        self != .search
    }

    /// The image loader for the screenshot scenes: the network, tried up to 4 times per image, checked to be a
    /// real image, and counted, so the scene is only reported ready once every image on screen has loaded.
    static let imageLoader = ArtworkLoader { url in
        await ScreenshotImageTracker.shared.begin()
        var lastError: any Error = URLError(.unknown)
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
            }
            if Task.isCancelled { break }
            do {
                let data = try await ArtworkLoader.fetch(url)
                guard ArtworkDecoder.canDecode(data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                await ScreenshotImageTracker.shared.end(failed: false)
                return data
            } catch {
                lastError = error
                screenshotLog("Screenshot image \(url) failed (attempt \(attempt + 1) of 4): \(error)")
            }
        }
        // A view that went away cancels its load; that is not a failure.
        await ScreenshotImageTracker.shared.end(failed: !Task.isCancelled)
        throw lastError
    }
}

/// Counts the image loads of a screenshot scene.
actor ScreenshotImageTracker {
    static let shared = ScreenshotImageTracker()

    struct Snapshot: Sendable {
        var started = 0
        var inFlight = 0
        var failed = 0
        var lastChange = Date()
    }

    private var state = Snapshot()

    func begin() {
        state.started += 1
        state.inFlight += 1
        state.lastChange = Date()
    }

    func end(failed: Bool) {
        state.inFlight -= 1
        if failed {
            state.failed += 1
        }
        state.lastChange = Date()
    }

    func snapshot() -> Snapshot {
        state
    }

    /// Waits until at least one image has loaded and none started or finished for `quiet` seconds.
    /// Returns false, and the scene is never reported ready, when an image failed to load.
    static func waitUntilSettled(quiet: TimeInterval = 2.5) async -> Bool {
        var lastReport = Date()
        while !Task.isCancelled {
            let state = await shared.snapshot()
            if state.failed > 0 {
                screenshotLog("Screenshot scene: \(state.failed) image(s) failed to load; not marking it ready")
                return false
            }
            if state.started > 0, state.inFlight == 0, Date().timeIntervalSince(state.lastChange) >= quiet {
                return true
            }
            if Date().timeIntervalSince(lastReport) >= 10 {
                lastReport = Date()
                screenshotLog("Screenshot scene: waiting for images (started \(state.started), in flight \(state.inFlight))")
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

extension View {
    /// Tells the screenshot scripts that the scene is on screen by writing the ready marker, once `isReady` is true
    /// (the real data has loaded) and every image the scene shows has loaded too. Nothing is written when loading
    /// fails, so CI fails instead of committing a broken or made-up capture.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            screenshotLog("Screenshot scene \(scene.rawValue): data loaded, waiting for its images")
            // Give the views a moment to start loading their images.
            try? await Task.sleep(for: .seconds(1.5))
            guard await ScreenshotImageTracker.waitUntilSettled(), !Task.isCancelled else { return }
            do {
                try scene.rawValue.write(to: ScreenshotScene.markerURL, atomically: true, encoding: .utf8)
                screenshotLog("Screenshot scene \(scene.rawValue) is ready")
            } catch {
                screenshotLog("Could not write the screenshot marker: \(error)")
                return
            }
            #if os(macOS)
            await MainActor.run {
                ScreenshotWindowCoordinator.shared.sceneIsReady()
            }
            #endif
        }
    }
}

/// Prints a line and, in a screenshot scene, also appends it to `screenshot-log.txt` in the temporary directory. The
/// iPhone screenshot script prints that file when a scene does not become ready, since the app's console is not
/// reliably captured on CI.
func screenshotLog(_ message: String) {
    print(message)
    guard ScreenshotScene.current != nil else { return }
    ScreenshotLog.append(message)
}

enum ScreenshotLog {
    private static let lock = NSLock()

    static var url: URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-log.txt")
    }

    static func append(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = Data((message + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }
}
