import Foundation

public enum PaperOutlineInference {
    public static func sectionTitle(from line: String) -> String? {
        let trimmed = cleanLine(line)
        guard trimmed.count <= 120, trimmed.count >= 3 else {
            return nil
        }

        if let appendixTitle = appendixTitle(from: trimmed) {
            return appendixTitle
        }

        let lower = trimmed.lowercased()
        let namedSections = [
            "abstract", "introduction", "background", "related work", "theory",
            "model", "models", "method", "methods", "methodology", "setup",
            "experiment", "experiments", "results", "analysis", "discussion",
            "conclusion", "conclusions", "summary", "acknowledgements",
            "acknowledgments", "appendix", "appendices", "supplementary material",
            "supplemental material", "references"
        ]
        if namedSections.contains(lower) {
            return titleCased(trimmed)
        }

        if matches(trimmed, #"^(abstract|introduction|background|related work|theory|model|methods?|methodology|setup|experiments?|results|analysis|discussion|conclusions?|summary|acknowledg(e)?ments|appendix|appendices|supplement(al|ary)\s+material|references)\b[:.]?\s+.{1,80}$"#) {
            return trimmedTitle(trimmed)
        }

        if matches(trimmed, #"^(section|sec\.?)\s+([0-9]+(\.[0-9]+)*|[IVXLCDM]+)\.?\s*[:.]?\s+[A-Z][A-Za-z0-9,.\-–—:() ]{2,100}$"#) {
            return trimmedTitle(trimmed)
        }

        if matches(trimmed, #"^([0-9]+(\.[0-9]+)*|[IVXLCDM]+)\.?\s+[A-Z][A-Za-z0-9,.\-–—:() ]{2,100}$"#) {
            return trimmedTitle(trimmed)
        }

        return nil
    }

    public static func figureOrTableLabel(from line: String) -> String? {
        let trimmed = cleanLine(line)
        guard trimmed.count >= 5 else {
            return nil
        }

        if let figureIdentifier = firstCapture(
            in: trimmed,
            pattern: #"^(?:fig\.?|figure)\s*([0-9]+[A-Za-z]?|[A-Z][0-9]+[A-Za-z]?)(?=\s*[:.)\-–—])"#
        ) {
            return "Figure \(figureIdentifier)"
        }

        if let tableIdentifier = firstCapture(
            in: trimmed,
            pattern: #"^table\s*([0-9]+[A-Za-z]?|[A-Z][0-9]+[A-Za-z]?)(?=\s*[:.)\-–—])"#
        ) {
            return "Table \(tableIdentifier)"
        }

        return nil
    }

    public static func sectionTitles(in text: String) -> [String] {
        var titles: [String] = []
        var seen = Set<String>()

        func append(_ title: String) {
            let displayTitle = normalizedDisplayTitle(title)
            let key = displayTitle.lowercased()
            if seen.insert(key).inserted {
                titles.append(displayTitle)
            }
        }

        for line in text
            .components(separatedBy: .newlines)
            .map(cleanLine)
            where !line.isEmpty {
            if let title = sectionTitle(from: line) {
                append(title)
            }
        }

        for pattern in flattenedSectionPatterns {
            for candidate in captures(in: cleanLine(text), pattern: pattern) {
                if let title = sectionTitle(from: candidate) {
                    append(title)
                }
            }
        }

        return titles
    }

    public static func cleanLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func trimmedTitle(_ title: String, maxLength: Int = 82) -> String {
        let clean = cleanLine(title)
        let truncated: String
        if clean.count > maxLength {
            truncated = String(clean.prefix(maxLength - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        } else {
            truncated = clean
        }
        guard truncated.count > 1, truncated.hasSuffix(".") else {
            return truncated
        }
        return String(truncated.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendixTitle(from trimmed: String) -> String? {
        if matches(trimmed, #"^appendix\s+[A-Z0-9]+([:.]\s*|\s+)?[A-Z0-9,.\-–—:() ]{0,100}$"#) {
            return titleCasedAppendix(trimmedTitle(trimmed))
        }

        if matches(trimmed, #"^appendices[:.]?\s+.{0,90}$"#) {
            return trimmedTitle(trimmed)
        }

        if matchesCaseSensitive(trimmed, #"^[A-H]\.?\s+[A-Z][A-Za-z0-9,.\-–—:() ]{2,100}$"#) {
            return trimmedTitle(trimmed)
        }

        return nil
    }

    private static func titleCased(_ title: String) -> String {
        title
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private static func titleCasedAppendix(_ title: String) -> String {
        guard title.range(of: #"^appendix\b"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return title
        }
        let rest = title.dropFirst("appendix".count)
        return "Appendix" + rest
    }

    private static func normalizedDisplayTitle(_ title: String) -> String {
        let clean = cleanLine(title)
        if let sectionPrefixed = firstCapture(
            in: clean,
            pattern: #"^[0-9]+(?:\.[0-9]+)*\.?\s+((?:Section|Sec\.?)\s+.+)$"#
        ), let normalized = sectionTitle(from: sectionPrefixed) {
            return normalized
        }
        return clean
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func matchesCaseSensitive(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression]) != nil
    }

    private static let flattenedSectionPatterns = [
        #"((?:Section|Sec\.?)\s+[0-9A-Za-z.]+[:.]?\s+[A-Z][A-Za-z0-9,.\-–—:() ]{2,100}?)(?=\s+(?:This|The|We|Equation|Figure|Fig\.?|Table|Main-|Appendix|References|[0-9]+(?:\.[0-9]+)*\.?\s+Section|(?:Section|Sec\.?)\s+[0-9A-Za-z.]+)|$)"#,
        #"([0-9]+(?:\.[0-9]+)*\.?\s+Section\s+[0-9A-Za-z.]+[:.]?\s+[A-Z][A-Za-z0-9,.\-–—:() ]{2,100}?)(?=\s+(?:This|The|We|Equation|Figure|Fig\.?|Table|Main-|Appendix|References|[0-9]+(?:\.[0-9]+)*\.?\s+Section)|$)"#,
        #"(Appendix\s+[A-Z0-9]+[:.]?\s+[A-Z][A-Za-z0-9,.\-–—:() ]{2,100}?)(?=\s+(?:This|The|We|Equation|Figure|Fig\.?|Table|Main-|References)|$)"#
    ]

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    private static func captures(in text: String, pattern: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[captureRange])
        }
    }
}
