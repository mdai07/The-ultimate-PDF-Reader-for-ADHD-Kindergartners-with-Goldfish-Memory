import Foundation

public enum SearchSource: String, Codable, Equatable {
    case embeddedText
    case ocr
}

public struct SearchResult: Codable, Equatable {
    public var pageIndex: Int
    public var source: SearchSource
    public var snippet: String
    public var bounds: NormalizedRect?

    public init(pageIndex: Int, source: SearchSource, snippet: String, bounds: NormalizedRect? = nil) {
        self.pageIndex = pageIndex
        self.source = source
        self.snippet = snippet
        self.bounds = bounds
    }
}

public struct SearchIndex {
    private struct Entry {
        var pageIndex: Int
        var source: SearchSource
        var text: String
        var bounds: NormalizedRect?
    }

    private var entries: [Entry]

    public init(session: DocumentSession) {
        var builtEntries: [Entry] = []

        for page in session.pages {
            if let embeddedText = page.embeddedText, !embeddedText.isEmpty {
                builtEntries.append(
                    Entry(pageIndex: page.index, source: .embeddedText, text: embeddedText, bounds: nil)
                )
            }
        }

        for block in session.ocrBlocks where !block.text.isEmpty {
            builtEntries.append(
                Entry(pageIndex: block.pageIndex, source: .ocr, text: block.text, bounds: block.bounds)
            )
        }

        entries = builtEntries
    }

    public func search(_ query: String, limit: Int = 20) -> [SearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return entries.compactMap { entry in
            guard entry.text.range(of: normalizedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil else {
                return nil
            }

            return SearchResult(
                pageIndex: entry.pageIndex,
                source: entry.source,
                snippet: Self.snippet(in: entry.text, matching: normalizedQuery),
                bounds: entry.bounds
            )
        }
        .prefix(limit)
        .map { $0 }
    }

    private static func snippet(in text: String, matching query: String) -> String {
        guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(text.prefix(180))
        }

        let lower = text.index(range.lowerBound, offsetBy: -60, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: 80, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lower..<upper])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
