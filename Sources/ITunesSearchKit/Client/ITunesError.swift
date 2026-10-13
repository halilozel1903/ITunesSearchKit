import Foundation

/// Errors thrown by ``ITunesClient``.
public enum ITunesError: Error, Equatable, Sendable, LocalizedError {
    /// The request was not sent because a parameter is invalid (checked before any network access).
    case invalidRequest(String)
    /// Apple is limiting the request rate (HTTP 403 or 429), after the retries of the ``RetryPolicy``.
    /// `retryAfter` is the wait Apple asked for in seconds, when it said.
    case rateLimited(retryAfter: TimeInterval?)
    /// The API rejected the request and said why, as in `{"errorMessage": "Invalid value(s) for key(s): [mediaType]"}`.
    case api(message: String, statusCode: Int)
    /// An unsuccessful HTTP status without an error message.
    case http(statusCode: Int, url: URL)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// A lookup that needs a result, such as ``ITunesClient/album(id:country:)``, found nothing.
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidRequest(reason):
            return reason
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "The iTunes Search API is limiting requests. Try again in \(Int(retryAfter.rounded(.up))) seconds."
            }
            return "The iTunes Search API is limiting requests. Try again in a minute."
        case let .api(message, _):
            return message
        case let .http(statusCode, _):
            return "The iTunes Search API answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "The iTunes Search API sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "The iTunes Search API sent an invalid response."
        case let .notFound(what):
            return "Nothing was found for \(what)."
        }
    }

    /// Whether trying again later may succeed: rate limits, server errors and connection problems.
    public var isTransient: Bool {
        switch self {
        case .rateLimited:
            return true
        case let .http(statusCode, _):
            return statusCode >= 500
        case let .transport(error):
            return error.code != .cancelled
        default:
            return false
        }
    }
}

/// The body the API sends with a 400 Bad Request.
struct APIErrorBody: Decodable {
    let errorMessage: String
}
