import Foundation

/// Artwork of an item, which Apple serves at any size you ask for.
///
/// The API returns small thumbnails such as `…/source/100x100bb.jpg`. Replace the size in the file name and Apple's
/// image server scales the original instead:
///
/// ```swift
/// song.artwork?.url                              // …/100x100bb.jpg, as returned
/// song.artwork?.url(size: 600)                   // …/600x600bb.jpg
/// movie.artwork?.url(width: 400, height: 600)    // …/400x600bb.jpg, a poster
/// app.artwork?.url(size: 512, format: .png)      // …/512x512bb.png
/// ```
///
/// The `bb` suffix fits the image into the box without cropping, so a poster asked for at 600 × 600 comes back
/// 400 × 600.
public struct Artwork: Sendable, Hashable {
    /// The image formats Apple's image server can return.
    public enum Format: String, Sendable, Hashable, CaseIterable {
        case jpeg = "jpg"
        case png
        case webp
    }

    /// The largest artwork URL in the response, upgraded to HTTPS.
    public let url: URL

    public init(url: URL) {
        self.url = Artwork.secure(url)
    }

    /// The width and height in the URL's file name, such as 100 × 100 for `100x100bb.jpg`, or `nil` when the URL has
    /// no size in it.
    public var size: (width: Int, height: Int)? {
        guard let name = Artwork.FileName(url.lastPathComponent) else { return nil }
        return (name.width, name.height)
    }

    /// Whether ``url(size:format:)`` can change this URL's size.
    public var isResizable: Bool {
        Artwork.FileName(url.lastPathComponent) != nil
    }

    /// The artwork as a square of `size` pixels, such as 600 for `600x600bb.jpg`. Returns ``url`` unchanged when it
    /// has no size in its file name.
    public func url(size: Int, format: Format? = nil) -> URL {
        url(width: size, height: size, format: format)
    }

    /// The artwork fitted into `width` × `height` pixels. Returns ``url`` unchanged when it has no size in its file name.
    public func url(width: Int, height: Int, format: Format? = nil) -> URL {
        Artwork.resized(url, width: width, height: height, format: format) ?? url
    }

    /// Changes the size (and optionally the format) in an artwork URL from the iTunes Search API, such as
    /// `…/100x100bb.jpg` to `…/600x600bb.jpg`. Returns `nil` when the file name has no `<width>x<height>` size.
    public static func resized(_ url: URL, width: Int, height: Int, format: Format? = nil) -> URL? {
        guard width > 0, height > 0, var name = FileName(url.lastPathComponent) else { return nil }
        name.width = width
        name.height = height
        if let format {
            name.fileExtension = format.rawValue
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let path = components.path
        guard let slash = path.lastIndex(of: "/") else { return nil }
        components.path = String(path[...slash]) + name.description
        return components.url
    }

    /// Apple's artwork and preview hosts serve HTTPS; some older responses still say `http`.
    static func secure(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        components.scheme = "https"
        return components.url ?? url
    }

    /// A file name such as `100x100bb.jpg`: a width, an `x`, a height, a suffix (`bb`, `cc`, `bb-60`…) and an
    /// extension.
    struct FileName: Equatable, CustomStringConvertible {
        var width: Int
        var height: Int
        var suffix: String
        var fileExtension: String

        init?(_ name: String) {
            guard let dot = name.lastIndex(of: ".") else { return nil }
            let base = name[..<dot]
            let fileExtension = String(name[name.index(after: dot)...])
            guard !fileExtension.isEmpty, let x = base.firstIndex(of: "x") else { return nil }
            let widthText = base[..<x]
            let rest = base[base.index(after: x)...]
            let heightText = rest.prefix(while: \.isASCIIDigit)
            guard !widthText.isEmpty, widthText.allSatisfy(\.isASCIIDigit), !heightText.isEmpty,
                  let width = Int(widthText), let height = Int(heightText)
            else { return nil }
            self.width = width
            self.height = height
            self.suffix = String(rest.dropFirst(heightText.count))
            self.fileExtension = fileExtension
        }

        var description: String {
            "\(width)x\(height)\(suffix).\(fileExtension)"
        }
    }
}

extension Artwork {
    /// The best artwork among the URLs the API returned for an item, preferring the largest.
    static func best(_ candidates: [URL?]) -> Artwork? {
        candidates.compactMap { $0 }.first.map(Artwork.init(url:))
    }
}
