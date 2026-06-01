import Foundation

public enum SelectionShortcutAction: String, Codable, CaseIterable, Equatable, Identifiable {
    case inlineSuggestions
    case marginComment
    case highlight

    public var id: String { rawValue }

    public var defaultKey: String {
        switch self {
        case .inlineSuggestions:
            return "q"
        case .marginComment:
            return "m"
        case .highlight:
            return "h"
        }
    }

    public var title: String {
        switch self {
        case .inlineSuggestions:
            return "Show inline suggestions"
        case .marginComment:
            return "Add margin comment"
        case .highlight:
            return "Highlight selection"
        }
    }
}

public struct SelectionShortcutBindings: Codable, Equatable {
    public var inlineSuggestionsKey: String
    public var marginCommentKey: String
    public var highlightKey: String

    public init(
        inlineSuggestionsKey: String = SelectionShortcutAction.inlineSuggestions.defaultKey,
        marginCommentKey: String = SelectionShortcutAction.marginComment.defaultKey,
        highlightKey: String = SelectionShortcutAction.highlight.defaultKey
    ) {
        self.inlineSuggestionsKey = Self.normalizedKey(
            inlineSuggestionsKey,
            fallback: SelectionShortcutAction.inlineSuggestions.defaultKey
        )
        self.marginCommentKey = Self.normalizedKey(
            marginCommentKey,
            fallback: SelectionShortcutAction.marginComment.defaultKey
        )
        self.highlightKey = Self.normalizedKey(
            highlightKey,
            fallback: SelectionShortcutAction.highlight.defaultKey
        )
    }

    public func key(for action: SelectionShortcutAction) -> String {
        switch action {
        case .inlineSuggestions:
            return inlineSuggestionsKey
        case .marginComment:
            return marginCommentKey
        case .highlight:
            return highlightKey
        }
    }

    public func action(for typedKey: String) -> SelectionShortcutAction? {
        let normalized = Self.normalizedKey(typedKey, fallback: "")
        guard !normalized.isEmpty else {
            return nil
        }
        return SelectionShortcutAction.allCases.first { action in
            key(for: action) == normalized
        }
    }

    public func updating(_ action: SelectionShortcutAction, key rawKey: String) -> SelectionShortcutBindings {
        var updated = self
        let key = Self.normalizedKey(rawKey, fallback: action.defaultKey)
        switch action {
        case .inlineSuggestions:
            updated.inlineSuggestionsKey = key
        case .marginComment:
            updated.marginCommentKey = key
        case .highlight:
            updated.highlightKey = key
        }
        return updated
    }

    public static func normalizedKey(_ rawKey: String, fallback: String) -> String {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let first = trimmed.first else {
            return fallback
        }
        return String(first)
    }
}
