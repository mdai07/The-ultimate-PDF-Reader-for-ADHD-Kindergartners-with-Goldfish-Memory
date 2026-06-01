import Foundation

public enum SidebarChatScrollPolicy {
    public static func needsNestedScroll(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let lineCount = trimmed.split(whereSeparator: \.isNewline).count
        let wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        let hasEquationMarkup = trimmed.contains("$") || trimmed.contains("\\(") || trimmed.contains("\\[")

        return trimmed.count > 900
            || wordCount > 130
            || lineCount > 14
            || (hasEquationMarkup && trimmed.count > 520)
    }

    public static func bubbleMaxHeight(viewportHeight: Double) -> Double {
        min(max((viewportHeight * 0.50).rounded(), 150), 320)
    }
}
