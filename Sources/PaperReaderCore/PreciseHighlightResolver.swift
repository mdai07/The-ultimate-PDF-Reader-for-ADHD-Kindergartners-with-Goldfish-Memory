import Foundation

public enum PreciseHighlightResolver {
    public static func refinedCitations(
        question: String,
        answer: String,
        session: DocumentSession,
        baseCitations: [SourceCitation]
    ) -> [SourceCitation] {
        let pages = searchablePages(in: session)

        if question.localizedCaseInsensitiveContains("after")
            || question.localizedCaseInsensitiveContains("following") {
            for anchor in quotedPhrases(in: question) {
                if let citation = citationForTextAfter(anchor: anchor, pages: pages) {
                    return [citation]
                }
            }
        }

        for phrase in quotedPhrases(in: answer) where phrase.count > 2 {
            if let citation = citationForExactPhrase(phrase, pages: pages, label: "matching answer text") {
                return [citation]
            }
        }

        return baseCitations
    }

    private struct SearchablePage {
        var pageIndex: Int
        var text: String
        var bounds: NormalizedRect?
    }

    private static func searchablePages(in session: DocumentSession) -> [SearchablePage] {
        let embedded = session.pages
            .sorted { $0.index < $1.index }
            .compactMap { page -> SearchablePage? in
                guard let text = page.embeddedText, !text.isEmpty else {
                    return nil
                }
                return SearchablePage(pageIndex: page.index, text: text, bounds: nil)
            }

        let ocr = session.ocrBlocks
            .filter { !$0.text.isEmpty }
            .map { block in
                SearchablePage(pageIndex: block.pageIndex, text: block.text, bounds: block.bounds)
            }

        return embedded + ocr
    }

    private static func citationForTextAfter(anchor: String, pages: [SearchablePage]) -> SourceCitation? {
        for page in pages {
            guard let anchorRange = page.text.range(
                of: anchor,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) else {
                continue
            }

            let remainder = String(page.text[anchorRange.upperBound...])
            guard let following = followingSentence(in: remainder) else {
                continue
            }

            return SourceCitation(
                pageIndex: page.pageIndex,
                label: "text after anchor",
                highlightText: following,
                bounds: page.bounds
            )
        }

        return nil
    }

    private static func citationForExactPhrase(
        _ phrase: String,
        pages: [SearchablePage],
        label: String
    ) -> SourceCitation? {
        let target = collapsedWhitespace(phrase)
        guard !target.isEmpty else {
            return nil
        }

        for page in pages where page.text.range(
            of: target,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil {
            return SourceCitation(
                pageIndex: page.pageIndex,
                label: label,
                highlightText: target,
                bounds: page.bounds
            )
        }

        return nil
    }

    private static func followingSentence(in text: String) -> String? {
        let trimmed = text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard !trimmed.isEmpty else {
            return nil
        }

        let line = trimmed
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

        if let terminator = line.firstIndex(where: { ".?!".contains($0) }) {
            return String(line[...terminator]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func quotedPhrases(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #""([^"]+)"|'([^']+)'|“([^”]+)”"#) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            for index in 1..<match.numberOfRanges {
                guard match.range(at: index).location != NSNotFound,
                      let range = Range(match.range(at: index), in: text) else {
                    continue
                }
                return collapsedWhitespace(String(text[range]))
            }
            return nil
        }
    }

    private static func collapsedWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
