import Foundation

public enum AIPromptTemplateKey: String, CaseIterable, Identifiable {
    case sidebarSystem
    case sidebarUser
    case paperMemory
    case inlineSuggestions
    case inlineAnswer

    public var id: String { rawValue }
}

public enum AIPromptTemplates {
    public static func defaultTemplate(for key: AIPromptTemplateKey) -> String {
        switch key {
        case .sidebarSystem:
            return "You are an academic paper reading assistant. Cite page numbers when possible. Use LaTeX math delimiters, such as $...$ or $$...$$, for equations."
        case .sidebarUser:
            return """
            {paperContext}

            Question: {question}
            """
        case .paperMemory:
            return """
            Read this paper context and create a compact working memory for future Q&A.
            Include topic, main result, methods, important figures/tables/equations, and where definitions are likely found.
            Keep it under 900 words.

            {wholePaper}
            """
        case .inlineSuggestions:
            return """
            Generate exactly three concise, selection-specific explanations of this selected paper content.
            Do not list questions. Do not write Q/A pairs.
            Each explanation must directly explain the selected text, figure, table, equation, symbol, claim, axis, caption, or object.
            Each explanation must be grounded in the selected context text and mention at least one selected term, label, variable, caption phrase, axis, column, or object.
            If the selected context mentions Figure, Fig., Table, plot, caption, curve, axes, columns, or rows, prioritize explaining what the selected figure/table/plot is showing or summarizing.
            Use the whole-paper memory only to ground the selected content, not to replace it.
            Prioritize definitions for short words, symbols, or equations. Prioritize contextual explanation for longer passages.
            Use LaTeX math delimiters, such as $...$ or $$...$$, when writing equations or symbols that need mathematical formatting.
            Keep every explanation to one short sentence, ideally under 24 words.
            Return only the explanations as bullet points or numbered lines.

            {paperMemory}

            Selected context title:
            {selectionTitle}

            Selected context text, OCR, caption, or digest:
            {selectionDetail}
            """
        case .inlineAnswer:
            return """
            Answer this inline paper-reading question in 2-4 sentences. Use LaTeX math delimiters, such as $...$ or $$...$$, for equations when helpful.

            {paperMemory}

            {selectionTitle}
            {selectionDetail}

            Question: {question}
            """
        }
    }

    public static func render(_ template: String, values: [String: String]) -> String {
        values.reduce(template) { rendered, pair in
            rendered.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    public static func effectiveTemplate(override: String, for key: AIPromptTemplateKey) -> String {
        if override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return defaultTemplate(for: key)
        }
        return override
    }
}
