import Foundation

public struct InlineSuggestionCandidate: Codable, Equatable {
    public var question: String
    public var answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

public enum InlineSuggestionHeuristics {
    public static func suggestions(
        forText text: String,
        paperMemory: String = "",
        pageLabel: String? = nil
    ) -> [InlineSuggestionCandidate] {
        let selected = collapsedWhitespace(text)
        guard !selected.isEmpty else {
            return []
        }

        let snippet = displaySnippet(selected)
        let paperAnchor = paperAnchor(from: paperMemory)
        let pageHint = pageLabel.map { " on \($0)" } ?? ""
        if let visualReference = visualReference(in: selected) {
            return visualTextSuggestions(
                reference: visualReference,
                selected: selected,
                paperAnchor: paperAnchor
            )
        }

        let isShortSelection = selected.count < 80 || looksLikeEquation(selected)

        if isShortSelection {
            let roleExplanation = looksLikeEquation(selected)
                ? "\"\(snippet)\" is an equation-level object; read it through the nearby definitions and its role in the derivation."
                : "\"\(snippet)\" is the selected term; interpret it through the surrounding sentence and later uses in the paper."

            return [
                InlineSuggestionCandidate(
                    question: "",
                    answer: "\"\(snippet)\" should be explained from the nearby text\(pageHint) and grounded in \(paperAnchor)."
                ),
                InlineSuggestionCandidate(
                    question: "",
                    answer: "The useful context is where \"\(snippet)\" is introduced, defined, or reused around this selection."
                ),
                InlineSuggestionCandidate(
                    question: "",
                    answer: roleExplanation
                )
            ]
        }

        let topic = topicPhrase(from: selected, fallback: "this passage")
        return [
            InlineSuggestionCandidate(
                question: "",
                answer: "This selected passage connects \(topic) with \(paperAnchor)."
            ),
            InlineSuggestionCandidate(
                question: "",
                answer: "\(topic) depends on the setup terms and definitions inside the selected passage."
            ),
            InlineSuggestionCandidate(
                question: "",
                answer: "The passage should be read as evidence for the paper's result, figure interpretation, or stated conclusion."
            )
        ]
    }

    public static func suggestions(
        forRegionKind regionKind: String,
        detail: String,
        paperMemory: String = ""
    ) -> [InlineSuggestionCandidate] {
        let kind = collapsedWhitespace(regionKind).lowercased()
        let resolvedKind = kind.isEmpty ? "region" : kind
        let topic = topicPhrase(from: detail, fallback: "the selected region")
        let paperAnchor = paperAnchor(from: paperMemory)

        return [
            InlineSuggestionCandidate(
                question: "",
                answer: "This \(resolvedKind) shows or summarizes \(topic), and should be read with its caption/OCR and \(paperAnchor)."
            ),
            InlineSuggestionCandidate(
                question: "",
                answer: "The important interpretation comes from the axes, labels, values, or contrasts tied to \(topic)."
            ),
            InlineSuggestionCandidate(
                question: "",
                answer: "The selected \(resolvedKind) links \(topic) to the nearby text and the paper's main claim."
            )
        ]
    }

    private struct VisualReference {
        var kind: String
        var label: String
        var topic: String
    }

    private static func visualTextSuggestions(
        reference: VisualReference,
        selected: String,
        paperAnchor: String
    ) -> [InlineSuggestionCandidate] {
        let action = reference.kind == "table" ? "summarizing" : "showing"
        let focus = reference.kind == "table" ? "columns, values, and comparisons" : "axes, curves, labels, and trends"
        let selectedSnippet = displaySnippet(selected, maxLength: 96)

        return [
            InlineSuggestionCandidate(
                question: "",
                answer: "\(reference.label) is \(action) \(reference.topic) through the selected text: \(selectedSnippet)"
            ),
            InlineSuggestionCandidate(
                question: "",
                answer: "For \(reference.label), focus on the \(focus) tied to \(reference.topic)."
            ),
            InlineSuggestionCandidate(
                question: "",
                answer: "\(reference.label)'s selected text on \(reference.topic) should be connected to \(paperAnchor) without replacing the selected details."
            )
        ]
    }

    private static func paperAnchor(from paperMemory: String) -> String {
        let memory = collapsedWhitespace(paperMemory)
        guard !memory.isEmpty else {
            return "the whole-paper context"
        }
        let topic = topicPhrase(from: memory, fallback: "the whole-paper context")
        if topic == "the whole-paper context" {
            return topic
        }
        return "the paper context around \(topic)"
    }

    private static func topicPhrase(from text: String, fallback: String) -> String {
        let terms = meaningfulTokens(from: text)
        guard !terms.isEmpty else {
            return fallback
        }

        if let phrase = adjacentPhrase(in: terms, preferredLength: 3) {
            return phrase
        }
        if let phrase = adjacentPhrase(in: terms, preferredLength: 2) {
            return phrase
        }
        return terms.first ?? fallback
    }

    private static func visualReference(in text: String) -> VisualReference? {
        let lower = text.lowercased()
        let candidates: [(kind: String, pattern: String)] = [
            ("figure", #"\b(?:figure|fig\.?)\s*([0-9]+[a-z]?|[ivxlcdm]+)?"#),
            ("table", #"\btable\s*([0-9]+[a-z]?|[ivxlcdm]+)?"#)
        ]

        for candidate in candidates {
            guard let match = lower.range(
                of: candidate.pattern,
                options: [.regularExpression, .caseInsensitive]
            ) else {
                continue
            }

            let rawLabel = String(text[match]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            let label = canonicalVisualLabel(rawLabel, kind: candidate.kind)
            return VisualReference(
                kind: candidate.kind,
                label: label,
                topic: topicPhrase(from: text, fallback: label.lowercased())
            )
        }

        return nil
    }

    private static func canonicalVisualLabel(_ rawLabel: String, kind: String) -> String {
        let trimmed = collapsedWhitespace(rawLabel)
        guard !trimmed.isEmpty else {
            return kind.capitalized
        }

        let words = trimmed.split(separator: " ").map(String.init)
        if words.count == 1 {
            return kind.capitalized
        }
        let suffix = words.dropFirst().joined(separator: " ")
        return "\(kind.capitalized) \(suffix)"
    }

    private static func adjacentPhrase(in terms: [String], preferredLength: Int) -> String? {
        guard terms.count >= preferredLength else {
            return nil
        }
        let candidate = terms.prefix(preferredLength).joined(separator: " ")
        return candidate.isEmpty ? nil : candidate
    }

    private static func meaningfulTokens(from text: String) -> [String] {
        tokens(from: text)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { token in
                token.count > 2
                    && !stopWords.contains(token)
                    && !token.allSatisfy(\.isNumber)
            }
    }

    private static func tokens(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z][A-Za-z0-9-]*"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else {
                return nil
            }
            return String(text[matchRange])
        }
    }

    private static func looksLikeEquation(_ text: String) -> Bool {
        let strongMarkers = ["=", "\\", "^", "_"]
        if strongMarkers.contains(where: { text.contains($0) }) {
            return true
        }
        return text.range(
            of: #"\b[A-Za-z0-9]\s*[+/*-]\s*[A-Za-z0-9]\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func collapsedWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displaySnippet(_ text: String, maxLength: Int = 72) -> String {
        let clean = collapsedWhitespace(text)
        guard clean.count > maxLength else {
            return clean
        }
        let end = clean.index(clean.startIndex, offsetBy: max(0, maxLength - 3))
        return "\(clean[..<end])..."
    }

    private static let stopWords: Set<String> = [
        "about", "across", "after", "again", "also", "analysis", "and", "are", "axis",
        "before", "being", "between", "caption", "can", "claim", "compares", "conclusion",
        "current", "data", "does", "each", "equation", "figure", "fig", "for", "from",
        "have", "here", "how", "image", "into", "label", "labels", "main", "near",
        "nearby", "not", "ocr", "paper", "page", "passage", "plot", "result", "results",
        "section", "selected", "several", "show", "shows", "studies", "table", "text",
        "that", "the", "their", "then", "this", "those", "through", "using", "uses",
        "versus", "what", "when", "where", "which", "with"
    ]
}
