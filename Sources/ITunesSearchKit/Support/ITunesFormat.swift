import Foundation

/// Small formatting helpers for what the API returns.
public enum ITunesFormat {
    /// A running time such as `"3:45"` or `"1:02:03"`. Negative and non-finite values give `"0:00"`.
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 {
            return String(format: "%ld:%02ld:%02ld", hours, minutes, rest)
        }
        return String(format: "%ld:%02ld", minutes, rest)
    }

    /// A longer running time such as `"2 hr 49 min"` or `"42 min"`, for movies and podcast episodes.
    public static func longDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 min" }
        let totalMinutes = max(1, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _):
            return "\(minutes) min"
        case (_, 0):
            return "\(hours) hr"
        default:
            return "\(hours) hr \(minutes) min"
        }
    }

    /// A file size such as `"245.3 MB"`.
    public static func fileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// The year of a release date, in UTC as the API sends it.
    public static func year(of date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return calendar.component(.year, from: date)
    }
}

/// Dates as the API sends them: `2013-05-17T07:00:00Z`, sometimes with fractional seconds, sometimes only a day.
enum ITunesDate {
    static func parse(_ text: String) -> Date? {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if let date = try? Date(text, strategy: .iso8601) {
            return date
        }
        if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        // A day only, such as 2013-05-17.
        let parts = text.prefix(10).split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

/// Plain text from the light HTML some descriptions contain (books and some apps and podcasts).
public enum ITunesText {
    /// Removes tags, turns `<br>` and paragraph ends into line breaks, decodes common entities and collapses runs of
    /// blank lines.
    ///
    /// ```swift
    /// ITunesText.plainText(fromHTML: "<b>Bestseller</b><br />A &quot;novel&quot; &amp; more")
    /// // "Bestseller\nA \"novel\" & more"
    /// ```
    public static func plainText(fromHTML html: String) -> String {
        var output = ""
        var index = html.startIndex
        while index < html.endIndex {
            let character = html[index]
            if character == "<", startsTag(in: html, at: index), let close = html[index...].firstIndex(of: ">") {
                let tag = html[html.index(after: index)..<close]
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                let name = tag.drop(while: { $0 == "/" }).prefix(while: { $0.isLetter || $0.isNumber })
                if name == "br" || (tag.hasPrefix("/") && (name == "p" || name == "div" || name == "li")) {
                    output.append("\n")
                } else if name == "li" {
                    output.append("• ")
                }
                index = html.index(after: close)
            } else if character == "&", let semicolon = html[index...].prefix(10).firstIndex(of: ";"),
                      let decoded = decodeEntity(String(html[html.index(after: index)..<semicolon])) {
                output.append(decoded)
                index = html.index(after: semicolon)
            } else {
                output.append(character)
                index = html.index(after: index)
            }
        }
        // Trim every line, and keep at most one blank line in a row.
        var lines: [String] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty, lines.last?.isEmpty ?? true {
                continue
            }
            lines.append(trimmed)
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    /// Whether the `<` at `index` opens a tag (`<b>`, `</p>`, `<!-- -->`) rather than being a less-than sign.
    static func startsTag(in html: String, at index: String.Index) -> Bool {
        let next = html.index(after: index)
        guard next < html.endIndex else { return false }
        let character = html[next]
        return character.isLetter || character == "/" || character == "!"
    }

    static func decodeEntity(_ entity: String) -> String? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return " "
        case "mdash": return "—"
        case "ndash": return "–"
        case "hellip": return "…"
        case "rsquo": return "’"
        case "lsquo": return "‘"
        case "rdquo": return "”"
        case "ldquo": return "“"
        default:
            guard entity.hasPrefix("#") else { return nil }
            let digits = entity.dropFirst()
            let value: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits)
            }
            guard let value, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
    }
}
