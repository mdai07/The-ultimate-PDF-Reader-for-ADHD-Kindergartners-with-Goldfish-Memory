import Foundation

public enum NavigationQuery: Equatable {
    case page(Int)
    case equation(String)
    case figure(String)
    case table(String)
}

public enum NavigationQueryParser {
    public static func parse(_ rawQuery: String) -> NavigationQuery? {
        let query = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !query.isEmpty else {
            return nil
        }

        if let page = positiveInt(query) {
            return .page(page)
        }

        if let page = firstCapture(in: query, pattern: #"^(?:p|page)\.?\s+([1-9]\d*)$"#),
           let pageNumber = Int(page) {
            return .page(pageNumber)
        }

        if let identifier = firstCapture(
            in: query,
            pattern: #"^(?:eq|equation)\.?\s*\(?\s*((?:[A-Za-z]\.?\d+|\d+)(?:\.\d+)*[a-z]?)\s*\)?$"#
        ) {
            return .equation(normalizedIdentifier(identifier))
        }

        if let identifier = firstCapture(
            in: query,
            pattern: #"^(?:fig|figure)\.?\s+([0-9]+[a-z]?|[ivxlcdm]+)$"#
        ) {
            return .figure(normalizedIdentifier(identifier))
        }

        if let identifier = firstCapture(
            in: query,
            pattern: #"^(?:tab|table)\.?\s+([0-9]+[a-z]?|[ivxlcdm]+)$"#
        ) {
            return .table(normalizedIdentifier(identifier))
        }

        return nil
    }

    private static func positiveInt(_ text: String) -> Int? {
        guard text.range(of: #"^[1-9]\d*$"#, options: .regularExpression) != nil else {
            return nil
        }
        return Int(text)
    }

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

    private static func normalizedIdentifier(_ text: String) -> String {
        text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "()")))
    }
}
