import Foundation

public enum AnnotationIdentity {
    public static func key(
        pageIndex: Int,
        kind: AnnotationKind,
        bounds: NormalizedRect,
        contents: String? = nil
    ) -> String {
        [
            "page:\(pageIndex)",
            "kind:\(kind.rawValue)",
            "x:\(rounded(bounds.x))",
            "y:\(rounded(bounds.y))",
            "w:\(rounded(bounds.width))",
            "h:\(rounded(bounds.height))",
            "text:\(normalizedContents(contents))"
        ].joined(separator: "|")
    }

    private static func rounded(_ value: Double) -> String {
        String(Int((value * 10_000).rounded()))
    }

    private static func normalizedContents(_ contents: String?) -> String {
        (contents ?? "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
