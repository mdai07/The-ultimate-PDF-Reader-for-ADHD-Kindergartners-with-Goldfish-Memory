import Foundation

public enum ChatCitationSummary {
    public static func text(
        for citations: [SourceCitation],
        maximumVisiblePages: Int = 3
    ) -> String? {
        guard maximumVisiblePages > 0 else {
            return nil
        }

        var seenPages = Set<Int>()
        let pages = citations.compactMap { citation -> Int? in
            guard citation.pageIndex >= 0,
                  seenPages.insert(citation.pageIndex).inserted else {
                return nil
            }
            return citation.pageIndex + 1
        }
        guard !pages.isEmpty else {
            return nil
        }

        let visiblePages = pages.prefix(maximumVisiblePages)
            .map(String.init)
            .joined(separator: ", ")
        let remainingCount = pages.count - min(pages.count, maximumVisiblePages)
        let prefix = pages.count == 1 ? "Source: p." : "Sources: pp."
        if remainingCount > 0 {
            return "\(prefix) \(visiblePages) + \(remainingCount) more"
        }
        return "\(prefix) \(visiblePages)"
    }
}
