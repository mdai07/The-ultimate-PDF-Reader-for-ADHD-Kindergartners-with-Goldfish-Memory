import Foundation

public struct InlineAutocompleteEngine: Equatable {
    public init() {}

    public func candidates(
        typed: String,
        preferredQuestions: [String],
        fallbackQuestions: [String] = Self.defaultFallbackQuestions,
        limit: Int = 3
    ) -> [String] {
        let normalizedTyped = normalize(typed)
        guard !normalizedTyped.isEmpty else {
            return []
        }

        let tokens = normalizedTyped
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        let questions = (preferredQuestions + fallbackQuestions)
            .filter { seen.insert($0).inserted }

        let directMatches = questions
            .filter { normalize($0).hasPrefix(normalizedTyped) }
            .sorted { lhs, rhs in
                lhs.count < rhs.count
            }
            .prefix(limit)
            .map { $0 }

        if !directMatches.isEmpty {
            return directMatches
        }

        seen.removeAll()
        let generatedMatches = questions
            .compactMap { completion(from: normalizedTyped, tokens: tokens, question: $0) }
            .filter { seen.insert($0).inserted }
            .filter { normalize($0).hasPrefix(normalizedTyped) }
            .prefix(limit)
            .map { $0 }

        if !generatedMatches.isEmpty {
            return generatedMatches
        }

        guard let aggregateMatch = aggregateCompletion(
            from: normalizedTyped,
            tokens: tokens,
            questions: questions
        ) else {
            return []
        }
        return [aggregateMatch]
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func completion(from normalizedTyped: String, tokens: [String], question: String) -> String? {
        let questionWords = normalize(question)
            .split(separator: " ")
            .map(String.init)

        guard typedTokens(tokens, matchQuestionWords: questionWords) else {
            return nil
        }

        var completedTokens = tokens
        if let last = tokens.last,
           let completedLast = questionWords.first(where: { $0.hasPrefix(last) && $0.count > last.count }) {
            completedTokens[completedTokens.count - 1] = completedLast
        }

        let base = completedTokens.joined(separator: " ")
        let suffix = suffixForCompletion(questionWords: questionWords, baseTokens: completedTokens)
        if suffix.isEmpty {
            return "\(base)?"
        }
        return "\(base) \(suffix)?"
    }

    private func aggregateCompletion(
        from normalizedTyped: String,
        tokens: [String],
        questions: [String]
    ) -> String? {
        guard !tokens.isEmpty else {
            return nil
        }

        let wordGroups = questions.map { question in
            normalize(question)
                .split(separator: " ")
                .map(String.init)
        }
        let allWords = wordGroups.flatMap { $0 }
        var completedTokens = tokens
        if let last = tokens.last,
           let completedLast = bestWordCompletion(for: last, in: allWords) {
            completedTokens[completedTokens.count - 1] = completedLast
        }

        let matchedWords = wordGroups
            .filter { words in
                completedTokens.contains { token in
                    words.contains { word in
                        word == token || word.hasPrefix(token) || token.hasPrefix(word)
                    }
                }
            }
            .flatMap { $0 }

        let semanticWords = matchedWords.isEmpty ? allWords : matchedWords
        let base = completedTokens.joined(separator: " ")
        let suffix = suffixForCompletion(questionWords: semanticWords, baseTokens: completedTokens)
        let candidate = suffix.isEmpty ? "\(base)?" : "\(base) \(suffix)?"
        guard normalize(candidate).hasPrefix(normalizedTyped) else {
            return nil
        }
        return candidate
    }

    private func bestWordCompletion(for token: String, in words: [String]) -> String? {
        words
            .filter { $0.hasPrefix(token) && $0.count > token.count }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count < rhs.count
            }
            .first
    }

    private func typedTokens(_ typedTokens: [String], matchQuestionWords questionWords: [String]) -> Bool {
        guard !typedTokens.isEmpty else {
            return false
        }

        return typedTokens.allSatisfy { typedToken in
            questionWords.contains { questionWord in
                questionWord == typedToken || questionWord.hasPrefix(typedToken)
            }
        }
    }

    private func suffixForCompletion(questionWords: [String], baseTokens: [String]) -> String {
        let baseSet = Set(baseTokens)
        let candidates = [
            (["claim", "claims"], "claim"),
            (["result", "results"], "result"),
            (["defined", "definition", "define"], "definition"),
            (["figure", "plot"], "figure"),
            (["table"], "table"),
            (["assumption", "assumptions"], "assumptions"),
            (["context"], "context"),
            (["important", "importance"], "importance"),
            (["derivation", "derive"], "derivation")
        ]

        for (needles, suffix) in candidates where !baseSet.contains(suffix) {
            if needles.contains(where: { questionWords.contains($0) }) {
                return suffix
            }
        }
        return ""
    }

    public static let defaultFallbackQuestions = [
        "Where is this defined?",
        "Explain this in the context of the paper.",
        "Why is this important?",
        "How does this connect to the main result?",
        "What assumptions are used here?",
        "Give a concise derivation.",
        "What should I notice in this figure?"
    ]
}
