import Foundation

public enum MathSelectionAnalyzer {
    public static func shouldAttachImage(selectedText: String) -> Bool {
        let text = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return false
        }

        let mathSignals = text.reduce(into: 0) { count, character in
            if isMathSignal(character) {
                count += 1
            }
        }

        if mathSignals >= 2 {
            return true
        }

        if text.range(of: #"[A-Za-z0-9]\s*[\^_]\s*[A-Za-z0-9{}]"#, options: .regularExpression) != nil {
            return true
        }

        if text.range(of: #"\\(frac|sum|int|alpha|beta|gamma|delta|epsilon|lambda|mu|sigma|theta)"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private static func isMathSignal(_ character: Character) -> Bool {
        if "^_=+−-*/÷±∑∫∏√≈≃≠≤≥∞∂∇".contains(character) {
            return true
        }

        guard let scalar = character.unicodeScalars.first else {
            return false
        }

        switch scalar.value {
        case 0x0370...0x03FF, 0x1D400...0x1D7FF, 0x2070...0x209F:
            return true
        default:
            return false
        }
    }
}
