import Foundation

public struct AISuggestionExplanation: Equatable {
    public var prompt: String
    public var explanation: String

    public init(prompt: String, explanation: String) {
        self.prompt = prompt
        self.explanation = explanation
    }
}

public enum AISuggestionNoteFormatter {
    public static func commentBodyForDisplay(_ body: String) -> String {
        legacyQuestionAnswerNote(from: body)
            ?? legacyBoldQuestionNote(from: body)
            ?? body
    }

    public static func marginNote(
        contextTitle: String?,
        suggestions: [AISuggestionExplanation],
        limit: Int = 3
    ) -> String {
        var sections: [String] = []
        _ = contextTitle

        let explanations = suggestions
            .prefix(max(0, limit))
            .map { explanation(for: $0) }
            .filter { !$0.isEmpty }

        if explanations.count > 1 {
            sections.append(explanations.map { "- \($0)" }.joined(separator: "\n"))
        } else {
            sections.append(contentsOf: explanations)
        }

        if sections.isEmpty {
            return fallbackExplanation
        }
        return sections.joined(separator: "\n\n")
    }

    public static func explanation(for suggestion: AISuggestionExplanation) -> String {
        let cleaned = stripQuestionAnswerLabels(from: suggestion.explanation)
        if cleaned.isEmpty {
            return fallbackExplanation
        }
        return cleaned
    }

    private static var fallbackExplanation: String {
        "This selection needs more context before it can be explained clearly."
    }

    private static func stripQuestionAnswerLabels(from text: String) -> String {
        let cleanedLines = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return nil
                }
                if isQuestionLabelLine(trimmed) {
                    return nil
                }
                return stripLeadingExplanationLabel(from: trimmed)
            }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isQuestionLabelLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.hasPrefix("question:")
            || lowercased.hasPrefix("q:")
            || lowercased.hasPrefix("**question:**")
            || lowercased.hasPrefix("**q:**")
    }

    private static func stripLeadingExplanationLabel(from line: String) -> String {
        let labels = [
            "answer:",
            "a:",
            "explanation:",
            "**answer:**",
            "**a:**",
            "**explanation:**"
        ]
        let lowercased = line.lowercased()
        for label in labels where lowercased.hasPrefix(label) {
            let index = line.index(line.startIndex, offsetBy: label.count)
            return String(line[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line
    }

    private static func legacyQuestionAnswerNote(from body: String) -> String? {
        guard body.range(of: "Question:", options: .caseInsensitive) != nil,
              body.range(of: "Answer:", options: .caseInsensitive) != nil else {
            return nil
        }

        let answers = body
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard let answerRange = line.range(of: "Answer:", options: .caseInsensitive) else {
                    return nil
                }
                let answer = String(line[answerRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return answer.isEmpty ? nil : answer
            }

        guard !answers.isEmpty else {
            return nil
        }

        return marginNote(
            contextTitle: legacyContextTitle(from: body),
            suggestions: answers.map { AISuggestionExplanation(prompt: "", explanation: $0) },
            limit: answers.count
        )
    }

    private static func legacyBoldQuestionNote(from body: String) -> String? {
        let lines = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1,
              let heading = unwrappedBoldMarkdown(lines[0]),
              heading.contains("?") else {
            return nil
        }

        return lines.dropFirst().joined(separator: "\n\n")
    }

    private static func legacyContextTitle(from body: String) -> String? {
        guard let contextRange = body.range(of: "Context:", options: .caseInsensitive) else {
            return nil
        }

        let tail = body[contextRange.upperBound...]
        let line = tail.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let title = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? line
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func unwrappedBoldMarkdown(_ line: String) -> String? {
        guard line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4 else {
            return nil
        }
        let start = line.index(line.startIndex, offsetBy: 2)
        let end = line.index(line.endIndex, offsetBy: -2)
        return String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
