import Foundation

public struct EquationReference: Equatable, Hashable {
    public var matchedText: String
    public var citation: SourceCitation

    public init(matchedText: String, citation: SourceCitation) {
        self.matchedText = matchedText
        self.citation = citation
    }
}

public enum EquationReferenceResolver {
    public static func citation(
        forEquationIdentifier identifier: String,
        in session: DocumentSession,
        displayText: String? = nil
    ) -> SourceCitation? {
        let normalized = normalizedIdentifier(identifier)
        guard !normalized.isEmpty else {
            return nil
        }
        return citation(
            for: normalized,
            displayText: displayText ?? "Eq. (\(normalized))",
            pages: searchablePages(in: session)
        )
    }

    public static func references(in replyText: String, session: DocumentSession) -> [EquationReference] {
        let candidates = referenceCandidates(in: replyText)
        guard !candidates.isEmpty else {
            return []
        }

        let pages = searchablePages(in: session)
        var references: [EquationReference] = []
        var seen = Set<String>()

        for candidate in candidates {
            guard seen.insert(candidate.matchedText).inserted else {
                continue
            }
            for identifier in candidate.identifiers {
                if let citation = citation(for: identifier, displayText: candidate.matchedText, pages: pages) {
                    references.append(EquationReference(matchedText: candidate.matchedText, citation: citation))
                    break
                }
            }
        }

        return references
    }

    private struct ReferenceCandidate {
        var matchedText: String
        var identifiers: [String]
    }

    private struct SearchablePage {
        var pageIndex: Int
        var text: String
        var bounds: NormalizedRect?
    }

    private static func referenceCandidates(in text: String) -> [ReferenceCandidate] {
        guard let expression = try? NSRegularExpression(
            pattern: #"\b(?:Eq(?:s)?\.?|Equation(?:s)?)\s*(?:[:#]?\s*)?((?:\(?\s*(?:[A-Za-z]\.?\d+|\d+)(?:\.\d+)*[a-z]?\s*\)?\s*(?:,|and|to|[-–—])?\s*)+)"#,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: nsRange).compactMap { match in
            guard let fullRange = Range(match.range(at: 0), in: text),
                  let bodyRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            let matchedText = trimmedReferenceText(String(text[fullRange]))
            let body = String(text[bodyRange])
            let identifiers = identifiers(in: body, expandSimpleRanges: body.contains("-")
                || body.contains("–")
                || body.contains("—")
                || body.localizedCaseInsensitiveContains("to"))
            guard !matchedText.isEmpty, !identifiers.isEmpty else {
                return nil
            }
            return ReferenceCandidate(matchedText: matchedText, identifiers: identifiers)
        }
    }

    private static func identifiers(in text: String, expandSimpleRanges: Bool) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"(?:[A-Za-z]\.?\d+|\d+)(?:\.\d+)*[a-z]?"#,
            options: []
        ) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var raw = expression.matches(in: text, range: nsRange).compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else {
                return nil
            }
            return String(text[range])
        }

        if expandSimpleRanges,
           raw.count == 2,
           let first = Int(raw[0]),
           let last = Int(raw[1]),
           first <= last,
           last - first <= 20 {
            raw = (first...last).map(String.init)
        }

        var seen = Set<String>()
        return raw.filter { seen.insert($0).inserted }
    }

    private static func trimmedReferenceText(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
    }

    private static func normalizedIdentifier(_ text: String) -> String {
        text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "()")))
    }

    private static func searchablePages(in session: DocumentSession) -> [SearchablePage] {
        let embedded = session.pages
            .sorted { $0.index < $1.index }
            .compactMap { page -> SearchablePage? in
                guard let text = page.embeddedText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return SearchablePage(pageIndex: page.index, text: text, bounds: nil)
            }

        let ocr = session.ocrBlocks
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.pageIndex != $1.pageIndex {
                    return $0.pageIndex < $1.pageIndex
                }
                return $0.bounds.y < $1.bounds.y
            }
            .map {
                SearchablePage(pageIndex: $0.pageIndex, text: $0.text, bounds: $0.bounds)
            }

        return embedded + ocr
    }

    private static func citation(
        for identifier: String,
        displayText: String,
        pages: [SearchablePage]
    ) -> SourceCitation? {
        let variants = searchVariants(for: identifier)

        for page in pages {
            for variant in variants {
                if let match = firstMatch(of: variant, in: page.text) {
                    return SourceCitation(
                        pageIndex: page.pageIndex,
                        label: displayText,
                        highlightText: match,
                        bounds: page.bounds
                    )
                }
            }
        }

        return nil
    }

    private static func searchVariants(for identifier: String) -> [String] {
        let escaped = NSRegularExpression.escapedPattern(for: identifier)
        var variants = [
            #"\(\s*\#(escaped)\s*\)"#,
            #"\[\s*\#(escaped)\s*\]"#,
            #"\bEq(?:uation)?\.?\s*\(?\s*\#(escaped)\s*\)?"#
        ]

        if identifier.count >= 2 || identifier.contains(".") || identifier.rangeOfCharacter(from: .letters) != nil {
            variants.append(#"(?<!\d)\#(escaped)(?!\d)"#)
        }

        return variants
    }

    private static func firstMatch(of pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
