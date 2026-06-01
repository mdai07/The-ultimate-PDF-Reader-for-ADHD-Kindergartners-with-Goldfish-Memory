import XCTest
@testable import PaperReaderCore

final class AIPromptTemplatesTests: XCTestCase {
    func testRenderReplacesKnownPlaceholdersAndLeavesUnknownPlaceholdersReadable() {
        let rendered = AIPromptTemplates.render(
            "Context: {paperContext}\nQuestion: {question}\nUnknown: {custom}",
            values: [
                "paperContext": "page 1 context",
                "question": "What is the result?"
            ]
        )

        XCTAssertEqual(
            rendered,
            "Context: page 1 context\nQuestion: What is the result?\nUnknown: {custom}"
        )
    }

    func testDefaultInlineSuggestionPromptHasRequiredSelectionPlaceholders() {
        let template = AIPromptTemplates.defaultTemplate(for: .inlineSuggestions)

        XCTAssertTrue(template.contains("{paperMemory}"))
        XCTAssertTrue(template.contains("{selectionTitle}"))
        XCTAssertTrue(template.contains("{selectionDetail}"))
        XCTAssertTrue(template.contains("explanations"))
        XCTAssertTrue(template.contains("$...$"))
        XCTAssertFalse(template.contains("Q:"))
        XCTAssertFalse(template.contains("A:"))
    }

    func testDefaultSidebarUserPromptHasPaperContextAndQuestionPlaceholders() {
        let template = AIPromptTemplates.defaultTemplate(for: .sidebarUser)

        XCTAssertTrue(template.contains("{paperContext}"))
        XCTAssertTrue(template.contains("{question}"))
    }

    func testDefaultSidebarSystemPromptEncouragesLatexMathDelimiters() {
        let template = AIPromptTemplates.defaultTemplate(for: .sidebarSystem)

        XCTAssertTrue(template.contains("$...$"))
        XCTAssertTrue(template.contains("$$...$$"))
    }

    func testEffectiveTemplateUsesDefaultWhenOverrideIsBlank() {
        let effective = AIPromptTemplates.effectiveTemplate(
            override: "   \n",
            for: .sidebarSystem
        )

        XCTAssertEqual(effective, AIPromptTemplates.defaultTemplate(for: .sidebarSystem))
    }

    func testEffectiveTemplateUsesUserOverrideWhenProvided() {
        let effective = AIPromptTemplates.effectiveTemplate(
            override: "Answer like a terse referee.",
            for: .sidebarSystem
        )

        XCTAssertEqual(effective, "Answer like a terse referee.")
    }
}
