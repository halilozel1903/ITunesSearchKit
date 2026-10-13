import Foundation

/// Settings for an ``ITunesClient``: the host, the default store country and language, the `URLSession`, and
/// how the client deals with Apple's rate limit.
public struct ITunesConfiguration: Sendable {
    /// The host serving `/search` and `/lookup`. `https://itunes.apple.com` by default.
    public var baseURL: URL
    /// The two-letter store country used when a request names none, such as `"US"` or `"TR"`. Prices, availability
    /// and some names depend on it. `nil` leaves it to the API, which uses the US store.
    public var country: String?
    /// The language of the results when a request names none. `nil` leaves it to the API.
    public var language: ITunesLanguage?
    /// The session every request goes through. Point it at a stub `URLProtocol` in tests.
    public var session: URLSession
    /// The timeout of each request, in seconds.
    public var timeout: TimeInterval
    /// What to do when Apple answers with a rate limit (HTTP 403 or 429) or a server error.
    public var retryPolicy: RetryPolicy
    /// Spaces requests out so that no more than this many start in any 60 seconds. Apple asks for about 20 a minute;
    /// `nil` (the default) sends requests as they come.
    public var requestsPerMinute: Int?
    /// An optional `User-Agent` header.
    public var userAgent: String?

    public init(
        baseURL: URL = URL(string: "https://itunes.apple.com")!,
        country: String? = "US",
        language: ITunesLanguage? = nil,
        session: URLSession = .shared,
        timeout: TimeInterval = 30,
        retryPolicy: RetryPolicy = .default,
        requestsPerMinute: Int? = nil,
        userAgent: String? = nil
    ) {
        self.baseURL = baseURL
        self.country = country
        self.language = language
        self.session = session
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.requestsPerMinute = requestsPerMinute
        self.userAgent = userAgent
    }

    /// `/search` on ``baseURL``.
    public var searchURL: URL {
        baseURL.appendingPathComponent("search")
    }

    /// `/lookup` on ``baseURL``.
    public var lookupURL: URL {
        baseURL.appendingPathComponent("lookup")
    }

    /// The configuration Apple recommends for a shared app: at most 20 requests a minute, with retries.
    public static var politeDefault: ITunesConfiguration {
        ITunesConfiguration(requestsPerMinute: 20)
    }
}

/// How often and how long the client waits before trying a request again after a rate limit (HTTP 403 or 429) or
/// a server error (HTTP 5xx). Other errors are never retried.
public struct RetryPolicy: Sendable, Hashable {
    /// Retries after the first attempt. `0` turns retrying off.
    public var maxRetries: Int
    /// The wait before the first retry, doubled for every further one.
    public var baseDelay: TimeInterval
    /// The longest wait, also for a `Retry-After` header asking for more.
    public var maxDelay: TimeInterval

    public init(maxRetries: Int, baseDelay: TimeInterval, maxDelay: TimeInterval = 60) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(0, maxDelay)
    }

    /// Two retries, after 3 and 6 seconds (or what `Retry-After` asks for).
    public static let `default` = RetryPolicy(maxRetries: 2, baseDelay: 3, maxDelay: 30)

    /// Fail at once.
    public static let none = RetryPolicy(maxRetries: 0, baseDelay: 0)

    /// The wait before retry number `retry` (1 for the first), in seconds.
    public func delay(forRetry retry: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if let retryAfter {
            return min(max(0, retryAfter), maxDelay)
        }
        let exponent = max(0, retry - 1)
        let delay = baseDelay * pow(2, Double(exponent))
        return min(delay, maxDelay)
    }
}
