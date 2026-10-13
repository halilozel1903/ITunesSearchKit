import AVFoundation
import ITunesSearchKit
import Observation
import SwiftUI

/// Plays the 30-second previews of songs, audiobooks and episodes, one at a time.
///
/// Keep one player for the app (or a screen) and hand it to every ``PreviewButton``:
///
/// ```swift
/// @State private var player = PreviewPlayer()
///
/// ForEach(album.tracks) { song in
///     HStack {
///         Text(song.name)
///         Spacer()
///         PreviewButton(url: song.previewURL, player: player)
///     }
/// }
/// ```
@MainActor
@Observable
public final class PreviewPlayer {
    /// The preview loaded in the player, playing or paused.
    public private(set) var currentURL: URL?
    /// Whether ``currentURL`` is playing.
    public private(set) var isPlaying = false

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?

    public init() {}

    /// Whether `url` is the preview that is playing.
    public func isPlaying(_ url: URL?) -> Bool {
        guard let url else { return false }
        return isPlaying && currentURL == url
    }

    /// Plays `url`, or pauses it when it is the one playing.
    public func toggle(_ url: URL) {
        if isPlaying(url) {
            pause()
        } else {
            play(url)
        }
    }

    /// Plays `url` from where it was paused, or from the start; any other preview stops.
    public func play(_ url: URL) {
        if currentURL != url {
            stop()
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            currentURL = url
            endObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: item,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.stop()
                }
            }
        }
        player?.play()
        isPlaying = true
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Stops and unloads the current preview.
    public func stop() {
        player?.pause()
        player = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        currentURL = nil
        isPlaying = false
    }
}

/// A round play and pause button for a preview. Hidden when `url` is `nil`.
public struct PreviewButton: View {
    private let url: URL?
    private let player: PreviewPlayer
    private let size: CGFloat

    public init(url: URL?, player: PreviewPlayer, size: CGFloat = 28) {
        self.url = url
        self.player = player
        self.size = size
    }

    public var body: some View {
        if let url {
            let playing = player.isPlaying(url)
            Button {
                player.toggle(url)
            } label: {
                Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel(playing ? "Pause preview" : "Play preview")
        }
    }
}

/// The small "E" Apple shows next to explicit tracks.
public struct ExplicitBadge: View {
    public init() {}

    public var body: some View {
        Text(verbatim: "E")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.background)
            .frame(width: 13, height: 13)
            .background(.secondary, in: RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            .accessibilityLabel("Explicit")
    }
}

/// Five stars for an average rating out of 5, with halves.
public struct RatingStars: View {
    private let rating: Double
    private let count: Int?

    public init(_ rating: Double, count: Int? = nil) {
        self.rating = min(5, max(0, rating))
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: symbol(for: index))
            }
            if let count {
                Text(count.formatted(.number.notation(.compactName)))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%.1f out of 5 stars", rating))
    }

    private func symbol(for index: Int) -> String {
        let value = rating - Double(index)
        if value >= 0.75 {
            return "star.fill"
        }
        if value >= 0.25 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }
}
