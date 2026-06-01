import Foundation

public enum InlineSuggestionScrollPolicy {
    public static func needsNestedScroll(_ answer: String) -> Bool {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let lineCount = trimmed.split(whereSeparator: \.isNewline).count
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        let hasEquationMarkup = trimmed.contains("$") || trimmed.contains("\\(") || trimmed.contains("\\[")

        return trimmed.count > 220
            || wordCount > 36
            || lineCount > 4
            || (hasEquationMarkup && trimmed.count > 140)
    }

    public static func answerMaxHeight(panelHeight: Double) -> Double {
        min(max((panelHeight * 0.48).rounded(), 72), 140)
    }
}
