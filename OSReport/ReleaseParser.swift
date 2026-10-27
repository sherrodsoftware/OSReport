import Foundation

struct Release: Sendable {
    let name: String
    let version: String
    let url: URL
    let date: String
}

enum OSKind: String, CaseIterable, Sendable {
    case macOS, iOS, iPadOS, watchOS, tvOS, visionOS

    init?(name: String) {
        guard let kind = Self.allCases.first(where: { name.hasPrefix($0.rawValue + " ") }) else { return nil }
        self = kind
    }

    var symbolName: String {
        switch self {
        case .macOS: "laptopcomputer"
        case .iOS: "iphone"
        case .iPadOS: "ipad"
        case .watchOS: "applewatch"
        case .tvOS: "appletv"
        case .visionOS: "visionpro"
        }
    }
}

struct Platform: Sendable {
    let name: String
    let releases: [Release]
    var latest: Release { releases[0] }
    var kind: OSKind? { OSKind(name: name + " ") }
}

enum ReleaseParser {
    static let pageURL = URL(string: "https://support.apple.com/en-us/100100")!

    static func parse(_ html: String) -> [Platform] {
        let rowRegex = /<tr>(.*?)<\/tr>/.dotMatchesNewlines()
        let cellRegex = /<td[^>]*>(.*?)<\/td>/.dotMatchesNewlines()
        let linkRegex = /<a[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>/.dotMatchesNewlines()
        let firstParagraph = /<p[^>]*>(.*?)<\/p>/.dotMatchesNewlines()
        let versionRegex = /\d+(?:\.\d+)+|\b\d+\b/

        var groups: [String: [Release]] = [:]
        var order: [String] = []

        for row in html.matches(of: rowRegex) {
            let cells = row.output.1.matches(of: cellRegex).map { String($0.output.1) }
            guard cells.count >= 3 else { continue }

            let nameCell = cells[0]
            let rawName: String
            let url: URL
            if let link = nameCell.firstMatch(of: linkRegex) {
                rawName = String(link.output.2)
                url = URL(string: String(link.output.1), relativeTo: pageURL)?.absoluteURL ?? pageURL
            } else if let p = nameCell.firstMatch(of: firstParagraph) {
                rawName = String(p.output.1)
                url = pageURL
            } else { continue }

            let date = clean(cells[2])
            for component in clean(rawName).split(separator: /\s+and\s+/).map(String.init) {
                guard OSKind(name: component) != nil,
                      let version = component.firstMatch(of: versionRegex).map({ String($0.output) }) else { continue }
                let key = platformName(from: component)
                if groups[key] == nil { order.append(key) }
                groups[key, default: []].append(Release(name: component, version: version, url: url, date: date))
            }
        }

        let platforms = order.map { key in
            let sorted = groups[key]!.enumerated().sorted { a, b in
                let cmp = a.element.version.compare(b.element.version, options: .numeric)
                return cmp == .orderedSame ? a.offset < b.offset : cmp == .orderedDescending
            }.map(\.element)
            return Platform(name: key, releases: sorted)
        }

        let newestMac = platforms.filter { $0.kind == .macOS }
            .max { $0.latest.version.compare($1.latest.version, options: .numeric) == .orderedAscending }?.name

        func rank(_ p: Platform) -> Int {
            switch p.kind {
            case .macOS: p.name == newestMac ? 0 : 4
            case .iOS: 1
            case .iPadOS: 2
            default: 3
            }
        }
        return platforms.enumerated().sorted { a, b in
            let ra = rank(a.element), rb = rank(b.element)
            if ra != rb { return ra < rb }
            if ra == 4 {
                let cmp = a.element.latest.version.compare(b.element.latest.version, options: .numeric)
                if cmp != .orderedSame { return cmp == .orderedDescending }
            }
            return a.offset < b.offset
        }.map(\.element)
    }

    private static func platformName(from name: String) -> String {
        var s = name
        s = s.replacing(/\s*\([^)]*\)/, with: "")
        s = s.replacing(/\d+(?:\.\d+)+|\b\d+\b/, with: "")
        s = s.replacing(/\s+/, with: " ")
        return s.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ",")))
    }

    private static func clean(_ html: String) -> String {
        var s = html.replacing(/<[^>]+>/, with: "")
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        return s.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
