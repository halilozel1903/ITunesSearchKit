import Foundation

/// The start times of recent requests, to keep at most `limit` in any `interval` seconds.
struct SlidingWindow: Sendable, Equatable {
    let limit: Int
    let interval: TimeInterval
    private(set) var starts: [Date] = []

    init(limit: Int, interval: TimeInterval) {
        self.limit = max(1, limit)
        self.interval = max(0, interval)
    }

    /// How long a request starting at `now` has to wait, in seconds; `0` when it can start at once.
    func delay(at now: Date) -> TimeInterval {
        let recent = starts.filter { now.timeIntervalSince($0) < interval }
        guard recent.count >= limit, let oldest = recent.min() else { return 0 }
        return max(0, interval - now.timeIntervalSince(oldest))
    }

    /// Records a request starting at `date`, and forgets those older than the window.
    mutating func record(_ date: Date) {
        starts.removeAll { date.timeIntervalSince($0) >= interval }
        starts.append(date)
    }
}

/// Makes callers wait their turn so no more than a set number of requests start per minute.
actor RequestThrottle {
    private var window: SlidingWindow

    init(requestsPerMinute: Int) {
        window = SlidingWindow(limit: requestsPerMinute, interval: 60)
    }

    /// Waits until a request may start, then counts it. Throws `CancellationError` when the task is cancelled.
    func acquire() async throws {
        while true {
            try Task.checkCancellation()
            let now = Date()
            let wait = window.delay(at: now)
            if wait <= 0 {
                window.record(now)
                return
            }
            try await Task.sleep(for: .seconds(wait))
        }
    }
}
