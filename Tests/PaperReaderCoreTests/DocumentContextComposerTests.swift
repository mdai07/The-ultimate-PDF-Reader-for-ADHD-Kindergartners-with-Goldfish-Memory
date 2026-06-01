import XCTest
@testable import PaperReaderCore

final class DocumentContextComposerTests: XCTestCase {
    func testDefaultChatContextUsesPrimaryPaperOnly() {
        let primary = DocumentContext(prompt: "Primary paper context")

        let composed = DocumentContextComposer.chatContext(
            primaryTitle: "Primary",
            primary: primary,
            additional: []
        )

        XCTAssertTrue(composed.prompt.contains("Primary paper context"))
        XCTAssertFalse(composed.prompt.contains("Additional paper context"))
    }

    func testAdditionalTabContextIsIncludedWhenRequested() {
        let primaryCitation = SourceCitation(pageIndex: 0, label: "primary")
        let extraCitation = SourceCitation(pageIndex: 2, label: "extra")
        let primary = DocumentContext(prompt: "Primary paper context", citations: [primaryCitation])
        let extra = DocumentContext(prompt: "Second paper context", citations: [extraCitation])

        let composed = DocumentContextComposer.chatContext(
            primaryTitle: "Primary",
            primary: primary,
            additional: [
                DocumentContextComposer.AdditionalContext(title: "Second", context: extra)
            ]
        )

        XCTAssertTrue(composed.prompt.contains("Primary paper context"))
        XCTAssertTrue(composed.prompt.contains("Additional paper context: Second"))
        XCTAssertTrue(composed.prompt.contains("Second paper context"))
        XCTAssertEqual(
            composed.citations,
            [primaryCitation, SourceCitation(pageIndex: 2, label: "Second: extra")]
        )
    }

    func testPrimaryVisualAttachmentsArePreserved() {
        let attachment = AIImageAttachment(label: "equation", mimeType: "image/png", base64Data: "abc")
        let primary = DocumentContext(prompt: "Primary paper context", imageAttachments: [attachment])

        let composed = DocumentContextComposer.chatContext(
            primaryTitle: "Primary",
            primary: primary,
            additional: []
        )

        XCTAssertEqual(composed.imageAttachments, [attachment])
    }
}
